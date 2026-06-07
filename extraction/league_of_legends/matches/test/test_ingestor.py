import requests
import pytest

from extraction.league_of_legends.matches.ingestor import RiotGamesIngestor


class FakeResponse:
    """Minimal stand-in for requests.Response used by the ingestor."""

    def __init__(self, json_data=None, status_code=200, headers=None):
        self._json = json_data
        self.status_code = status_code
        self.headers = headers or {}

    def json(self):
        return self._json

    def raise_for_status(self):
        if self.status_code >= 400:
            raise requests.HTTPError(f"{self.status_code} error")


@pytest.fixture
def riot_env(monkeypatch):
    monkeypatch.setenv("RIOT_API_KEY", "test-key")
    monkeypatch.setenv("RIOT_REGIONAL_HOST", "https://americas.example.test")


@pytest.fixture
def ingestor(riot_env):
    return RiotGamesIngestor()


class TestInit:
    def test_reads_credentials_and_sets_auth_header(self, ingestor):
        assert ingestor.api_key == "test-key"
        assert ingestor.host == "https://americas.example.test"
        assert ingestor.session.headers["X-Riot-Token"] == "test-key"

    def test_missing_api_key_raises(self, monkeypatch):
        monkeypatch.delenv("RIOT_API_KEY", raising=False)
        monkeypatch.setenv("RIOT_REGIONAL_HOST", "https://americas.example.test")
        with pytest.raises(KeyError):
            RiotGamesIngestor()


class TestGet:
    def test_builds_url_and_returns_json(self, ingestor, monkeypatch):
        captured = {}

        def fake_get(url, params=None):
            captured["url"] = url
            captured["params"] = params
            return FakeResponse(json_data={"ok": True})

        monkeypatch.setattr(ingestor.session, "get", fake_get)

        result = ingestor._get("/some/path", params={"a": 1})

        assert result == {"ok": True}
        assert captured["url"] == "https://americas.example.test/some/path"
        assert captured["params"] == {"a": 1}

    def test_retries_once_on_429_then_succeeds(self, ingestor, monkeypatch):
        responses = [
            FakeResponse(status_code=429, headers={"Retry-After": "3"}),
            FakeResponse(json_data={"ok": True}),
        ]
        calls = []

        def fake_get(url, params=None):
            calls.append(url)
            return responses.pop(0)

        slept = []
        monkeypatch.setattr(ingestor.session, "get", fake_get)
        monkeypatch.setattr(
            "extraction.league_of_legends.matches.ingestor.time.sleep",
            lambda s: slept.append(s),
        )

        result = ingestor._get("/path")

        assert result == {"ok": True}
        assert len(calls) == 2
        assert slept == [3]

    def test_defaults_retry_after_to_one_second(self, ingestor, monkeypatch):
        responses = [
            FakeResponse(status_code=429),  # no Retry-After header
            FakeResponse(json_data={}),
        ]
        slept = []
        monkeypatch.setattr(
            ingestor.session, "get", lambda url, params=None: responses.pop(0)
        )
        monkeypatch.setattr(
            "extraction.league_of_legends.matches.ingestor.time.sleep",
            lambda s: slept.append(s),
        )

        ingestor._get("/path")

        assert slept == [1]

    def test_raises_for_status_on_error(self, ingestor, monkeypatch):
        monkeypatch.setattr(
            ingestor.session,
            "get",
            lambda url, params=None: FakeResponse(status_code=500),
        )
        with pytest.raises(requests.HTTPError):
            ingestor._get("/path")


class TestEndpoints:
    def test_get_puuid_by_riot_id(self, ingestor, monkeypatch):
        seen = {}
        monkeypatch.setattr(
            ingestor, "_get", lambda path, params=None: seen.update(path=path)
        )
        ingestor.get_puuid_by_riot_id("Faker", "KR1")
        assert seen["path"] == "/riot/account/v1/accounts/by-riot-id/Faker/KR1"

    def test_get_match_ids_default_params(self, ingestor, monkeypatch):
        seen = {}
        monkeypatch.setattr(
            ingestor,
            "_get",
            lambda path, params=None: seen.update(path=path, params=params),
        )
        ingestor.get_match_ids("PUUID-1")
        assert seen["path"] == "/lol/match/v5/matches/by-puuid/PUUID-1/ids"
        assert seen["params"] == {"start": 0, "count": 10}

    def test_get_match_ids_includes_queue_when_given(self, ingestor, monkeypatch):
        seen = {}
        monkeypatch.setattr(
            ingestor,
            "_get",
            lambda path, params=None: seen.update(params=params),
        )
        ingestor.get_match_ids("PUUID-1", start=5, count=3, queue=420)
        assert seen["params"] == {"start": 5, "count": 3, "queue": 420}

    def test_get_match(self, ingestor, monkeypatch):
        seen = {}
        monkeypatch.setattr(
            ingestor, "_get", lambda path, params=None: seen.update(path=path)
        )
        ingestor.get_match("NA1_123")
        assert seen["path"] == "/lol/match/v5/matches/NA1_123"

    def test_get_match_timeline(self, ingestor, monkeypatch):
        seen = {}
        monkeypatch.setattr(
            ingestor, "_get", lambda path, params=None: seen.update(path=path)
        )
        ingestor.get_match_timeline("NA1_123")
        assert seen["path"] == "/lol/match/v5/matches/NA1_123/timeline"


class TestIngestMatches:
    def _wire(self, ingestor, monkeypatch, account=None, match_ids=None, matches=None):
        monkeypatch.setattr(
            ingestor, "get_puuid_by_riot_id", lambda g, t: account
        )
        monkeypatch.setattr(
            ingestor, "get_match_ids", lambda puuid, count=10: match_ids
        )
        monkeypatch.setattr(
            ingestor, "get_match", lambda mid: matches[mid]
        )

    def test_yields_all_matches_for_player(self, ingestor, monkeypatch):
        self._wire(
            ingestor,
            monkeypatch,
            account={"puuid": "P1"},
            match_ids=["M1", "M2"],
            matches={"M1": {"id": "M1"}, "M2": {"id": "M2"}},
        )
        out = list(ingestor.ingest_league_of_legend_matches(["Faker#KR1"]))
        assert out == [{"id": "M1"}, {"id": "M2"}]

    def test_passes_count_through_to_match_ids(self, ingestor, monkeypatch):
        seen = {}
        monkeypatch.setattr(ingestor, "get_puuid_by_riot_id", lambda g, t: {"puuid": "P"})
        monkeypatch.setattr(
            ingestor,
            "get_match_ids",
            lambda puuid, count=10: seen.update(count=count) or [],
        )
        list(ingestor.ingest_league_of_legend_matches(["A#B"], count=25))
        assert seen["count"] == 25

    def test_skips_riot_id_without_hashtag(self, ingestor, monkeypatch):
        # "noseparator".split("#", 1) -> single element, unpack raises ValueError
        monkeypatch.setattr(
            ingestor,
            "get_puuid_by_riot_id",
            lambda g, t: (_ for _ in ()).throw(AssertionError("should not be called")),
        )
        out = list(ingestor.ingest_league_of_legend_matches(["noseparator"]))
        assert out == []

    def test_skips_player_on_http_error(self, ingestor, monkeypatch):
        def boom(g, t):
            raise requests.HTTPError("404")

        monkeypatch.setattr(ingestor, "get_puuid_by_riot_id", boom)
        out = list(ingestor.ingest_league_of_legend_matches(["Ghost#NA1"]))
        assert out == []

    def test_skips_player_on_missing_puuid_key(self, ingestor, monkeypatch):
        monkeypatch.setattr(ingestor, "get_puuid_by_riot_id", lambda g, t: {})
        out = list(ingestor.ingest_league_of_legend_matches(["A#B"]))
        assert out == []

    def test_continues_to_next_player_after_failure(self, ingestor, monkeypatch):
        def maybe_boom(g, t):
            if g == "Bad":
                raise requests.HTTPError("404")
            return {"puuid": "P-good"}

        monkeypatch.setattr(ingestor, "get_puuid_by_riot_id", maybe_boom)
        monkeypatch.setattr(ingestor, "get_match_ids", lambda puuid, count=10: ["M1"])
        monkeypatch.setattr(ingestor, "get_match", lambda mid: {"id": mid})

        out = list(
            ingestor.ingest_league_of_legend_matches(["Bad#NA1", "Good#NA1"])
        )
        assert out == [{"id": "M1"}]

    def test_skips_single_bad_match_but_keeps_others(self, ingestor, monkeypatch):
        monkeypatch.setattr(ingestor, "get_puuid_by_riot_id", lambda g, t: {"puuid": "P"})
        monkeypatch.setattr(
            ingestor, "get_match_ids", lambda puuid, count=10: ["M1", "M2", "M3"]
        )

        def get_match(mid):
            if mid == "M2":
                raise requests.HTTPError("500")
            return {"id": mid}

        monkeypatch.setattr(ingestor, "get_match", get_match)

        out = list(ingestor.ingest_league_of_legend_matches(["A#B"]))
        assert out == [{"id": "M1"}, {"id": "M3"}]

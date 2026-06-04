import os
import time
import logging

import requests

log = logging.getLogger(__name__)


class RiotGamesIngestor:
    def __init__(self):
        self.api_key = os.environ["RIOT_API_KEY"]
        # match-v5 and account-v1 use the REGIONAL routing host, not the platform host
        # (na1/euw1). americas covers NA/BR/LAN/LAS; others are europe / asia / sea.
        self.host = os.environ["RIOT_REGIONAL_HOST"]
        self.session = requests.Session()
        self.session.headers.update({"X-Riot-Token": self.api_key})

    def _get(self, path, params=None):
        """GET {host}{path} with one naive retry on 429 (rate limit)."""
        url = f"{self.host}{path}"
        resp = self.session.get(url, params=params)
        if resp.status_code == 429:
            retry_after = int(resp.headers.get("Retry-After", "1"))
            log.warning("Rate limited; sleeping %ss", retry_after)
            time.sleep(retry_after)
            resp = self.session.get(url, params=params)
        resp.raise_for_status()
        return resp.json()

    def get_puuid_by_riot_id(self, game_name, tag_line):
        """Riot ID (gameName#tagLine) -> account, incl. puuid. account-v1."""
        return self._get(f"/riot/account/v1/accounts/by-riot-id/{game_name}/{tag_line}")

    def get_match_ids(self, puuid, start=0, count=10, queue=None):
        """PUUID -> list of recent match IDs. match-v5."""
        params = {"start": start, "count": count}
        if queue is not None:
            params["queue"] = queue
        return self._get(f"/lol/match/v5/matches/by-puuid/{puuid}/ids", params=params)

    def get_match(self, match_id):
        """Match ID -> full match JSON (metadata + info). match-v5."""
        return self._get(f"/lol/match/v5/matches/{match_id}")

    def get_match_timeline(self, match_id):
        """Match ID -> per-minute timeline of events. match-v5 (optional)."""
        return self._get(f"/lol/match/v5/matches/{match_id}/timeline")

    def ingest_league_of_legend_matches(self, riot_ids, count=10):
        """For each Riot ID, resolve PUUID, list recent matches, fetch each.

        riot_ids: iterable of "gameName#tagLine" strings.
        Yields full match dicts. Logs and continues on per-call errors so one
        bad player/match never crashes the whole run.
        """
        for riot_id in riot_ids:
            try:
                game_name, tag_line = riot_id.split("#", 1)
                account = self.get_puuid_by_riot_id(game_name, tag_line)
                puuid = account["puuid"]
                match_ids = self.get_match_ids(puuid, count=count)
                log.info("%s -> %d matches", riot_id, len(match_ids))
            except (requests.HTTPError, ValueError, KeyError) as e:
                log.warning("Skipping %s: %s", riot_id, e)
                continue

            for match_id in match_ids:
                try:
                    yield self.get_match(match_id)
                except requests.HTTPError as e:
                    log.warning("Skipping match %s: %s", match_id, e)
                    continue

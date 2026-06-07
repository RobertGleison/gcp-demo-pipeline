import json
import logging
from unittest.mock import MagicMock

import pytest

from extraction.league_of_legends.matches.producer import MatchProducer

TOPIC = "projects/demo/topics/matches"


def make_match(match_id="NA1_123", platform="NA1", queue=420):
    info = {}
    if platform is not None:
        info["platformId"] = platform
    if queue is not None:
        info["queueId"] = queue
    return {"metadata": {"matchId": match_id}, "info": info}


class TestDryRun:
    def test_returns_none_and_never_touches_pubsub(self, monkeypatch):
        producer = MatchProducer(TOPIC, dry_run=True)
        # _publisher() must not be reached in dry-run mode.
        monkeypatch.setattr(
            producer,
            "_publisher",
            lambda: (_ for _ in ()).throw(AssertionError("publisher used in dry-run")),
        )

        assert producer.publish_match(make_match()) is None
        assert producer._client is None

    def test_logs_what_it_would_publish(self, caplog):
        producer = MatchProducer(TOPIC, dry_run=True)
        with caplog.at_level(logging.INFO):
            producer.publish_match(make_match(match_id="NA1_999"))
        assert "dry-run" in caplog.text
        assert "NA1_999" in caplog.text


class TestRealPublish:
    def _producer_with_fake_client(self, message_id="msg-1"):
        producer = MatchProducer(TOPIC, dry_run=False)
        client = MagicMock()
        future = MagicMock()
        future.result.return_value = message_id
        client.publish.return_value = future
        producer._client = client  # bypass lazy creation
        return producer, client

    def test_publishes_encoded_body_with_attributes(self):
        producer, client = self._producer_with_fake_client(message_id="msg-42")
        match = make_match(match_id="NA1_777", platform="NA1", queue=420)

        result = producer.publish_match(match)

        assert result == "msg-42"
        client.publish.assert_called_once()
        args, kwargs = client.publish.call_args
        assert args[0] == TOPIC
        assert json.loads(kwargs["data"].decode("utf-8")) == match
        assert kwargs["match_id"] == "NA1_777"
        assert kwargs["platform"] == "NA1"
        assert kwargs["queue_id"] == "420"

    def test_coerces_attribute_values_to_strings(self):
        producer, client = self._producer_with_fake_client()
        producer.publish_match(make_match(queue=440))
        _, kwargs = client.publish.call_args
        assert kwargs["queue_id"] == "440"
        assert isinstance(kwargs["queue_id"], str)

    def test_missing_platform_and_queue_become_empty_strings(self):
        producer, client = self._producer_with_fake_client()
        producer.publish_match(make_match(platform=None, queue=None))
        _, kwargs = client.publish.call_args
        assert kwargs["platform"] == ""
        assert kwargs["queue_id"] == ""


class TestLazyPublisher:
    def test_publisher_created_once_and_cached(self, monkeypatch):
        fake_client = MagicMock()
        constructor = MagicMock(return_value=fake_client)

        # Patch the symbol the lazy import resolves to.
        import google.cloud.pubsub_v1 as pubsub_v1

        monkeypatch.setattr(pubsub_v1, "PublisherClient", constructor)

        producer = MatchProducer(TOPIC, dry_run=False)
        first = producer._publisher()
        second = producer._publisher()

        assert first is fake_client
        assert second is fake_client
        constructor.assert_called_once()

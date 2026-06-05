import json
import logging

log = logging.getLogger(__name__)


class MatchProducer:
    """Publishes one Pub/Sub message per match: body = raw match JSON,
    attributes = match_id / platform / queue_id (per the design doc's Landing
    section). In dry-run mode it logs what it *would* publish and never touches
    Pub/Sub, so the extractor can be exercised with no topic and no GCP.
    """

    def __init__(self, topic_path, dry_run=False):
        self.topic_path = topic_path
        self.dry_run = dry_run
        self._client = None  # the pubsub client is created lazily (real runs only)

    def _publisher(self):
        # Imported lazily so --dry-run works without google-cloud-pubsub installed.
        if self._client is None:
            from google.cloud import pubsub_v1
            self._client = pubsub_v1.PublisherClient()
        return self._client

    def publish_match(self, match):
        meta = match["metadata"]
        info = match["info"]
        match_id = meta["matchId"]
        attributes = {
            "match_id": match_id,
            "platform": str(info.get("platformId", "")),
            "queue_id": str(info.get("queueId", "")),
        }
        data = json.dumps(match).encode("utf-8")

        if self.dry_run:
            log.info(
                "[dry-run] would publish match %s (%d bytes) attrs=%s",
                match_id, len(data), attributes,
            )
            return None

        future = self._publisher().publish(self.topic_path, data=data, **attributes)
        message_id = future.result()
        log.info("published match %s as message %s", match_id, message_id)
        return message_id

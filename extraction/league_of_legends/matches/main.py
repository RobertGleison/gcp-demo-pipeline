import os
import logging
import argparse
from pathlib import Path

import dotenv

from extraction.league_of_legends.matches.ingestor import RiotGamesIngestor
from extraction.league_of_legends.matches.producer import MatchProducer

# Load extraction/.env by absolute path so it works regardless of CWD
# (the module runs from the repo root). main.py -> matches -> league_of_legends
# -> extraction, so parents[2] is the extraction/ project dir.
dotenv.load_dotenv(Path(__file__).resolve().parents[2] / ".env")
logging.basicConfig(level=logging.INFO)
log = logging.getLogger("ingestor")


def main():
    parser = argparse.ArgumentParser(description="Riot match extractor")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="resolve and log what would be published; never call Pub/Sub",
    )
    parser.add_argument(
        "--count", type=int, default=5, help="matches to fetch per player"
    )
    args = parser.parse_args()

    # Topic is only needed for real publishes. PUBSUB_TOPIC is the full path:
    # projects/<project>/topics/<topic>.
    topic_path = os.environ.get("PUBSUB_TOPIC")
    if not args.dry_run and not topic_path:
        parser.error("PUBSUB_TOPIC is required unless --dry-run is set")

    # In the real pipeline this seed list comes from config (common.tfvars).
    # Use a real Riot ID — your own account is the safest test. NA/BR/LAN/LAS
    # accounts work on the default `americas` host; for KR/EU set
    # RIOT_REGIONAL_HOST accordingly (e.g. asia / europe).
    seed_riot_ids = ["YourName#NA1"]
    ingestor = RiotGamesIngestor()
    producer = MatchProducer(topic_path, dry_run=args.dry_run)
    for match in ingestor.ingest_league_of_legend_matches(seed_riot_ids, count=args.count):
        meta = match["metadata"]
        info = match["info"]
        log.info(
            "match %s queue=%s duration=%ss participants=%d",
            meta["matchId"],
            info["queueId"],
            info["gameDuration"],
            len(meta["participants"]),
        )
        producer.publish_match(match)


if __name__ == "__main__":
    main()

# Riot LoL match extractor.
# Run from the repo root: the `etl.extraction.league_of_legends.matches` package
# imports require the repo root as CWD, while `uv run --project etl/extraction`
# resolves dependencies from the etl/extraction/ project venv.
#
# Pass extra flags via ARGS, e.g.  make dryrun ARGS="--count 10"

MODULE := etl.extraction.league_of_legends.matches.main
UV     := uv run --project etl/extraction

.PHONY: run dryrun

run:  ## Run the extractor and publish to Pub/Sub (needs PUBSUB_TOPIC)
	$(UV) python -m $(MODULE) $(ARGS)

dryrun:  ## Run the extractor and only log what would be published (no Pub/Sub)
	$(UV) python -m $(MODULE) --dry-run $(ARGS)

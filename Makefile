# Riot LoL match extractor.
# Run from the repo root: the `extraction.league_of_legends.matches` package
# imports require the repo root as CWD, while `uv run --project extraction`
# resolves dependencies from the extraction/ project venv.
#
# Pass extra flags via ARGS, e.g.  make dryrun ARGS="--count 10"

MODULE := extraction.league_of_legends.matches.main
UV     := uv run --project extraction

.PHONY: run dryrun

run:  ## Run the extractor and publish to Pub/Sub (needs PUBSUB_TOPIC)
	$(UV) python -m $(MODULE) $(ARGS)

dryrun:  ## Run the extractor and only log what would be published (no Pub/Sub)
	$(UV) python -m $(MODULE) --dry-run $(ARGS)

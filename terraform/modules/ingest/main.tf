# Shared locals for the ingest layer.
locals {
  # Extractor image: <repo-prefix>/extractor:<tag>. Repo prefix injected from the
  # cicd module; CD must have pushed this tag first.
  extractor_image = "${var.artifact_registry_repo}/extractor:${var.extractor_image_tag}"
}

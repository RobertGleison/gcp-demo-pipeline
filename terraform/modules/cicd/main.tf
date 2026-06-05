module "wif_github" {
  source = "../wif_github"

  project_id        = var.project_id
  github_repository = var.github_repository

}

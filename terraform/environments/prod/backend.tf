terraform {
  backend "gcs" {
    bucket = "project-5a3b1a75-500c-4b93-9e1-tfstate"
    prefix = "prod"
  }
}

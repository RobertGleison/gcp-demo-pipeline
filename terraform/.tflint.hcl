plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# Version constraints are intentionally consolidated in the root module
# (environments/prod/versions.tf); child modules inherit the provider and
# do not redeclare required_version / required_providers. Disable the two
# rules that expect every module to carry its own constraints.
rule "terraform_required_version" {
  enabled = false
}

rule "terraform_required_providers" {
  enabled = false
}

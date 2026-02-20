locals {
  project_id      = "my-gcp-project-12345"
  project_name    = "webapp"
  region          = "us-central1"
  zones           = ["us-central1-a", "us-central1-b", "us-central1-c"]
  environment     = "staging"
  machine_type    = "e2-medium"
  app_subnet_cidr = "10.0.1.0/24"
  db_subnet_cidr  = "10.0.2.0/24"
}

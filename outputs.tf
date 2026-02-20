output "vpc_id" {
  description = "The ID of the VPC network"
  value       = google_compute_network.main.id
}

output "gke_cluster_endpoint" {
  description = "The endpoint of the GKE cluster"
  value       = google_container_cluster.primary.cluster_endpoint
}

output "cloud_run_api_url" {
  description = "The URL of the API Cloud Run service"
  value       = google_cloud_run_v2_service.api.url
}

output "scheduler_job_names" {
  description = "Names of the report generation scheduler jobs"
  value       = google_cloud_scheduler_job.report_generation.name
}

output "database_connection_name" {
  description = "Cloud SQL instance connection name"
  value       = google_sql_database_instance.main.connection_name
}

output "node_pool_names" {
  description = "Names of the extra node pools"
  value       = google_container_node_pool.extra_pools.name
}

output "storage_bucket_name" {
  description = "Name of the assets storage bucket"
  value       = google_storage_bucket.assets.bucket_name
}

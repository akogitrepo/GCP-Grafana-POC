output "cicd_service_account_email" {
  value = google_service_account.cicd.email
}

output "app_service_account_emails" {
  value = { for k, sa in google_service_account.apps : k => sa.email }
}

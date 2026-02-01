output "budget_alerts_sns_topic_arn" {
  description = "SNS topic ARN for budget alerts"
  value       = aws_sns_topic.budget_alerts.arn
}

output "budget_alerts_sns_topic_name" {
  description = "SNS topic name for budget alerts"
  value       = aws_sns_topic.budget_alerts.name
}

output "overall_budget_name" {
  description = "Overall budget name"
  value       = aws_budgets_budget.overall.name
}

output "database_budget_name" {
  description = "Database budget name"
  value       = aws_budgets_budget.database.name
}

output "compute_budget_name" {
  description = "Compute budget name"
  value       = aws_budgets_budget.compute.name
}

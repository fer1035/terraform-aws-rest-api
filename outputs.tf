output "api_root_id" {
  value       = aws_api_gateway_rest_api.api.root_resource_id
  sensitive   = false
  description = "API root ID."
}

output "api_name" {
  value       = var.api_name
  description = "The name of the REST API."
}

output "api_description" {
  value       = var.api_description
  description = "A description for the REST API."
}

output "api_id" {
  value       = aws_api_gateway_rest_api.api.id
  description = "API ID."
}

output "api_validator" {
  value       = aws_api_gateway_request_validator.validator.id
  description = "API Request Validator ID."
}

output "api_execution_arn" {
  value       = aws_api_gateway_rest_api.api.execution_arn
  description = "API execution ARN."
}

output "api_url" {
  value       = "https://${aws_api_gateway_rest_api.api.id}.execute-api.${local.region}.amazonaws.com/${aws_api_gateway_deployment.deployment.stage_name}"
  description = "API URL not including endpoint pathparts."
}

output "api_key" {
  value       = aws_api_gateway_api_key.api_key.value
  description = "API key."
}

output "stage_name" {
  value       = aws_api_gateway_deployment.deployment.stage_name
  description = "API Stage name."
}

output "cors" {
  value       = var.cors
  description = "API CORS configuration."
}

resource "aws_api_gateway_rest_api" "api" {
  # body = jsonencode({
  #   openapi = "3.0.1"
  #   info = {
  #     title   = "example"
  #     version = "1.0"
  #   }
  #   paths = {
  #     "/path1" = {
  #       get = {
  #         x-amazon-apigateway-integration = {
  #           httpMethod           = "GET"
  #           payloadFormatVersion = "1.0"
  #           type                 = "HTTP_PROXY"
  #           uri                  = "https://ip-ranges.amazonaws.com/ip-ranges.json"
  #         }
  #       }
  #     }
  #   }
  # })
  name        = var.api_name
  description = var.api_description
  endpoint_configuration {
    types = ["REGIONAL"] # | EDGE
  }
}

resource "aws_api_gateway_request_validator" "validator" {
  name                        = "validator"
  rest_api_id                 = aws_api_gateway_rest_api.api.id
  validate_request_body       = true
  validate_request_parameters = true
  depends_on = [
    aws_api_gateway_rest_api.api
  ]
}

# Root CORS.
resource "aws_api_gateway_method" "options" {
  rest_api_id      = aws_api_gateway_rest_api.api.id
  resource_id      = aws_api_gateway_rest_api.api.root_resource_id
  http_method      = "OPTIONS"
  authorization    = "NONE"
  api_key_required = false
  depends_on = [
    aws_api_gateway_rest_api.api
  ]
}
resource "aws_api_gateway_method_response" "options" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_rest_api.api.root_resource_id
  http_method = aws_api_gateway_method.options.http_method
  status_code = "200"
  depends_on = [
    aws_api_gateway_method.options
  ]
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}
resource "aws_api_gateway_integration" "options" {
  rest_api_id          = aws_api_gateway_rest_api.api.id
  resource_id          = aws_api_gateway_rest_api.api.root_resource_id
  http_method          = "OPTIONS"
  type                 = "MOCK"
  passthrough_behavior = "WHEN_NO_MATCH"
  depends_on = [
    aws_api_gateway_rest_api.api
  ]
  #   # Transforms the incoming XML request to JSON
  #   request_templates = {
  #     "application/xml" = <<EOF
  # {
  #    "body" : $input.json('$')
  # }
  # EOF
  #   }
  request_templates = {
    "application/json" : "{\"statusCode\": 200}"
  }
}
resource "aws_api_gateway_integration_response" "options" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_rest_api.api.root_resource_id
  http_method = aws_api_gateway_integration.options.http_method
  status_code = "200"
  depends_on = [
    aws_api_gateway_integration.options
  ]
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'${var.cors}'"
  }
  #   # Transforms the backend JSON response to XML
  #   response_templates = {
  #     "application/xml" = <<EOF
  # #set($inputRoot = $input.path('$'))
  # <?xml version="1.0" encoding="UTF-8"?>
  # <message>
  #     $inputRoot.body
  # </message>
  # EOF
  #   }
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = var.stage_name
  depends_on = [
    aws_api_gateway_rest_api.api
  ]

  /* triggers = {
    # NOTE: The configuration below will satisfy ordering considerations,
    #       but not pick up all future REST API changes. More advanced patterns
    #       are possible, such as using the filesha1() function against the
    #       Terraform configuration file(s) or removing the .id references to
    #       calculate a hash against whole resources. Be aware that using whole
    #       resources will show a difference after the initial implementation.
    #       It will stabilize to only change when resources change afterwards.
    # redeployment = sha1(jsonencode([
    #   aws_api_gateway_resource.resource.id,
    #   aws_api_gateway_method.method.id,
    #   aws_api_gateway_integration.integration.id,
    # ]))
    redeployment = filesha1(
      "./modules/security_demo_endpoint/api_endpoint.tf"
    )
  } */

  lifecycle {
    create_before_destroy = true
  }
}

# resource "aws_api_gateway_stage" "stage" {
#   deployment_id = aws_api_gateway_deployment.deployment.id
#   rest_api_id   = aws_api_gateway_rest_api.api.id
#   stage_name    = "test"
# }

resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_deployment.deployment.stage_name
  method_path = "*/*"
  depends_on = [
    aws_api_gateway_deployment.deployment
  ]

  settings {
    metrics_enabled        = false
    logging_level          = "OFF"
    throttling_rate_limit  = 1000
    throttling_burst_limit = 500
  }
}

resource "aws_api_gateway_api_key" "api_key" {
  name = "my_api_key"
}

resource "aws_api_gateway_usage_plan" "usage_plan" {
  name        = "my_usage_plan"
  description = "API usage plan."
  depends_on = [
    aws_api_gateway_deployment.deployment
  ]

  api_stages {
    api_id = aws_api_gateway_rest_api.api.id
    stage  = aws_api_gateway_deployment.deployment.stage_name
    # stage  = aws_api_gateway_stage.stage.stage_name
  }

  quota_settings {
    limit  = 10000
    offset = 0
    period = "MONTH"
  }

  throttle_settings {
    burst_limit = 500
    rate_limit  = 1000
  }
}

resource "aws_api_gateway_usage_plan_key" "plan_key" {
  key_id        = aws_api_gateway_api_key.api_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.usage_plan.id
  depends_on = [
    aws_api_gateway_usage_plan.usage_plan
  ]
}

resource "aws_wafv2_web_acl_association" "waf_association" {
  count        = var.use_waf ? 1 : 0
  resource_arn = "arn:aws:apigateway:${local.region}::/restapis/${aws_api_gateway_rest_api.api.id}/stages/${aws_api_gateway_deployment.deployment.stage_name}"
  web_acl_arn  = aws_wafv2_web_acl.waf_regional[0].arn
  depends_on = [
    aws_wafv2_web_acl.waf_regional[0]
  ]
}

locals {
  db_data = {
    allocated_storage       = "30"
    max_allocated_storage   = 100
    engine_version          = "14.10"
    instance_class          = "db.t3.small"
    ca_cert_name            = "rds-ca-rsa2048-g1"
    backup_retention_period = 7
    db_name                 = "mydb"
    cloudwatch_logs         = ["postgresql", "upgrade"]
  }

  ecs_services = [
    {
      name          = "flask"
      cpu           = var.flask_app_cpu
      memory        = var.flask_app_memory
      template_file = var.flask_app_template_file
      vars = {
        aws_ecr_repository            = aws_ecr_repository.python_app.repository_url
        tag                           = var.flask_app_tag
        container_name                = var.flask_app_container_name
        aws_cloudwatch_log_group_name = "/aws/ecs/${var.environment}-flask-app"
        database_address              = aws_db_instance.postgres.address
        database_name                 = aws_db_instance.postgres.db_name
        postgres_username             = aws_db_instance.postgres.username
        postgres_password             = random_password.dbs_random_string.result
        database_url                  = aws_secretsmanager_secret_version.dbs_secret_val.secret_string
        environment                   = var.environment
      }
    },
    {
      name          = "nginx"
      cpu           = var.nginx_cpu
      memory        = var.nginx_memory
      template_file = var.nginx_template_file
      vars = {
        aws_ecr_repository            = var.nginx_aws_ecr_repository
        tag                           = var.nginx_tag
        container_name                = var.nginx_container_name
        aws_cloudwatch_log_group_name = "/aws/ecs/${var.environment}-nginx"
        environment                   = var.environment
      }
    },
    {
      name          = "redis"
      cpu           = var.redis_cpu
      memory        = var.redis_memory
      template_file = var.redis_template_file
      vars = {
        aws_ecr_repository            = var.redis_aws_ecr_repository
        tag                           = var.redis_tag
        container_name                = var.redis_container_name
        aws_cloudwatch_log_group_name = "/aws/ecs/${var.environment}-redis"
        environment                   = var.environment
      }
    }
  ]

  app_deploy_data = {
    IMAGE_NAME : "${var.app_name}-image"
    ECR_REGISTRY : "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com"
    ECR_REPOSITORY : "${var.environment}-${var.app_name}"
    ACCOUNT_ID : data.aws_caller_identity.current.account_id
    ECS_CLUSTER : "${var.environment}-${var.app_name}-cluster"
    ECS_REGION : data.aws_region.current.name
    ECS_SERVICE : "${var.environment}-${var.app_name}-flask-service"
    ECS_TASK_DEFINITION : "${var.environment}-${var.app_name}"
    ECS_APP_CONTAINER_NAME : var.flask_app_container_name
  }
}


resource "aws_secretsmanager_secret" "app_deploy_data" {
  name        = "${var.environment}-${var.app_name}-deploy-data"
  description = "Deployment data for the Flask app"
}

resource "aws_secretsmanager_secret_version" "app_deploy_data_version" {
  secret_id     = aws_secretsmanager_secret.app_deploy_data.id
  secret_string = jsonencode(local.app_deploy_data)
}

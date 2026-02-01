module "ecr" {
  source = "./ecr"

  prefix               = var.prefix
  env                  = var.env
  service_name         = var.service_name
  image_tag_mutability = var.image_tag_mutability
  scan_on_push         = var.scan_on_push
  max_image_count      = var.max_image_count
}

module "ecs_service" {
  source = "./ecs-service"

  prefix                    = var.prefix
  env                       = var.env
  service_name              = var.service_name
  vpc_id                    = var.vpc_id
  subnet_ids                = var.subnet_ids
  cluster_id                = var.cluster_id
  cluster_name              = var.cluster_name
  alb_security_group_id     = var.alb_security_group_id
  bastion_security_group_id = var.bastion_security_group_id
  listener_arn              = var.listener_arn
  listener_rule_priority    = var.listener_rule_priority
  path_pattern              = var.path_pattern
  container_port            = var.container_port
  container_image           = var.container_image != "" ? var.container_image : module.ecr.repository_url
  task_cpu                  = var.task_cpu
  task_memory               = var.task_memory
  ephemeral_storage_size    = var.ephemeral_storage_size
  desired_count             = var.desired_count
  min_capacity              = var.min_capacity
  max_capacity              = var.max_capacity
  cpu_target_value          = var.cpu_target_value
  memory_target_value       = var.memory_target_value
  health_check_path         = var.health_check_path
  health_check_matcher      = var.health_check_matcher
  environment_variables     = var.environment_variables
  log_group_name            = var.log_group_name
  aws_region                = var.aws_region
  cpu_architecture          = var.cpu_architecture

  depends_on = [module.ecr]
}

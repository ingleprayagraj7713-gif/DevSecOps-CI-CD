data "aws_caller_identity" "current" {}

module "vpc" {
  source = "../../modules/vpc"

  name                 = "${var.project_name}-${var.environment}"
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  nat_gateway_per_az   = var.nat_gateway_per_az
}

module "jenkins" {
  source = "../../modules/jenkins"

  name               = "${var.project_name}-${var.environment}-jenkins"
  vpc_id             = module.vpc.vpc_id
  subnet_id          = module.vpc.private_subnet_ids[0]
  instance_type      = var.jenkins_instance_type
  volume_size_gib    = var.jenkins_volume_size_gib
  provision_instance = var.provision_jenkins
}

module "security" {
  source = "../../modules/security"

  name              = "${var.project_name}-${var.environment}"
  vpc_id            = module.vpc.vpc_id
  vpc_cidr          = var.vpc_cidr
  alb_ingress_cidrs = var.alb_ingress_cidrs
  container_port    = var.container_port
}

module "ecr" {
  source = "../../modules/ecr"

  repository_name       = "${var.project_name}-${var.environment}"
  image_retention_count = var.ecr_image_retention_count
}

module "iam" {
  source = "../../modules/iam"

  name               = "${var.project_name}-${var.environment}"
  ecr_repository_arn = module.ecr.repository_arn
  log_group_arn      = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/${var.project_name}-${var.environment}:*"
  secret_arns        = values(var.application_secret_arns)
  kms_key_arns       = var.application_secret_kms_key_arns
}

module "alb" {
  source = "../../modules/alb"

  name                  = "${var.project_name}-${var.environment}"
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  alb_security_group_id = module.security.alb_security_group_id
  target_port           = var.container_port
  health_check_path     = var.health_check_path
  account_id            = data.aws_caller_identity.current.account_id
  region                = var.aws_region
  waf_rate_limit        = var.waf_rate_limit
  log_retention_days    = var.log_retention_days
}

module "ecs" {
  source = "../../modules/ecs"

  name                              = "${var.project_name}-${var.environment}"
  region                            = var.aws_region
  private_subnet_ids                = module.vpc.private_subnet_ids
  task_security_group_id            = module.security.task_security_group_id
  target_group_arn                  = module.alb.target_group_arn
  repository_url                    = module.ecr.repository_url
  image_tag                         = var.image_tag
  execution_role_arn                = module.iam.execution_role_arn
  task_role_arn                     = module.iam.task_role_arn
  secrets                           = var.application_secret_arns
  container_port                    = var.container_port
  cpu                               = var.task_cpu
  memory                            = var.task_memory
  desired_count                     = var.desired_count
  min_capacity                      = var.min_capacity
  max_capacity                      = var.max_capacity
  health_check_grace_period_seconds = var.health_check_grace_period_seconds
  log_retention_days                = var.log_retention_days
}

module "monitoring" {
  source = "../../modules/monitoring"

  name                     = "${var.project_name}-${var.environment}"
  region                   = var.aws_region
  jenkins_instance_id      = module.jenkins.instance_id
  jenkins_enabled          = var.provision_jenkins
  cluster_name             = module.ecs.cluster_name
  service_name             = module.ecs.service_name
  load_balancer_arn_suffix = module.alb.load_balancer_arn_suffix
  target_group_arn_suffix  = module.alb.target_group_arn_suffix
  alarm_email              = var.alarm_email
}

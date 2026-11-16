output "application_url" {
  description = "HTTP endpoint for the application ALB."
  value       = "http://${module.alb.load_balancer_dns_name}"
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "ecs_service_name" {
  value = module.ecs.service_name
}

output "ecs_task_definition_arn" {
  value = module.ecs.task_definition_arn
}

output "target_group_arn" {
  value = module.alb.target_group_arn
}

output "alarm_topic_arn" {
  value = module.monitoring.alarm_topic_arn
}

output "jenkins_instance_id" {
  description = "Private Jenkins controller; null when provision_jenkins is false."
  value       = module.jenkins.instance_id
}

output "jenkins_security_group_id" {
  description = "Source security group for private SSH-launched Jenkins agents."
  value       = module.jenkins.security_group_id
}

output "alb_dns_name" {
  value = module.alb.load_balancer_dns_name
}

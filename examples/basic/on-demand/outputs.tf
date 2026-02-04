output "autoscaling_group_id" {
  description = "The ID of the launch template"
  value       = module.ec2-autoscale[*].autoscaling_group_id
}

output "autoscaling_group_arn" {
  description = "The ID of the launch template"
  value       = module.ec2-autoscale[*].autoscaling_group_arn
}

output "autoscaling_tags" {
  description = "tags"
  value       = module.ec2-autoscale[*].on_demand[*].tag
}
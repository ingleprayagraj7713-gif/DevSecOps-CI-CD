output "instance_id" { value = try(aws_instance.jenkins[0].id, null) }
output "private_ip" { value = try(aws_instance.jenkins[0].private_ip, null) }
output "security_group_id" { value = aws_security_group.jenkins.id }

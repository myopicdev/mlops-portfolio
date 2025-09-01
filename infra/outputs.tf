output "s3_bucket" { value = aws_s3_bucket.docs.bucket }
output "db_address" { value = aws_db_instance.postgres.address }
output "db_name" { value = aws_db_instance.postgres.db_name }
output "vpc_id" { value = aws_vpc.this.id }

output "ssm_connect_command" {
  description = "Run this command to connect to the private EC2 via SSM"
  value       = "aws ssm start-session --target ${aws_instance.ssm_ec2.id}"
}

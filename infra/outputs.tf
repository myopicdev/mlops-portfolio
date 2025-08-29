output "s3_bucket" { value = aws_s3_bucket.docs.bucket }
output "db_address" { value = aws_db_instance.postgres.address }
output "db_name" { value = aws_db_instance.postgres.db_name }
output "vpc_id" { value = aws_vpc.this.id }
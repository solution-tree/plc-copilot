output "bucket_arn" {
  description = "ARN of the data S3 bucket"
  value       = aws_s3_bucket.data.arn
}

output "bucket_name" {
  description = "Name of the data S3 bucket"
  value       = aws_s3_bucket.data.id
}

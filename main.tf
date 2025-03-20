terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "default"
}

module "template_files"{
  source = "hashicorp/dir/template"
  base_dir ="${path.module}/website"
}

# 1. Create an S3 bucket
resource "aws_s3_bucket" "website" {
  bucket = var.bucket_name
  force_destroy = true
}

# 2. Configure the bucket for static website hosting
resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "404.html"
  }
}

# 3. Configure public access block
resource "aws_s3_bucket_public_access_block" "website_public_access" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}


# 4. Create bucket policy for public read access
resource "aws_s3_bucket_policy" "public_read_policy" {
  bucket = aws_s3_bucket.website.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website.arn}/*"
      },
    ]
  })

  # This is important: it ensures the public access block is configured before applying the policy
  depends_on = [aws_s3_bucket_public_access_block.website_public_access]
}

# 5. Upload website files
resource "aws_s3_object" "bucket_files" {
  bucket       = aws_s3_bucket.website.id
  for_each = module.template_files.files
  key          = each.key
  content_type = each.value.content_type
  source  = each.value.source_path
  content = each.value.content
  etag= each.value.digests.md5
}





terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

resource "aws_dynamodb_table" "this" {
  count = var.enabled ? 1 : 0

  name         = var.table_name
  billing_mode = var.billing_mode
  hash_key     = var.hash_key
  range_key    = var.range_key

  dynamic "attribute" {
    for_each = var.attributes
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_dynamodb_arn
  }

  point_in_time_recovery {
    enabled = var.point_in_time_recovery
  }

  tags = merge(var.tags, { Name = var.table_name })
}

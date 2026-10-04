# ---------- roleC ----------
# Trust policy: the principal is roleB's exact ARN, NOT the Account A root.
# Trusting the root would let anything in Account A assume this role as long as
# it had sts:AssumeRole permission. Naming roleB means only roleB can get in.
resource "aws_iam_role" "role_c" {
  name = "roleC"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { AWS = "arn:aws:iam::${var.account_a_id}:role/roleB" }
    }]
  })
}

# ---------- Full access to ONE bucket ----------
resource "aws_iam_role_policy" "role_c_s3" {
  name = "full-access-to-one-bucket"
  role = aws_iam_role.role_c.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "s3:*"
      Resource = [
        "arn:aws:s3:::${var.bucket_name}",   # the bucket itself (list, etc.)
        "arn:aws:s3:::${var.bucket_name}/*", # the objects inside it
      ]
    }]
  })
}

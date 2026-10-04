# Trust policy: anyone in Account A *who has been given sts:AssumeRole on the
# role* can assume it. The group policies in users_groups.tf control who that is.
locals {
  trust_account_a = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { AWS = "arn:aws:iam::${var.account_a_id}:root" }
    }]
  })
}

# ---------- roleA: admin on everything except IAM ----------
resource "aws_iam_role" "role_a" {
  name               = "roleA"
  assume_role_policy = local.trust_account_a
}

resource "aws_iam_role_policy" "role_a_admin_no_iam" {
  name = "admin-except-iam"
  role = aws_iam_role.role_a.id

  # NotAction = allow everything EXCEPT iam:*
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect      = "Allow"
      NotAction   = "iam:*"
      Resource    = "*"
    }]
  })
}

# ---------- roleB: can only assume a role in Account B ----------
resource "aws_iam_role" "role_b" {
  name               = "roleB"
  assume_role_policy = local.trust_account_a
}

resource "aws_iam_role_policy" "role_b_assume_account_b" {
  name = "assume-role-in-account-b"
  role = aws_iam_role.role_b.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = "arn:aws:iam::${var.account_b_id}:role/${var.account_b_role_name}"
    }]
  })
}

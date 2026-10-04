# Trust policy: only roleB from Account A may assume roleC
data "aws_iam_policy_document" "roleC_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type = "AWS"
      # FIX 1: roleB is a role, so this must be role/roleB, not user/roleB
      identifiers = ["arn:aws:iam::${var.account_a_id}:role/roleB"]
    }
  }
}

resource "aws_iam_role" "roleC" {
  name               = "roleC"
  assume_role_policy = data.aws_iam_policy_document.roleC_trust.json
}

# Permissions: full S3 access, but only on the one bucket
data "aws_iam_policy_document" "roleC_s3" {
  statement {
    effect  = "Allow"
    actions = ["s3:*"]

    # FIX 2: was Resource = "*" (every bucket). Now just this bucket,
    # plus its objects (the /* line is needed for object-level actions).
    resources = [
      "arn:aws:s3:::${var.bucket_name}",
      "arn:aws:s3:::${var.bucket_name}/*",
    ]
  }
}

resource "aws_iam_role_policy" "roleC_s3" {
  name   = "roleC-s3-access"
  role   = aws_iam_role.roleC.id
  policy = data.aws_iam_policy_document.roleC_s3.json
}

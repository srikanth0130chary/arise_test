# ---------- Groups ----------
resource "aws_iam_group" "group1" {
  name = "group1" # CLI / programmatic only
}

resource "aws_iam_group" "group2" {
  name = "group2" # console + CLI
}

# ---------- Users ----------
resource "aws_iam_user" "group1" {
  for_each = toset(var.group1_users)
  name     = each.key
}

resource "aws_iam_user" "group2" {
  for_each = toset(var.group2_users)
  name     = each.key
}

# ---------- Group membership ----------
resource "aws_iam_group_membership" "group1" {
  name  = "group1-membership"
  group = aws_iam_group.group1.name
  users = [for u in aws_iam_user.group1 : u.name]
}

resource "aws_iam_group_membership" "group2" {
  name  = "group2-membership"
  group = aws_iam_group.group2.name
  users = [for u in aws_iam_user.group2 : u.name]
}

# ---------- Console access (group2 only) ----------
# group1 users never get a login profile, so they can't sign in to the console.
resource "aws_iam_user_login_profile" "group2" {
  for_each                = aws_iam_user.group2
  user                    = each.value.name
  password_reset_required = true
}

# group2 users need this to be able to change their first password
resource "aws_iam_group_policy_attachment" "group2_change_password" {
  group      = aws_iam_group.group2.name
  policy_arn = "arn:aws:iam::aws:policy/IAMUserChangePassword"
}

# ---------- CLI access keys (both groups) ----------
resource "aws_iam_access_key" "this" {
  for_each = merge(aws_iam_user.group1, aws_iam_user.group2)
  user     = each.value.name
}

# ---------- What each group is allowed to do ----------
# group1 (programmatic) -> can assume roleB
resource "aws_iam_group_policy" "group1_assume" {
  name  = "assume-roleB"
  group = aws_iam_group.group1.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = aws_iam_role.role_b.arn
    }]
  })
}

# group2 (console) -> can assume roleA
resource "aws_iam_group_policy" "group2_assume" {
  name  = "assume-roleA"
  group = aws_iam_group.group2.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = aws_iam_role.role_a.arn
    }]
  })
}

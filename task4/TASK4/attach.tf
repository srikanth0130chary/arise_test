# Attaches policy.json to the ci user from Task 3 as an inline policy.
# If you drop this file into task3/account-a/ you can use
#   user = aws_iam_user.group1["ci"].name
# instead of the plain string below (and delete versions.tf).
resource "aws_iam_user_policy" "ci_pipeline" {
  name   = "ci-pipeline-least-privilege"
  user   = "ci"
  policy = file("${path.module}/policy.json")
}

output "role_a_arn" {
  value = aws_iam_role.role_a.arn
}

output "role_b_arn" {
  value = aws_iam_role.role_b.arn
}

output "access_key_ids" {
  description = "user => access key ID"
  value       = { for u, k in aws_iam_access_key.this : u => k.id }
}

output "secret_access_keys" {
  description = "user => secret key (sensitive, use: terraform output -json)"
  value       = { for u, k in aws_iam_access_key.this : u => k.secret }
  sensitive   = true
}

output "console_passwords" {
  description = "group2 user => first-login password (must be reset at first login)"
  value       = { for u, p in aws_iam_user_login_profile.group2 : u => p.password }
  sensitive   = true
}

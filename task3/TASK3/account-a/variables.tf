variable "region" {
  type    = string
  default = "us-east-1"
}

variable "account_a_id" {
  description = "Account A (where users, groups and roles are created)"
  type        = string
  default     = "000000000000"
}

variable "account_b_id" {
  description = "Account B, the account roleB is allowed to hop into"
  type        = string
  default     = "111111111111" # placeholder, change to the real ID
}

variable "account_b_role_name" {
  description = "Name of the role in Account B that roleB is allowed to assume"
  type        = string
  default     = "roleC"
}

variable "group1_users" {
  description = "Programmatic-only users"
  type        = list(string)
  default     = ["engine", "ci"]
}

variable "group2_users" {
  description = "Console + CLI users"
  type        = list(string)
  default     = ["alice", "bob"]
}

variable "instances" {
  description = "Map of instances to create. The key is used as the instance name."
  type = map(object({
    instance_type    = string
    root_volume_type = string
    root_volume_size = number
    root_volume_iops = optional(number) # required for io1/io2
    key_name         = string
    protected        = optional(bool, false)
  }))

  validation {
    condition = alltrue([
      for k, v in var.instances :
      contains(["gp2", "gp3", "io1", "io2"], v.root_volume_type)
    ])
    error_message = "root_volume_type must be one of gp2, gp3, io1, io2."
  }

  validation {
    condition = alltrue([
      for k, v in var.instances :
      !contains(["io1", "io2"], v.root_volume_type) || v.root_volume_iops != null
    ])
    error_message = "io1/io2 volumes need root_volume_iops to be set."
  }
}

variable "environment" {
  description = "Environment tag (dev, staging, prod...)"
  type        = string
}

variable "owner" {
  description = "Owner tag (person or team)"
  type        = string
}

variable "subnet_id" {
  description = "Subnet to launch the instances in"
  type        = string
}

variable "security_group_ids" {
  description = "Security groups to attach to the instances"
  type        = list(string)
  default     = []
}

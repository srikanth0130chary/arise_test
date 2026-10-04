# Latest Amazon Linux 2023 AMI
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

locals {
  # prevent_destroy can't take a variable or a condition, it has to be a
  # hardcoded true/false. So I split the map in two and use two resource
  # blocks, one with prevent_destroy and one without.
  protected_instances = { for name, cfg in var.instances : name => cfg if cfg.protected }
  regular_instances   = { for name, cfg in var.instances : name => cfg if !cfg.protected }
}

# Instances that are allowed to be destroyed
resource "aws_instance" "regular" {
  for_each = local.regular_instances

  ami                    = data.aws_ami.al2023.id
  instance_type          = each.value.instance_type
  key_name               = each.value.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids

  root_block_device {
    volume_type = each.value.root_volume_type
    volume_size = each.value.root_volume_size
    iops        = each.value.root_volume_iops
  }

  tags = {
    Name        = each.key
    Environment = var.environment
    Owner       = var.owner
  }
}

# Protected instance(s) - terraform destroy will fail on these
resource "aws_instance" "protected" {
  for_each = local.protected_instances

  ami                    = data.aws_ami.al2023.id
  instance_type          = each.value.instance_type
  key_name               = each.value.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids

  root_block_device {
    volume_type = each.value.root_volume_type
    volume_size = each.value.root_volume_size
    iops        = each.value.root_volume_iops
  }

  tags = {
    Name        = each.key
    Environment = var.environment
    Owner       = var.owner
  }

  lifecycle {
    prevent_destroy = true
  }
}

locals {
  all_instances = merge(aws_instance.regular, aws_instance.protected)
}

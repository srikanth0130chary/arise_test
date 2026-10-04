# Notes

## How it works
All 5 instances come from one variable, `instances`, which is a map. The map
key becomes the instance name and the `for_each` loops over it, so adding a
6th instance is just adding another entry in tfvars.

## Which instance has `prevent_destroy` and why
**`db-1`** is protected.

It's the database server, so it's the only one holding data that can't be
recreated from scratch. If someone runs `terraform destroy` or renames the key
by mistake, the web/app/cache/worker boxes can just be rebuilt, but losing the
db root volume (it's also the io2 one) would mean data loss and downtime.

## Why two resource blocks?
`prevent_destroy` has to be a literal `true`/`false` in Terraform. It can't
use a variable or `each.value`, so I can't turn it on for just one instance
inside a single `for_each` block. Workaround: split the map using the
`protected` flag into two locals, and use one resource block with
`prevent_destroy = true` and one without. Both are still driven by the same
`instances` variable. The outputs merge the two back together.

## Assumptions
- The key pairs in `key_name` already exist in the AWS region.
- All instances go in the same subnet (passed as `subnet_id`).
- AMI is the latest Amazon Linux 2023, looked up with a data source.
- io1/io2 needs `root_volume_iops`, so a validation checks that.

## Things I'd improve with more time
- Allow a different subnet per instance.
- Add encryption on the root volumes (`encrypted = true` with a KMS key).
- Maybe use `ignore_changes` on `ami` so a new AMI doesn't replace instances.

## Usage
```
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

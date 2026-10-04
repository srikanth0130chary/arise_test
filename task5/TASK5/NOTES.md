# Task 5 - Find and Fix the Bug

The original snippet is saved as `original_broken.tf.txt` (renamed so Terraform
doesn't load it). `main.tf` is the fixed version.

## Bug 1 - trust policy: `user/roleB` should be `role/roleB`

**The broken line**
```
identifiers = ["arn:aws:iam::000000000000:user/roleB"]
```

**Why it fails**
roleB is an IAM *role*, but this ARN points to an IAM *user* that happens to be
named "roleB". The ARN type is part of the identity: `user/roleB` and
`role/roleB` are two completely different things, and the first one doesn't
exist in Account A. So the trust policy names somebody that isn't there.

What goes wrong in practice:
- When Terraform saves the trust policy, IAM checks that the principal exists.
  It doesn't, so the apply fails with a `MalformedPolicyDocument: Invalid
  principal in policy` error and roleC isn't created.
- Even if a user called "roleB" did exist, it would still be wrong. roleB
  (the role) would not match the trust policy, because the trust policy would
  only allow that user. When roleB calls `sts:AssumeRole` on roleC it would be
  denied.

**Fix:** `arn:aws:iam::000000000000:role/roleB`

## Bug 2 - permissions policy: `Resource = "*"` gives access to every bucket

**The broken lines**
```
Action   = "s3:*"
Resource = "*"
```

**Why it's wrong**
This one wouldn't fail on apply. It would work, which is what makes it
dangerous. `s3:*` on `*` means roleC can do anything to *every* bucket in
Account B: read, overwrite and delete data, change bucket policies, even delete
buckets. The requirement is full access to a *single named bucket*, so this
gives far more than allowed. If roleB (or whatever is using it) were ever
compromised, the blast radius would be the whole account's S3 data.

**Fix:** limit the resource to the one bucket, with two ARNs:
```
arn:aws:s3:::<bucket>      <- the bucket itself (ListBucket, bucket settings)
arn:aws:s3:::<bucket>/*    <- the objects in it (Get/Put/DeleteObject)
```
You need both. Bucket-level actions apply to the first ARN and object-level
actions apply to the second, so with only one of them half of `s3:*` would stop
working.

## Other small changes (not bugs)
- Account ID and bucket name moved to variables.
- The permissions policy now uses `aws_iam_policy_document` as well, to match
  the trust policy.

## Things to remember
- roleB must already exist before this is applied. IAM validates the principal
  when the trust policy is saved, so apply Account A first.
- Cross-account needs both sides: roleB's own policy must also allow
  `sts:AssumeRole` on roleC's ARN. That part isn't in this snippet and was done
  in Task 3.

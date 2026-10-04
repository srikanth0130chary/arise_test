# Task 2 - Remote State & Locking

## What was added
- `backend.tf` - S3 backend with DynamoDB locking and encryption turned on.
- `bootstrap/` - small separate Terraform config that creates the S3 bucket
  (versioning, encryption, public access blocked) and the DynamoDB table
  (`LockID` as the hash key). The backend can't create its own bucket, so this
  is run once first, using local state.

The rest of the files are the Task 1 module (Task 1 notes are in
`TASK1_NOTES.md`).

## What happens today (local state) if two people run apply at the same time
With no backend, state is just a `terraform.tfstate` file on disk, and there
is no locking at all. Terraform doesn't stop a second run.

- If each person has their own copy of the repo, they each have their own
  state file. Neither knows what the other one created, so they can end up
  creating duplicate instances, or one person's apply can try to change
  things that the other already changed.
- If they somehow share one state file (shared folder, committed to git),
  both runs read the same state at the start, then both write back when they
  finish. Whoever finishes last overwrites the other's changes. The state then
  no longer matches what is really in AWS, and it can get corrupted or lose
  track of resources. Those resources are then orphaned and still cost money.

Either way it's a mess to clean up by hand with `terraform import` or by
deleting resources manually.

## How the backend change fixes it
- **One shared state** in S3, so everyone works from the same source of truth.
- **Locking with DynamoDB**: before `plan`/`apply` Terraform writes a lock item
  (key `LockID`) to the table, using a conditional write that only succeeds if
  the item doesn't already exist. If a second person runs apply while the
  first is still going, they get an "Error acquiring the state lock" message
  that shows who holds the lock, and they have to wait and retry. The lock is
  deleted when the run finishes.
- **Versioning on the bucket** means if the state ever does get damaged, we can
  go back to an older version.
- **Encryption** because state can contain sensitive values.

If a run crashes and leaves a stuck lock, it can be released with
`terraform force-unlock <LOCK_ID>`, but only after checking nobody is
actually running apply.

## How to use
```
cd bootstrap
terraform init && terraform apply     # one time only

cd ..
# edit backend.tf if you changed the bucket name / region
terraform init                        # asks to migrate state if any exists
terraform plan
terraform apply
```

## Note
Newer Terraform (1.10+) can lock directly in S3 with `use_lockfile = true`
and DynamoDB locking is being phased out. I used DynamoDB here since that is
what the task asked for.

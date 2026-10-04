# Task 4 - Least-Privilege Policy for the `ci` user

`policy.json` is a custom policy (no managed policies) with 7 statements.
`attach.tf` attaches it to `ci` as an inline policy.

The ARNs in it are example values. Change them to the real ones:

| Thing | Example in the file |
|---|---|
| Region / account | `us-east-1` / `000000000000` |
| ECR repository | `my-app` |
| ECS cluster / service | `my-cluster` / `my-service` |
| ECS task + execution roles | `my-app-task-role`, `my-app-task-execution-role` |
| Artifacts bucket | `my-build-artifacts` |

## What each statement is for

**1. Push a Docker image to one ECR repo**
- `ecr:GetAuthorizationToken` is needed for `docker login`. It does not
  support resource-level permissions, so it has to be `"*"`. It only returns a
  login token and gives no access to any repo by itself.
- The 5 upload actions (`BatchCheckLayerAvailability`, `InitiateLayerUpload`,
  `UploadLayerPart`, `CompleteLayerUpload`, `PutImage`) are exactly what
  `docker push` calls. They are limited to the one repository ARN.

**2. Deploy a new task definition to one ECS service**
- `ecs:RegisterTaskDefinition` and `ecs:DescribeTaskDefinition` create a new
  revision and read the current one. These two don't support resource-level
  permissions either, so they are on `"*"`. This is the one place the policy
  is broader than I'd like (see below for why it's still OK).
- `ecs:UpdateService` and `ecs:DescribeServices` are limited to the single
  service ARN. UpdateService points the service at the new revision, and
  DescribeServices lets the pipeline wait until the deploy is stable.
- `iam:PassRole` is required to register a task definition that has a task
  role / execution role in it. It's restricted to those two role ARNs, and with
  a condition that they can only be passed to `ecs-tasks.amazonaws.com`.

**3. Read-only on one S3 bucket**
- `s3:GetObject` on the objects (`bucket/*`) and `s3:ListBucket` on the bucket
  itself (`bucket`). Those are two different resources, which is why there are
  two statements. No write or delete actions anywhere.

## What I deliberately left out, and why

**ECR**
- Pull actions (`BatchGetImage`, `GetDownloadUrlForLayer`): pushing doesn't
  need them. Add them only if the pipeline pulls from this repo (e.g. for cache).
- `CreateRepository`, `DeleteRepository`, `BatchDeleteImage`,
  `SetRepositoryPolicy`: CI pushes into a repo that already exists. It
  shouldn't be able to create, delete or change who can access repos.
- `ecr:*`, and any other repository: wildcards would be way more than needed.

**ECS**
- `CreateService`, `DeleteService`, `RunTask`, `StopTask`, cluster actions:
  the task is to deploy to an existing service, not manage the infrastructure.
- `UpdateService` on any other service: only one service ARN is allowed.
- `DeregisterTaskDefinition`: CI only adds revisions, never removes them.
- `ecs:TagResource`: only needed if the pipeline tags the task definitions.

**IAM**
- Everything except `PassRole` on those two roles. No `iam:*`, and not
  `PassRole` on `"*"`. A wildcard PassRole is a well-known privilege
  escalation, because CI could register a task with an admin role and run
  code with it.

**S3**
- `PutObject`, `DeleteObject`, `PutBucketPolicy` etc. The task says read-only.
- `s3:ListAllMyBuckets` and `GetBucketLocation`: the pipeline already knows the
  bucket name. (If a tool complains about location, add `GetBucketLocation`
  on the bucket ARN.)
- Any other bucket.

**Other**
- CloudWatch Logs, CloudFormation, EC2, etc. Not part of the three jobs.
- KMS: if the bucket or ECR repo uses a customer-managed key, `kms:Decrypt`
  (and `GenerateDataKey` for ECR push) on that key would be needed. I assumed
  default AWS-managed encryption, so none is added.

## Things to be aware of
- `RegisterTaskDefinition` on `"*"` can't be avoided. It's less risky than it
  looks because the `PassRole` statement stops CI from registering a task
  definition that uses any role other than the two allowed ones.
- The ci user from Task 3 only had permission to assume roleB. This policy gives
  it these permissions directly. If you'd rather keep ci keyless, put the same
  policy on a role and let the pipeline assume it with OIDC (as in Task 3).
- I'd test it with the IAM policy simulator or `aws iam simulate-principal-policy`,
  and check CloudTrail / Access Analyzer after a few runs to see if anything
  can be removed.

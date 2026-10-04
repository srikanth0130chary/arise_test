# Task 3 - Multi-Account IAM & Cross-Account Access

Two separate Terraform folders because they run in two different accounts:
- `account-a/` - run with Account A (000000000000) credentials
- `account-b/` - run with Account B (111111111111) credentials

## Direct answers

### 1. Would I give engine and ci IAM users with access keys in real production?

No. I built it this way because the task asked for group1 users with
programmatic access, but in a real production setup I'd avoid long-lived
access keys.

Why keys are a problem:
- They never expire. If one leaks (git commit, CI log, laptop, Terraform state)
  it works until someone notices and revokes it.
- Rotation is manual, so in practice it doesn't get done.
- With shared service-style users like `ci`, it's hard to tell who or what
  used the key.

What I'd do instead:
- **ci**: OIDC federation (GitHub Actions / GitLab / Jenkins OIDC). The pipeline
  assumes an IAM role and gets temporary credentials for the job. No stored secret.
- **engine** (if it is a person or a team): IAM Identity Center (SSO). People log
  in with `aws sso login` and get short-lived credentials, with MFA, and
  offboarding is central.
- **engine** (if it is an app/service on AWS): an instance profile, ECS task
  role or EKS IRSA role, so the credentials come from the platform.

If a key truly can't be avoided (for example an on-prem system or a third-party
tool that can't federate), I'd:
- give the user only the permission to assume one role, which is what I did here
  (group1 can only assume roleB)
- rotate the key regularly, store it in Secrets Manager and never in code
- add a condition such as source IP and alarm on its use (CloudTrail)

### 2. In roleC's trust policy, why trust roleB's ARN and not the Account A root?

Because of who ends up controlling access to roleC.

- **Trusting `arn:aws:iam::000000000000:root`** means "Account A decides". Any
  user or role in Account A can assume roleC as soon as an Account A admin gives
  it `sts:AssumeRole` on roleC. Account B has no say in it after that, and
  nothing in Account B would show the change.
- **Trusting `arn:aws:iam::000000000000:role/roleB`** means "Account B decides".
  Only roleB can get in. If someone in Account A adds `sts:AssumeRole` to another
  role or user, the call is still denied because Account B's trust policy doesn't
  list them.

That matches the task's requirement: assumable only by roleB, *not by anything
else in Account A*. It is also least privilege. roleC gives full access to a
bucket, so the list of who can use it should be as short as possible, and it
limits the damage if another identity in Account A is compromised.

Cross-account access needs both sides to allow it: the caller's own policy
(Account A) and roleC's trust policy (Account B). Using the specific ARN means
Account B's side actually restricts something, instead of just passing the
decision to the other account.

One gotcha: IAM saves the role ARN as roleB's unique ID. If roleB is deleted and
recreated with the same name, the trust stops matching until `account-b/` is
applied again.

## Account A (000000000000)

| Thing | Details |
|---|---|
| `group1` | Programmatic only. Members: `engine`, `ci` |
| `group2` | Console + CLI. Members: `alice`, `bob` |
| `roleA` | Admin on all services except IAM |
| `roleB` | Only permission: `sts:AssumeRole` on `roleC` in Account B |

- **group1 is CLI only**: access keys but no login profile, so no console password.
- **group2 is console + CLI**: login profile (forced password reset) plus access
  keys. `IAMUserChangePassword` is attached so they can set their own password.
- **roleA**: `Allow` + `NotAction: iam:*` on `*`, i.e. everything except IAM.
- **roleB**: only `sts:AssumeRole`, limited to the one `roleC` ARN, not `*`.

### Assumptions (task didn't say who uses what)
- group2 (humans in the console) assumes **roleA**.
- group1 (engine / ci) assumes **roleB** to reach Account B.
- Users have no permissions of their own apart from assuming those roles.

## Account B (111111111111)

**roleC**: `s3:*` on `arn:aws:s3:::<bucket>` and `arn:aws:s3:::<bucket>/*`
(both lines are needed, one for the bucket and one for the objects). Nothing
else is allowed. Trust policy principal: `arn:aws:iam::000000000000:role/roleB`.

## Order to apply
1. `account-a/` first (creates roleB)
2. `account-b/` (creates roleC, whose trust policy names roleB, and IAM checks
   that roleB exists when the trust policy is saved)

## Using it from the CLI
```
# 1. as engine/ci, assume roleB in Account A
aws sts assume-role --role-arn arn:aws:iam::000000000000:role/roleB \
  --role-session-name s1
# 2. with those temp creds, assume roleC in Account B
aws sts assume-role --role-arn arn:aws:iam::111111111111:role/roleC \
  --role-session-name s2
# 3. with the new temp creds
aws s3 ls s3://<bucket>
```

## Things to know
- Account IDs, region and bucket name are placeholders/defaults in `variables.tf`.
- The bucket must already exist. I only gave roleC access to it, I didn't create it.
- Access keys and console passwords end up in the Terraform state, so use the
  encrypted S3 backend from Task 2.
- `allowed_account_ids` in both providers stops apply from running in the wrong account.
- `aws_iam_group_membership` is authoritative: users added to the groups outside
  Terraform will be removed.

## What I'd add with more time
- Require MFA for roleA (`aws:MultiFactorAuthPresent` in the trust policy).
- An `sts:ExternalId` or `aws:PrincipalOrgID` condition on roleC's trust policy.
- Restrict roleA's trust to named users instead of the account root.

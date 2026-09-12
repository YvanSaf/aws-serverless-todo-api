# Attack Simulation

This folder contains the scripts and the walkthrough used to demonstrate the
vulnerabilities of the vulnerable version of the Todo API, and to verify
that the hardened version blocks each one.

The same four scripts are run twice: once against the vulnerable deployment,
once against the hardened deployment. The contrast between the two runs is
the actual deliverable of this project.

## Prerequisites

- The target version (`vulnerable` or `hardened`) already deployed with
  `terraform apply` in the matching folder under `infra/terraform/`
- `bash`, `curl`
- `jq` recommended but not required, the scripts fall back to `grep`/`sed`
  when it is not installed

## How the scripts work

Every script takes the version to test as its first argument and defaults to
`vulnerable` when none is given:

```bash
./01-enumeration.sh              # tests the vulnerable version
./01-enumeration.sh hardened     # same script, tests the hardened version
```

Instead of hardcoding an API URL, each script reads it directly from the
Terraform state of the target version:

```bash
API=$(terraform -chdir="../../infra/terraform/${VERSION}" output -raw api_endpoint)
```

This means the exact same four files are reused for both deployments, with
no manual copy-pasting of endpoints and no risk of testing the wrong
environment by mistake.

## Attack 1: Enumeration

**Script:** `01-enumeration.sh`

**Vulnerability:** `list_tasks()` in `handler.py` uses a DynamoDB `Scan`
instead of a `Query` filtered by user, and the route has no authentication.
A single unauthenticated `GET /tasks` request returns every task from every
user in the table.

**What the script does:** creates two tasks for two different fake users,
then calls `GET /tasks` and counts how many distinct `userId` values come
back in the same response.

**Expected result:**
- Vulnerable: HTTP 200, tasks from both users returned together
- Hardened: HTTP 401, the Lambda Authorizer rejects the request before it
  reaches the data

## Attack 2: Stored XSS injection

**Script:** `02-injection.sh`

**Vulnerability:** `create_task()` stores the `title` field exactly as
received, with no validation or sanitization. A script tag submitted as a
title is written to DynamoDB unescaped.

**What the script does:** sends `POST /tasks` with
`<script>alert(document.cookie)</script>` as the title, then reads the task
back to confirm the payload is stored raw.

**Expected result:**
- Vulnerable: HTTP 201, the payload is accepted and returned unescaped by
  the API
- Hardened: HTTP 400, `validator.py` rejects the disallowed characters
  before the item is ever written

## Attack 3: IDOR (Insecure Direct Object Reference)

**Script:** `03-idor.sh`

**Vulnerability:** `get_task()` and `delete_task()` look up a task by its
`taskId` and act on it without ever comparing the caller's identity to the
task's `userId`. Knowing or guessing a `taskId` is enough to read or delete
any task, regardless of who owns it.

**What the script does:** creates a task for a fake victim user, then reads
and deletes that same task while acting as an attacker who never proves any
identity. An optional `ATTACKER_TOKEN` environment variable can be set once
the hardened authorizer issues real tokens, to simulate an authenticated
attacker targeting someone else's data.

**Expected result:**
- Vulnerable: HTTP 200 on both the read and the delete
- Hardened: HTTP 403, the ownership check rejects the request once the
  caller's `userId` does not match the task owner

## Attack 4: Scraping and cost abuse

**Script:** `04-scraping.sh`

**Vulnerability:** `api_gateway.tf` configures no throttling of any kind.
Every request reaches the Lambda function and the DynamoDB table, so an
attacker can both scrape the entire dataset and drive up the AWS bill by
sheer volume.

**What the script does:** sends a configurable number of concurrent
requests to `GET /tasks` (5000 by default, 50 at a time) and reports the
breakdown of HTTP status codes returned.

**Expected result:**
- Vulnerable: requests succeed with HTTP 200 almost across the board. A
  small number may fail with HTTP 503 if the AWS account's default Lambda
  concurrency limit is briefly exceeded, this is an accidental account level
  ceiling, not a security control
- Hardened: once the 100 req/s API Gateway throttle is exceeded, requests
  start failing with a predictable HTTP 429

## Running the full sequence

```bash
cd attack-simulation/scripts

./01-enumeration.sh vulnerable
./02-injection.sh vulnerable
./03-idor.sh vulnerable
./04-scraping.sh vulnerable

# after the hardened version is deployed
./01-enumeration.sh hardened
./02-injection.sh hardened
./03-idor.sh hardened
./04-scraping.sh hardened
```

Screenshots taken during each run are collected in
[`forensic/findings/`](../forensic/findings).

## Safety note

All attacks in this simulation were run against infrastructure owned and
controlled by the project author, in compliance with the
[AWS Penetration Testing policy](https://aws.amazon.com/security/penetration-testing/).
No third-party systems were involved.

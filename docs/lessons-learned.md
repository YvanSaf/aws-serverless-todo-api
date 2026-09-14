# Lessons Learned

This document collects what actually went wrong, or was not obvious in
advance, while building and testing this project. It is written for my
own future reference, and for anyone reviewing this repository who
wants to see the debugging process, not just the final result.

## Vocareum blocked the whole approach before it started

The original plan was to build this project inside the AWS Academy
Vocareum sandbox used for the AWS certifications. That sandbox blocks
`apigateway:POST` and `apigateway:PUT`, which makes it impossible to
create an HTTP API at all. The vulnerable Terraform files were written
and ready before this was discovered. The entire project, vulnerable
and hardened, ended up deployed on a personal AWS account instead.

Lesson: verify that a training sandbox actually allows the AWS API
calls a project needs before writing infrastructure code against it,
not after.

## Terraform state does not know it changed AWS accounts

After switching to the personal account, the first `terraform plan`
failed trying to read an SNS topic that belonged to a completely
different AWS account, the old Vocareum sandbox. The local
`terraform.tfstate` file still referenced resources from that account,
and Terraform tried to refresh them with the new account's credentials,
which of course had no permission on someone else's resources.

Lesson: a local Terraform state file is tied to whichever account
created it. Switching accounts means starting from a clean state
(`.terraform/`, `.tfstate`, `.tfstate.backup` all removed), not just
switching credentials.

## A short alias is not a valid ARN everywhere

`kms_key_arn = "alias/aws/dynamodb"` looks like it should work, since
that is the alias AWS itself displays in the console, but the
`aws_dynamodb_table` resource rejects it as an invalid ARN. The
simplest fix was also the correct one: leave `kms_key_arn` unset
entirely, and DynamoDB falls back to the AWS managed key
automatically when encryption is enabled.

Lesson: an AWS console label and a Terraform argument are not always
interchangeable strings, and the fix for a "hardening" feature is
sometimes to configure less, not more.

## Reserved concurrency needs headroom you might not have

Setting `reserved_concurrent_executions = 10` on the API Lambda failed
with an error about the account's unreserved concurrency dropping
below the required minimum of 10. A fresh personal AWS account can
have a total Lambda concurrency limit low enough that reserving any
meaningful amount for one function leaves too little for the rest of
the account. The fix was to drop reserved concurrency for this project
and rely on the API Gateway throttle instead, rather than hardcode a
number that happens to work today and might not tomorrow.

Lesson: reserved concurrency is an account wide budget, not a
per-function setting in isolation. Check
`aws lambda get-account-settings` before assuming a value like 10 is
safe to reserve.

## HTTP API authorizers answer 401 and 403 differently depending on why

A request with no `Authorization` header at all gets a native 401 from
API Gateway, before the Lambda Authorizer is ever invoked, because the
identity source it needs is missing. A request that does carry a token,
but one the authorizer rejects (`isAuthorized: false`), gets a 403 from
API Gateway's default denial response for a REQUEST authorizer using
the simple response format. Both are "you are not allowed in", but
they come from different layers and different reasons, and confusing
them cost real debugging time while chasing what looked like an
ownership bug but was actually an expired token.

Lesson: read the actual response body, not just the status code, and
know which layer (API Gateway's own identity source check versus the
authorizer's own logic) produced it.

## The authorizer's cache holds onto a bad verdict

`jwt_authorizer_cache_ttl = 300` means API Gateway caches the
authorizer's decision for a given token for five minutes. Sending 2000
requests with the same expired or invalid token does not invoke the
authorizer 2000 times, it invokes it once, caches the denial, and
serves that same denial to every subsequent request instantly. This
initially looked like the throttle blocking everything with a 403
instead of a 429, when the real cause was a stale token cached at the
authorizer layer.

Lesson: when testing with a cached authorizer, always mint a fresh
token immediately before the test, and remember that a single bad
token can silently poison an entire test run for the length of the
cache TTL.

## The account's own Lambda concurrency limit can hide the feature being tested

Even with a valid token, a scraping test at 150 concurrent requests
mostly produced 503s, not the 429s the throttle was supposed to
produce. The account's default Lambda concurrency limit was 10, far
below both the test's concurrency and the configured
`throttling_rate_limit` of 100 requests per second. The real
throughput never got close to 100 req/s because only 10 Lambda
invocations could ever run at once, so requests queued or failed with
503 from Lambda's own concurrency limit before enough sustained volume
built up to trigger the API Gateway throttle.

The fix was not to fight the account limit, but to lower
`throttling_rate_limit` to a value the account could actually exceed
(5 req/s) for the purpose of the demonstration, while documenting in
`terraform.tfvars.example` why that number is lower than what a real
deployment would use.

Lesson: a security control can be correctly configured and still be
untestable in practice if a more restrictive limit exists underneath
it. Know the account's own ceilings before designing a test to exceed
a higher configured one.

## A secret shown once in a screenshot should be treated as compromised

While capturing a terminal screenshot of the scraping attack, the
`JWT_SECRET` value used to generate a test token was visible in plain
text in the exported shell command. It was blurred before the
screenshot was shared, but the more durable lesson is about the
underlying habit, not the redaction after the fact.

Lesson: avoid putting secrets directly on the command line where shell
history and terminal screenshots can capture them. Reading a secret
from a file or a secrets manager, rather than typing it inline, avoids
this class of mistake entirely rather than relying on catching it
during screenshot review.

## Consistency rules are easy to state and easy to drift from

The project's own style rules (no em dashes, `yvan-saf` as owner,
English throughout) were violated in early files without anyone
intending to, an em dash in a docstring here, a leftover Vocareum
comment there. Catching these required deliberately grepping for the
character and the stale references rather than trusting a first read
through.

Lesson: style and consistency rules for a portfolio project are worth
enforcing with a search command, not just a visual scan, especially
across many files written over many sessions.

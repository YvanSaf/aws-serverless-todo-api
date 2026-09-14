# ADR-0001: Monolithic Lambda for all Todo API routes

## Status

Accepted

## Context

The Todo API exposes five routes: create, list, get, update and delete a
task. There are two common ways to package this in Lambda:

- One function per route (five small, single-purpose functions)
- One function handling every route, dispatching internally on the
  HTTP method and path

Both approaches are common in serverless architectures. The choice
mostly trades operational granularity against simplicity.

## Decision

A single Lambda function (`handler.py`) handles all five routes. It
inspects `requestContext.http.method` and `rawPath` and dispatches to
the matching internal function (`create_task`, `list_tasks`, and so
on).

## Consequences

### Positive

- One deployment package, one IAM role, one set of environment
  variables to manage for the entire API surface
- Fewer Terraform resources and fewer moving parts to keep in sync
  between the vulnerable and hardened versions
- All five routes need the exact same DynamoDB permissions in this
  project, so splitting them would not have reduced the IAM blast
  radius, the usual argument for per-route functions

### Negative

- Memory and timeout are shared across all routes, even though list
  and get are cheaper operations than create or update
- A bug introduced in one route's code path is redeployed alongside
  every other route, since they all live in the same package
- Cold starts affect the whole API surface at once rather than being
  isolated to a single route

## Alternatives considered

**One function per route.** Rejected for this project. It would add
five times the Terraform resources and five IAM roles to maintain for
no real security benefit here, since every route needs the same
DynamoDB actions. This tradeoff would look different on a larger API
where routes have meaningfully different permission needs or wildly
different performance profiles.

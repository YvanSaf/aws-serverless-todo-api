# ADR-0002: HTTP API instead of REST API for API Gateway

## Status

Accepted

## Context

API Gateway offers two product types: REST API (the original, feature
rich option with usage plans, API keys, request validation models and
resource policies) and HTTP API (newer, cheaper, lower latency, with a
smaller feature set and native JWT authorizer support for OIDC or
Cognito).

This project needs: five routes behind a Lambda proxy integration, a
custom authorizer, CORS, and basic throttling. It does not need usage
plans, API keys, or request validation models, since input validation
is handled in `validator.py` inside the Lambda function itself.

## Decision

HTTP API was used for both the vulnerable and hardened versions.

## Consequences

### Positive

- Meaningfully cheaper per request than REST API, and lower latency
- Native CORS configuration block, no need to hand roll OPTIONS routes
- The Lambda REQUEST authorizer with a simple response format was
  enough to implement JWT verification without adopting Cognito
- Throttling on the default stage covers the rate limiting need for
  this project

### Negative

- No built in JSON schema request validation, which is why
  `validator.py` exists as application level validation instead of a
  declarative API Gateway model
- No usage plans or API keys, so per-client quotas beyond the global
  throttle are not available if the project grows to need them
- The native JWT authorizer type (built for OIDC and Cognito token
  formats) could not be used as is, since the project signs its own
  JWTs with a shared secret rather than an OIDC provider, so a custom
  Lambda authorizer was required regardless

## Alternatives considered

**REST API.** Rejected for this project. Its request validation models
and usage plans would have been convenient, but the added cost and
setup complexity are not justified for a demo API with a single
consumer pattern. REST API would be worth revisiting if the project
grew to need per-client API keys or declarative request validation
without touching Lambda code.

# ADR-0003: Custom JWT Lambda Authorizer instead of Cognito or API keys

## Status

Accepted

## Context

The hardened version needs authentication in front of every route. Three
options were considered:

- A custom JWT (HS256) signed with a shared secret, verified by a
  Lambda Authorizer
- Amazon Cognito User Pool, with API Gateway's native JWT authorizer
- Per-user API keys stored in a DynamoDB table, checked by a Lambda
  Authorizer

## Decision

A custom JWT signed with a shared secret was used. `authorizer.py`
verifies the token's signature and expiry with PyJWT, extracts the
`sub` claim as the caller's `userId`, and returns it in the authorizer
context. The shared secret lives in the authorizer Lambda's environment
variable `JWT_SECRET`, set from a Terraform variable that is never
committed. `generate_token.py` mints test tokens for the attack
simulation scripts.

## Consequences

### Positive

- No additional managed service to provision, configure or pay for
- Fast to build, test and script against, `generate_token.py` lets the
  attack simulation mint tokens for two different users to exercise
  the ownership check in `03-idor.sh`
- Demonstrates end to end understanding of JWT verification, claim
  handling and Lambda Authorizer wiring, rather than delegating that
  logic to a managed service

### Negative

- No registration, login, password policy or MFA, this is
  authentication in the narrow sense of "prove which userId you are",
  not a real identity system
- No token refresh flow, tokens are minted once with a fixed expiry
- A single shared secret is a single point of compromise: if it leaks,
  anyone can forge a valid token for any `userId`. This happened once
  during testing, when the secret appeared in plaintext in a terminal
  screenshot, which is documented in `docs/lessons-learned.md`
- The secret sits in a Lambda environment variable, visible in
  plaintext to anyone with read access to the function's configuration
  in the console, rather than in a secrets manager with access
  auditing

This is acceptable for a project with no real users or personal data
behind it, and intentionally not a claim that this authentication
scheme is production ready.

## Alternatives considered

**Amazon Cognito.** Rejected due to setup overhead disproportionate to
the project's scope, a User Pool, an app client and either a hosted UI
or SDK integration would have added significant Terraform and testing
surface for a demo API. Cognito is the right choice for a project with
real end users.

**DynamoDB backed API keys.** Rejected because it does not exercise
JWT verification, and still requires solving the same key distribution
problem as the shared secret, without the benefit of an expiry claim
built into the token itself.

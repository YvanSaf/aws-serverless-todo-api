# ADR-0004: AWS managed KMS key instead of a customer managed key

## Status

Accepted

## Context

DynamoDB encryption at rest supports three key options:

- AWS owned key: default, free, not visible or manageable in the KMS
  console
- AWS managed key (`aws/dynamodb`): free, visible in the KMS console,
  shared across the account for DynamoDB specifically
- Customer managed key (CMK): full control over the key policy,
  rotation schedule and CloudTrail audit trail, billed monthly per key
  plus per API request

## Decision

The hardened version enables encryption with `server_side_encryption`
and leaves `kms_key_arn` unset, which makes DynamoDB use the AWS
managed key automatically.

## Consequences

### Positive

- No additional cost, unlike a CMK which bills monthly even at rest
- Encryption is deliberate and visible in the console, unlike the
  vulnerable version which does not configure it at all, which is the
  actual point being demonstrated for this project
- No key policy or rotation schedule to design and maintain

### Negative

- No custom key policy, so access to the key cannot be restricted to
  specific principals beyond what DynamoDB itself requires
- No independent control over key rotation or deletion
- Less audit granularity than a CMK provides through CloudTrail
- Would not satisfy compliance regimes that require customer
  controlled keys or data residency guarantees tied to a specific key

## Alternatives considered

**Customer managed key.** Rejected for this project. A personal AWS
account demo with no real data does not need a custom key policy or an
independent rotation schedule, and a CMK's monthly charge buys no
functional benefit here. A CMK is the right choice for a production
system with compliance requirements around key ownership or access
auditing.

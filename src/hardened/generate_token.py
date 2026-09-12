#!/usr/bin/env python3
"""
generate_token.py

Mint a JWT bearer token for testing the hardened Todo API.

The secret must match the jwt_secret value set in
infra/terraform/hardened/terraform.tfvars, since that same value is
what the authorizer Lambda uses to verify tokens.

Usage:
    JWT_SECRET="<same value as terraform.tfvars>" python3 generate_token.py <userId> [expiry_minutes]

Example:
    JWT_SECRET="my-local-secret" python3 generate_token.py alice-001
    JWT_SECRET="my-local-secret" python3 generate_token.py alice-001 5
"""

import os
import sys
import time
import jwt


def main():
    if len(sys.argv) < 2:
        print("Usage: JWT_SECRET=... python3 generate_token.py <userId> [expiry_minutes]")
        sys.exit(1)

    secret = os.environ.get("JWT_SECRET")
    if not secret:
        print("Error: set the JWT_SECRET environment variable to the value of jwt_secret in terraform.tfvars")
        sys.exit(1)

    user_id = sys.argv[1]
    expiry_minutes = int(sys.argv[2]) if len(sys.argv) > 2 else 60

    now = int(time.time())
    payload = {
        "sub": user_id,
        "iat": now,
        "exp": now + expiry_minutes * 60,
    }

    token = jwt.encode(payload, secret, algorithm="HS256")
    print(token)


if __name__ == "__main__":
    main()

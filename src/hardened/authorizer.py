"""
Lambda Authorizer for the hardened Todo API.

Validates a JWT bearer token on every request and returns the caller's
userId in the authorizer context, so the handler never has to trust
anything the client sends about its own identity.

This is a REQUEST authorizer using the simple response format for
HTTP APIs (payload format version 2.0). See infra/terraform/hardened/
api_gateway.tf for the authorizer resource configuration.
"""

import os
import jwt

JWT_SECRET = os.environ["JWT_SECRET"]
JWT_ALGORITHM = "HS256"


def lambda_handler(event, context):
    token = extract_bearer_token(event)

    if not token:
        return deny()

    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
    except jwt.InvalidTokenError:
        # Covers expired signatures, bad signatures, malformed tokens,
        # all treated the same way: deny, no details leaked to the caller.
        return deny()

    user_id = payload.get("sub")
    if not user_id:
        return deny()

    return allow(user_id)


def extract_bearer_token(event):
    headers = event.get("headers") or {}
    # API Gateway lowercases header names for HTTP APIs.
    auth_header = headers.get("authorization") or headers.get("Authorization")

    if not auth_header or not auth_header.startswith("Bearer "):
        return None

    return auth_header[len("Bearer "):].strip()


def allow(user_id):
    return {
        "isAuthorized": True,
        "context": {
            "userId": user_id
        }
    }


def deny():
    return {
        "isAuthorized": False,
        "context": {}
    }

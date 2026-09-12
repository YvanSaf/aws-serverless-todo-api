"""
Hardened Todo API, handler.py

Fixes applied relative to src/vulnerable/handler.py:
1. Authentication: every request has already passed through the Lambda
   Authorizer (see authorizer.py) before reaching this function. The
   caller's userId comes from the authorizer context, never from the
   request body.
2. Input validation: title, description and status are validated by
   validator.py before anything is written to DynamoDB.
3. Ownership check: get, update and delete verify that the caller's
   userId matches the task owner before acting on it.
4. Query instead of Scan: list_tasks reads only the caller's own tasks
   from the userId-index GSI, never the whole table.
5. Errors return a generic message, no internal details are exposed.
"""

import json
import os
import uuid
import boto3
from boto3.dynamodb.conditions import Key
from datetime import datetime, timezone
from botocore.exceptions import ClientError

from aws_xray_sdk.core import patch_all
patch_all()

from validator import validate_task_payload, ValidationError

dynamodb = boto3.resource("dynamodb")
TABLE_NAME = os.environ["TABLE_NAME"]
table = dynamodb.Table(TABLE_NAME)


def lambda_handler(event, context):
    method = event.get("requestContext", {}).get("http", {}).get("method", "")
    path = event.get("rawPath", "")
    path_params = event.get("pathParameters") or {}

    # The Lambda Authorizer already rejected the request with a 401 if
    # this is missing. Treat a missing value as fail-closed rather than
    # trusting the caller, in case this handler is ever wired up wrong.
    user_id = (
        event.get("requestContext", {})
        .get("authorizer", {})
        .get("lambda", {})
        .get("userId")
    )

    if not user_id:
        return response(401, {"error": "Unauthorized"})

    try:
        if method == "POST" and path == "/tasks":
            return create_task(user_id, event)

        elif method == "GET" and path == "/tasks":
            return list_tasks(user_id)

        elif method == "GET" and "/tasks/" in path:
            return get_task(user_id, path_params.get("taskId"))

        elif method == "PUT" and "/tasks/" in path:
            return update_task(user_id, path_params.get("taskId"), event)

        elif method == "DELETE" and "/tasks/" in path:
            return delete_task(user_id, path_params.get("taskId"))

        else:
            return response(404, {"error": "Route not found"})

    except ValidationError as e:
        return response(400, {"error": e.message, "field": e.field})

    except ClientError:
        return response(500, {"error": "Internal server error"})

    except Exception:
        return response(500, {"error": "Internal server error"})


def create_task(user_id, event):
    body = json.loads(event.get("body") or "{}")
    validated = validate_task_payload(body, partial=False)

    task_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc).isoformat()

    item = {
        "taskId": task_id,
        "userId": user_id,
        "title": validated["title"],
        "description": validated["description"],
        "status": validated["status"],
        "createdAt": now,
        "updatedAt": now,
    }

    table.put_item(Item=item)

    return response(201, {"message": "Task created", "task": item})


def list_tasks(user_id):
    """
    Query the userId-index GSI instead of scanning the whole table.
    Only the caller's own tasks are ever returned.
    """
    result = table.query(
        IndexName="userId-index",
        KeyConditionExpression=Key("userId").eq(user_id),
    )
    items = result.get("Items", [])

    return response(200, {"tasks": items, "count": len(items)})


def get_task(user_id, task_id):
    result = table.get_item(Key={"taskId": task_id})
    item = result.get("Item")

    if not item:
        return response(404, {"error": "Task not found"})

    if item.get("userId") != user_id:
        return response(403, {"error": "Forbidden"})

    return response(200, {"task": item})


def update_task(user_id, task_id, event):
    body = json.loads(event.get("body") or "{}")

    result = table.get_item(Key={"taskId": task_id})
    item = result.get("Item")

    if not item:
        return response(404, {"error": "Task not found"})

    if item.get("userId") != user_id:
        return response(403, {"error": "Forbidden"})

    validated = validate_task_payload(body, partial=True)

    if not validated:
        return response(400, {"error": "No valid fields to update"})

    now = datetime.now(timezone.utc).isoformat()
    update_expression = "SET updatedAt = :updatedAt"
    expression_values = {":updatedAt": now}
    expression_names = {}

    for field, value in validated.items():
        placeholder = f":{field}"
        if field == "status":
            update_expression += ", #status = :status"
            expression_names["#status"] = "status"
        else:
            update_expression += f", {field} = {placeholder}"
        expression_values[placeholder] = value

    kwargs = {
        "Key": {"taskId": task_id},
        "UpdateExpression": update_expression,
        "ExpressionAttributeValues": expression_values,
    }
    if expression_names:
        kwargs["ExpressionAttributeNames"] = expression_names

    table.update_item(**kwargs)

    return response(200, {"message": "Task updated", "taskId": task_id})


def delete_task(user_id, task_id):
    result = table.get_item(Key={"taskId": task_id})
    item = result.get("Item")

    if not item:
        return response(404, {"error": "Task not found"})

    if item.get("userId") != user_id:
        return response(403, {"error": "Forbidden"})

    table.delete_item(Key={"taskId": task_id})

    return response(200, {"message": "Task deleted", "taskId": task_id})


def response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            # CORS is still permissive here since this is a demo API with
            # no real frontend origin to restrict to. Authentication and
            # ownership checks are the actual security boundary, not CORS.
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(body, default=str),
    }

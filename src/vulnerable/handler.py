"""
Vulnerable Todo API — handler.py
=================================
This file is intentionally insecure for security demonstration purposes.

Vulnerabilities present in this version:
1. No authentication — any caller can perform any action
2. No input validation — any payload is accepted and stored as-is
3. No ownership check — any user can read, update or delete any task
4. Scan used instead of Query — returns ALL items from ALL users
5. userId comes from the request body — anyone can impersonate any user
6. Errors expose internal details — stack traces returned to the caller

Do NOT use this code in production.
See src/hardened/handler.py for the corrected implementation.
"""

import json
import os
import uuid
import boto3
from datetime import datetime, timezone

# DynamoDB client initialized outside the handler
# so it is reused across warm invocations
dynamodb = boto3.resource("dynamodb")
TABLE_NAME = os.environ["TABLE_NAME"]
table = dynamodb.Table(TABLE_NAME)


def lambda_handler(event, context):
    """
    Main entry point for all routes.
    Routes are dispatched based on the HTTP method and path.
    """
    method = event.get("requestContext", {}).get("http", {}).get("method", "")
    path = event.get("rawPath", "")
    path_params = event.get("pathParameters") or {}

    try:
        if method == "POST" and path == "/tasks":
            return create_task(event)

        elif method == "GET" and path == "/tasks":
            return list_tasks()

        elif method == "GET" and "/tasks/" in path:
            return get_task(path_params.get("taskId"))

        elif method == "PUT" and "/tasks/" in path:
            return update_task(path_params.get("taskId"), event)

        elif method == "DELETE" and "/tasks/" in path:
            return delete_task(path_params.get("taskId"))

        else:
            return response(404, {"error": "Route not found"})

    except Exception as e:
        # Vulnerability: full stack trace returned to the caller
        # This reveals internal implementation details to an attacker
        return response(500, {"error": str(e)})


def create_task(event):
    """
    Create a new task.

    Vulnerabilities:
    - No input validation: title can be a script tag, 10000 chars, anything
    - userId comes from the request body: anyone can create tasks as any user
    - No sanitization of any field before storing in DynamoDB
    """
    body = json.loads(event.get("body") or "{}")

    # Vulnerability: userId is taken directly from the request body
    # An attacker can set userId to any value and impersonate any user
    user_id = body.get("userId")
    title = body.get("title")
    description = body.get("description", "")
    status = body.get("status", "todo")

    task_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc).isoformat()

    # Vulnerability: no validation — XSS payload stored directly in DynamoDB
    item = {
        "taskId": task_id,
        "userId": user_id,
        "title": title,
        "description": description,
        "status": status,
        "createdAt": now,
        "updatedAt": now,
    }

    table.put_item(Item=item)

    return response(201, {"message": "Task created", "task": item})


def list_tasks():
    """
    List tasks.

    Vulnerability: uses Scan instead of Query.
    Scan reads the ENTIRE table and returns ALL items from ALL users.
    A single GET /tasks request dumps the entire database.
    This also becomes very expensive at scale — each Scan reads
    every item regardless of how many are needed.
    """
    result = table.scan()
    items = result.get("Items", [])

    # Vulnerability: returns ALL tasks from ALL users with no filtering
    return response(200, {"tasks": items, "count": len(items)})


def get_task(task_id):
    """
    Get a single task by ID.

    Vulnerability: no ownership check.
    Any caller who knows (or guesses) a taskId can read that task,
    regardless of which user it belongs to.
    Task IDs are UUIDs but they can be harvested via the list endpoint.
    """
    result = table.get_item(Key={"taskId": task_id})
    item = result.get("Item")

    if not item:
        return response(404, {"error": "Task not found"})

    # Vulnerability: no check that the caller owns this task
    return response(200, {"task": item})


def update_task(task_id, event):
    """
    Update a task.

    Vulnerabilities:
    - No ownership check: anyone can modify any task
    - No input validation: any value is accepted for any field
    - userId in the update body is not verified
    """
    body = json.loads(event.get("body") or "{}")

    # Check the task exists first
    result = table.get_item(Key={"taskId": task_id})
    if not result.get("Item"):
        return response(404, {"error": "Task not found"})

    # Vulnerability: no check that the caller owns this task
    # Vulnerability: no validation of the fields being updated
    now = datetime.now(timezone.utc).isoformat()

    update_expression = "SET updatedAt = :updatedAt"
    expression_values = {":updatedAt": now}

    if "title" in body:
        update_expression += ", title = :title"
        expression_values[":title"] = body["title"]

    if "description" in body:
        update_expression += ", description = :description"
        expression_values[":description"] = body["description"]

    if "status" in body:
        update_expression += ", #s = :status"
        expression_values[":status"] = body["status"]

    expression_names = {"#s": "status"}

    table.update_item(
        Key={"taskId": task_id},
        UpdateExpression=update_expression,
        ExpressionAttributeValues=expression_values,
        ExpressionAttributeNames=expression_names,
    )

    return response(200, {"message": "Task updated", "taskId": task_id})


def delete_task(task_id):
    """
    Delete a task.

    Vulnerability: no ownership check.
    Any caller who knows a taskId can delete that task permanently.
    Combined with the list endpoint, an attacker can delete
    every task in the database.
    """
    result = table.get_item(Key={"taskId": task_id})
    if not result.get("Item"):
        return response(404, {"error": "Task not found"})

    # Vulnerability: no check that the caller owns this task
    table.delete_item(Key={"taskId": task_id})

    return response(200, {"message": "Task deleted", "taskId": task_id})


def response(status_code, body):
    """
    Build an HTTP response object for API Gateway.
    """
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            # Vulnerability: CORS wide open — any origin is allowed
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(body, default=str),
    }

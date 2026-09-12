"""
Input validator for the hardened Todo API.

Rejects titles and descriptions containing HTML or script-like content
and enforces length limits, instead of accepting anything and storing
it as-is like src/vulnerable/handler.py does.
"""

import re

MAX_TITLE_LENGTH = 200
MAX_DESCRIPTION_LENGTH = 2000
ALLOWED_STATUSES = {"todo", "in_progress", "done"}

# Denylist approach: good enough to block the script tag payload used in
# the attack simulation. This is not a substitute for proper output
# encoding on whatever frontend eventually renders this data.
DANGEROUS_PATTERN = re.compile(
    r"<\s*script|<\s*/\s*script|<[^>]+>|javascript:|on\w+\s*=",
    re.IGNORECASE,
)


class ValidationError(Exception):
    """Raised when a field fails validation."""

    def __init__(self, field, message):
        self.field = field
        self.message = message
        super().__init__(f"{field}: {message}")


def validate_title(title):
    if not isinstance(title, str) or not title.strip():
        raise ValidationError("title", "title is required and must be a non-empty string")
    if len(title) > MAX_TITLE_LENGTH:
        raise ValidationError("title", f"title must be {MAX_TITLE_LENGTH} characters or fewer")
    if DANGEROUS_PATTERN.search(title):
        raise ValidationError("title", "title contains disallowed HTML or script content")
    return title.strip()


def validate_description(description):
    if description is None:
        return ""
    if not isinstance(description, str):
        raise ValidationError("description", "description must be a string")
    if len(description) > MAX_DESCRIPTION_LENGTH:
        raise ValidationError("description", f"description must be {MAX_DESCRIPTION_LENGTH} characters or fewer")
    if DANGEROUS_PATTERN.search(description):
        raise ValidationError("description", "description contains disallowed HTML or script content")
    return description.strip()


def validate_status(status):
    if status is None:
        return "todo"
    if status not in ALLOWED_STATUSES:
        raise ValidationError("status", f"status must be one of {sorted(ALLOWED_STATUSES)}")
    return status


def validate_task_payload(body, partial=False):
    """
    Validate a task creation or update payload.

    When partial is True (update), a field is only validated if it is
    present in the body, so a PUT can update a single field without
    resending the others. When partial is False (create), title is
    always required and description/status fall back to defaults.
    """
    result = {}

    if not partial or "title" in body:
        result["title"] = validate_title(body.get("title"))

    if not partial or "description" in body:
        result["description"] = validate_description(body.get("description"))

    if not partial or "status" in body:
        result["status"] = validate_status(body.get("status"))

    return result

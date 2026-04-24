#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Iterable


REQUIRED_PAGE_IDS = {
    "console-login",
    "console-dashboard",
    "console-consumer",
    "console-model-assets",
    "console-provider",
    "console-ai-route",
    "console-ai-quota",
    "console-agent-catalog",
    "console-mcp-list",
    "console-system-jobs",
    "portal-login",
    "portal-models",
    "portal-agents",
    "portal-ai-chat",
    "portal-billing",
    "portal-open-platform",
    "portal-accounts",
}

REQUIRED_FLOW_IDS = {
    "console-ai-route-edit",
    "console-model-binding-publish",
    "console-agent-publish-toggle",
    "portal-api-key-create",
    "portal-recharge-submit",
    "portal-ai-chat-send",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate Chrome DevTools acceptance artifacts.")
    parser.add_argument("--summary", required=True, help="Path to acceptance summary.json")
    return parser.parse_args()


def fail(errors: Iterable[str]) -> None:
    for error in errors:
        print(f"[ERROR] {error}")
    raise SystemExit(1)


def validate_status_items(items: list[dict], required_ids: set[str], item_name: str) -> list[str]:
    errors: list[str] = []
    by_id = {str(item.get("id", "")).strip(): item for item in items}

    for required_id in sorted(required_ids):
        if required_id not in by_id:
            errors.append(f"Missing {item_name}: {required_id}")
            continue

        item = by_id[required_id]
        status = str(item.get("status", "")).strip().lower()
        if status != "pass":
            errors.append(f"{item_name} {required_id} must be pass, got {status or 'empty'}")

        console_errors = item.get("consoleErrors", [])
        if console_errors:
            errors.append(f"{item_name} {required_id} still has consoleErrors: {console_errors}")

        network_failures = item.get("networkFailures", [])
        if network_failures:
            errors.append(f"{item_name} {required_id} still has networkFailures: {network_failures}")

    return errors


def main() -> None:
    args = parse_args()
    summary_path = Path(args.summary)

    if not summary_path.is_file():
        fail(
            [
                f"Acceptance summary not found: {summary_path}",
                "Fill the generated template with Chrome DevTools acceptance results, then rerun ./start.sh test --stage acceptance.",
            ]
        )

    data = json.loads(summary_path.read_text(encoding="utf-8"))
    errors: list[str] = []

    if data.get("tool") != "chrome-devtools":
        errors.append("summary.json field 'tool' must equal 'chrome-devtools'")

    if not str(data.get("executedAt", "")).strip():
        errors.append("summary.json field 'executedAt' is required")

    if not str(data.get("operator", "")).strip():
        errors.append("summary.json field 'operator' is required")

    base_urls = data.get("baseUrls", {})
    if not str(base_urls.get("console", "")).strip():
        errors.append("summary.json field 'baseUrls.console' is required")
    if not str(base_urls.get("portal", "")).strip():
        errors.append("summary.json field 'baseUrls.portal' is required")

    pages = data.get("pages", [])
    flows = data.get("flows", [])
    if not isinstance(pages, list):
        errors.append("summary.json field 'pages' must be a list")
        pages = []
    if not isinstance(flows, list):
        errors.append("summary.json field 'flows' must be a list")
        flows = []

    errors.extend(validate_status_items(pages, REQUIRED_PAGE_IDS, "page"))
    errors.extend(validate_status_items(flows, REQUIRED_FLOW_IDS, "flow"))

    if errors:
        fail(errors)

    print(f"[OK] Chrome DevTools acceptance summary validated: {summary_path}")


if __name__ == "__main__":
    main()

import json
import logging
from datetime import UTC, datetime
from typing import Any

_logger = logging.getLogger("navidrome_nas_agent.audit")


def audit_event(event: str, **fields: Any) -> None:
    payload = {
        "timestamp": datetime.now(UTC).isoformat(),
        "event": event,
        **fields,
    }
    _logger.info(json.dumps(payload, ensure_ascii=False, separators=(",", ":"), default=str))

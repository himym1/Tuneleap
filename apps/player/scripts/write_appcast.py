#!/usr/bin/env python3
"""Write a Sparkle 2 appcast.xml for the private Cloud update channel."""

from __future__ import annotations

import argparse
import html
import re
from datetime import datetime, timezone
from email.utils import format_datetime
from pathlib import Path
from urllib.parse import urlsplit

_VERSION = re.compile(r"^\d+\.\d+\.\d+$")
_SIGNATURE = re.compile(r'^[A-Za-z0-9+/]+=*$')


def validate_origin(origin: str) -> str:
    parsed = urlsplit(origin)
    if (
        parsed.scheme != "https"
        or not parsed.netloc
        or parsed.username is not None
        or parsed.password is not None
        or parsed.path not in ("", "/")
        or parsed.query
        or parsed.fragment
    ):
        raise ValueError(f"Invalid UPDATE_ORIGIN: {origin}")
    return origin.rstrip("/")


def parse_sign_update_output(output: str) -> tuple[str, int]:
    signature = ""
    length = 0
    for part in output.replace("\n", " ").split():
        if part.startswith("sparkle:edSignature="):
            signature = part.split("=", 1)[1].strip().strip('"')
        elif part.startswith("length="):
            length = int(part.split("=", 1)[1].strip().strip('"'))
    if not signature or not _SIGNATURE.fullmatch(signature):
        raise ValueError("sign_update did not print a sparkle:edSignature")
    if length < 1:
        raise ValueError("sign_update did not print a positive length")
    return signature, length


def render_appcast(
    *,
    origin: str,
    macos_version: str,
    macos_build: int,
    macos_name: str,
    signature: str,
    length: int,
    changelog: str,
    pub_date: datetime | None = None,
) -> str:
    if not _VERSION.fullmatch(macos_version):
        raise ValueError(f"Invalid version: {macos_version}")
    if macos_build < 1:
        raise ValueError(f"Invalid build: {macos_build}")
    if not re.fullmatch(
        r"navidrome_player-\d+\.\d+\.\d+\+\d+-macos\.dmg", macos_name
    ):
        raise ValueError(f"Invalid macOS artifact name: {macos_name}")
    if not _SIGNATURE.fullmatch(signature):
        raise ValueError("Invalid EdDSA signature")
    if length < 1:
        raise ValueError("Invalid enclosure length")
    base = validate_origin(origin)
    enclosure = f"{base}/releases/{macos_name}"
    notes = html.escape(changelog.strip() or macos_version, quote=False)
    published = format_datetime(pub_date or datetime.now(timezone.utc))
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<rss version="2.0" '
        'xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">\n'
        "  <channel>\n"
        "    <title>音跃</title>\n"
        "    <language>zh-cn</language>\n"
        "    <item>\n"
        f"      <title>Version {html.escape(macos_version)}</title>\n"
        f"      <sparkle:version>{macos_build}</sparkle:version>\n"
        f"      <sparkle:shortVersionString>"
        f"{html.escape(macos_version)}</sparkle:shortVersionString>\n"
        f"      <description><![CDATA[{notes}]]></description>\n"
        f"      <pubDate>{published}</pubDate>\n"
        f'      <enclosure url="{html.escape(enclosure, quote=True)}"\n'
        f'                 sparkle:edSignature="{html.escape(signature, quote=True)}"\n'
        f'                 sparkle:os="macos"\n'
        f'                 length="{length}"\n'
        '                 type="application/octet-stream" />\n'
        "    </item>\n"
        "  </channel>\n"
        "</rss>\n"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--origin", required=True)
    parser.add_argument("--macos-version", required=True)
    parser.add_argument("--macos-build", required=True, type=int)
    parser.add_argument("--macos-name", required=True)
    parser.add_argument("--signature", default="")
    parser.add_argument("--length", default=0, type=int)
    parser.add_argument("--sign-output", default="")
    parser.add_argument("--changelog", default="")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    signature = args.signature
    length = args.length
    if args.sign_output:
        signature, length = parse_sign_update_output(args.sign_output)
    Path(args.output).write_text(
        render_appcast(
            origin=args.origin,
            macos_version=args.macos_version,
            macos_build=args.macos_build,
            macos_name=args.macos_name,
            signature=signature,
            length=length,
            changelog=args.changelog,
        ),
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()

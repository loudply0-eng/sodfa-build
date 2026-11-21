#!/usr/bin/env python3
"""Build a validated SODFA OTA manifest from the matching changelog entry."""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path
from urllib.parse import urlsplit


def fail(message: str) -> None:
    raise SystemExit(message)


def build_manifest(changelog: dict, env: dict[str, str]) -> dict:
    version = env.get("VERSION", "")
    build_raw = env.get("BUILD_NUMBER", "")
    apk_url = env.get("APK_URL", "")
    apk_sha256 = env.get("APK_SHA256", "")

    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        fail("VERSION must use semantic numeric version syntax.")
    if not re.fullmatch(r"[1-9][0-9]*", build_raw):
        fail("BUILD_NUMBER must be a positive integer.")
    build_number = int(build_raw)
    if not re.fullmatch(r"[a-fA-F0-9]{64}", apk_sha256):
        fail("APK_SHA256 must be a 64-character hexadecimal digest.")

    parsed_url = urlsplit(apk_url)
    expected_filename = f"sodfa-{version}+{build_number}.apk"
    if (
        parsed_url.scheme != "https"
        or not parsed_url.hostname
        or parsed_url.username is not None
        or parsed_url.password is not None
        or parsed_url.query
        or parsed_url.fragment
        or parsed_url.path != f"/updates/sodfa/{expected_filename}"
    ):
        fail("APK_URL must be the exact HTTPS SODFA release path for this version/build.")

    if not isinstance(changelog, dict) or changelog.get("schema_version") != 1:
        fail("CHANGELOG.json has an unsupported schema_version.")
    releases = changelog.get("releases")
    if not isinstance(releases, list):
        fail("CHANGELOG.json releases must be a list.")

    matching = [
        item for item in releases
        if isinstance(item, dict)
        and item.get("version") == version
        and item.get("build_number") == build_number
    ]
    if len(matching) != 1:
        fail("CHANGELOG.json must contain exactly one entry matching pubspec.yaml.")

    release = matching[0]
    title = release.get("title", "تحديث جديد لصدفة")
    changes = release.get("changes")
    release_date = release.get("date", "")
    if not isinstance(title, str) or not title.strip() or len(title) > 200:
        fail("The matching changelog title must be a non-empty string of at most 200 characters.")
    if (
        not isinstance(changes, list)
        or not changes
        or len(changes) > 20
        or not all(isinstance(item, str) and item.strip() and len(item) <= 240 for item in changes)
    ):
        fail("The matching changelog must contain 1–20 valid change entries (max 240 characters each).")
    if not isinstance(release_date, str) or len(release_date) > 40:
        fail("The matching changelog date must be a string of at most 40 characters.")

    force_update = release.get("force_update", False)
    minimum_build = release.get("min_supported_build", 1)
    rollout_percentage = release.get("rollout_percentage", 100)
    if not isinstance(force_update, bool):
        fail("force_update in CHANGELOG.json must be a boolean.")
    if (
        isinstance(minimum_build, bool)
        or not isinstance(minimum_build, int)
        or not 1 <= minimum_build <= build_number
    ):
        fail("min_supported_build must be an integer between 1 and the release build number.")
    if (
        isinstance(rollout_percentage, bool)
        or not isinstance(rollout_percentage, int)
        or not 0 <= rollout_percentage <= 100
    ):
        fail("rollout_percentage must be an integer between 0 and 100.")

    return {
        "application_id": "com.sodfa.sodfa",
        "platform": "android",
        "channel": "stable",
        "version": version,
        "build_number": build_number,
        "apk_url": apk_url,
        "sha256": apk_sha256.lower(),
        "release_title": title,
        "release_changes": changes,
        "release_notes": title + "\n\n" + "\n".join("• " + item for item in changes),
        "release_date": release_date,
        "force_update": force_update,
        "min_supported_build": minimum_build,
        "rollout_percentage": rollout_percentage,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--changelog", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    try:
        changelog = json.loads(args.changelog.read_text(encoding="utf-8"))
        manifest = build_manifest(changelog, dict(os.environ))
        args.output.write_text(
            json.dumps(manifest, ensure_ascii=False, separators=(",", ":")) + "\n",
            encoding="utf-8",
        )
    except (OSError, json.JSONDecodeError) as error:
        fail(f"Could not read or write the update manifest: {error}")

    print(f"Validated SODFA manifest for {manifest['version']}+{manifest['build_number']}.")


if __name__ == "__main__":
    main()

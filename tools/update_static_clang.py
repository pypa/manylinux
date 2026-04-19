# /// script
# dependencies = ["lastversion>=3.5.0", "requests"]
# ///

from __future__ import annotations

import argparse
import re
import subprocess
from hashlib import sha256
from pathlib import Path

import requests
from lastversion import latest

PROJECT_ROOT = Path(__file__).parent.parent.resolve(strict=True)
CLANG_VERSIONS = PROJECT_ROOT / "docker" / "build_scripts" / "static_clang_versions.txt"


def get_sha256(url: str) -> str:
    response = requests.get(url, stream=True)
    response.raise_for_status()
    sha256sum = sha256()
    for chunk in response.iter_content(chunk_size=1024 * 4):
        sha256sum.update(chunk)
    return sha256sum.hexdigest()


def update_clang_versions(versions: dict[str, str], updates: list[str]) -> dict[str, str]:
    repo = "mayeut/static-clang-images"
    exclude = None
    new_versions = {}
    while True:
        tag = latest(
            repo=repo,
            output_format="tag",
            having_asset="sha256sums.txt",
            exclude=exclude,
        )
        if tag is None:
            break
        if tag in versions:
            break
        assert tag not in new_versions
        url = f"https://github.com/{repo}/releases/download/{tag}/sha256sums.txt"
        new_versions[tag] = get_sha256(url)
        message = f"adding clang {tag}"
        print(message)
        updates.append(message)
        new_exclude = f"({re.escape(tag)})"
        exclude = f"~{new_exclude}" if exclude is None else f"{exclude}|({new_exclude})"

    new_versions.update(versions)
    return new_versions


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", dest="dry_run", action="store_true", help="dry run")
    args = parser.parse_args()
    versions = {}
    for line in CLANG_VERSIONS.read_text().splitlines():
        if not line:
            continue
        version, sha256sum = line.split()
        versions[version] = sha256sum
    updates = []
    versions = update_clang_versions(versions, updates)
    if not args.dry_run:
        versions_text = "\n".join(
            [*(f"{version} {sha256sum}" for version, sha256sum in versions.items()), ""]
        )
        CLANG_VERSIONS.write_text(versions_text)
        if updates:
            details = "\n".join(f"- {message}" for message in updates)
            subprocess.check_call(["git", "commit", "-am", "Update clang versions", "-m", details])


if __name__ == "__main__":
    main()

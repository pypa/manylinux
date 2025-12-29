# /// script
# dependencies = ["packaging", "requests"]
# ///

import argparse
import configparser
import datetime
import functools
import os
import re
import subprocess
import sys
import tempfile
from collections import defaultdict
from pathlib import Path

from packaging.version import Version
from requests import Session
from requests.adapters import HTTPAdapter
from urllib3.util import Retry


@functools.cache
def requests_session() -> Session:
    retries = Retry(
        total=3,
        backoff_factor=0.1,
        status_forcelist=[500, 502, 503, 504],
        allowed_methods={"GET", "POST"},
    )
    adapter = HTTPAdapter(max_retries=retries)
    s = Session()
    s.mount("https://", adapter)
    s.mount("http://", adapter)
    return s


def update_cibuildwheel_tags(version: str, tags: dict[str, set[str]]) -> None:
    print(f"Updating image tags for cibuildwheel {version}")
    subprocess.run(
        ["git", "checkout", version],
        check=True,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    config_path = Path("cibuildwheel/resources/pinned_docker_images.cfg")
    if not config_path.is_file():
        print(f"::error::no configuration for cibuildwheel {version}")
        sys.exit(1)
    config = configparser.ConfigParser()
    config.read(config_path)
    for section in config.sections():
        for value in config[section].values():
            if not value.startswith("quay.io/pypa/"):
                continue
            image, tag = value[13:].split(":")
            tags[image].add(tag)


def get_cibuildwheel_tags() -> dict[str, set[str]]:
    result = defaultdict(set)
    cwd = os.getcwd()
    with tempfile.TemporaryDirectory() as tmpdir:
        subprocess.run(
            ["git", "clone", "--tags", "https://github.com/pypa/cibuildwheel.git", str(tmpdir)],
            check=True,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        try:
            os.chdir(tmpdir)
            git_tags = subprocess.run(
                ["git", "tag", "--list"],
                check=True,
                stdin=subprocess.DEVNULL,
                capture_output=True,
                text=True,
            )
            versions = [version for version in git_tags.stdout.splitlines() if version]
            for version in versions:
                version_ = Version(version)
                if version_ < Version("1.10.0"):
                    # skip older cibuildwheel versions; only protect images from 1.10.0 and later
                    continue
                update_cibuildwheel_tags(version, result)
        finally:
            os.chdir(cwd)
    return result


def get_images_to_delete(
    expiration_date: datetime.date, cibuildwheel_tags: dict[str, set[str]]
) -> list[str]:
    known_missing = {
        "manylinux_2_24_ppc64le:2021-09-06-7b0bd5d",  # cibuildwheel v2.1.2
        "musllinux_1_1_s390x:2021-10-06-94da8f1",  # cibuildwheel v2.1.3
        "manylinux_2_24_aarch64:2021-09-19-a5ef179",  # cibuildwheel v2.2.0a1
        "manylinux_2_24_i686:2021-09-19-a5ef179",  # cibuildwheel v2.2.0a1
        "manylinux_2_24_ppc64le:2021-09-19-a5ef179",  # cibuildwheel v2.2.0a1
        "manylinux_2_24_s390x:2021-09-19-a5ef179",  # cibuildwheel v2.2.0a1
        "musllinux_1_1_i686:2021-09-19-a5ef179",  # cibuildwheel v2.2.0a1
        "musllinux_1_1_ppc64le:2021-09-19-a5ef179",  # cibuildwheel v2.2.0a1
        "musllinux_1_1_s390x:2021-09-19-a5ef179",  # cibuildwheel v2.2.0a1
        "musllinux_1_1_s390x:2022-10-12-4e18a23",  # cibuildwheel v2.11.1
        "musllinux_1_1_ppc64le:2024-06-03-e195670",  # cibuildwheel v2.19.0
        "musllinux_1_1_s390x:2024-06-03-e195670",  # cibuildwheel v2.19.0
    }
    tag_re = re.compile(r"^(?P<year>\d+)[-.](?P<month>\d+)[-.](?P<day>\d+)[-.]")
    images_to_delete_candidates = defaultdict(set)
    # keep the last tag before dropping python versions (likely already part of cibuildwheel tags)
    all_tags_to_keep = {
        "2021-02-06-3d322a5",  # last tag before python 2.7 drop
        "2021-05-01-28d233a",  # last tag before python 3.5 drop
        "2025-05-03-cdd80a2",  # last tag before python 3.6/3.7 drop
        "2025.05.03-1",  # last tag before python 3.6/3.7 drop
    }
    for tags in cibuildwheel_tags.values():
        all_tags_to_keep.update(tags)
    images = [
        *sorted(cibuildwheel_tags.keys()),
        "manylinux2014",
        "manylinux_2_28",
        "manylinux_2_31",
        "manylinux_2_34",
        "manylinux_2_35",
        "manylinux_2_39",
        "musllinux_1_2",
    ]
    for image in images:
        print(f"checking pypa/{image}")
        tags_dict = {}
        page = 1
        while True:
            response = requests_session().get(
                f"https://quay.io/api/v1/repository/pypa/{image}/tag/?page={page}&limit=100&onlyActiveTags=true"
            )
            response.raise_for_status()
            repo_info = response.json()
            if len(repo_info["tags"]) == 0:
                break
            tags_dict.update({item["name"]: item for item in repo_info["tags"]})
            page += 1
        item = tags_dict.pop("latest")  # all repositories are guaranteed to have a "latest" tag
        manifest_to_keep = {item["manifest_digest"]}
        for tag in sorted(all_tags_to_keep):
            item = tags_dict.pop(tag, None)
            if item is None:
                image_tag = f"{image}:{tag}"
                if image_tag not in known_missing and tag in cibuildwheel_tags.get(image, set()):
                    print(f"::warning::image {image_tag} is missing")
                continue
            manifest_to_keep.add(item["manifest_digest"])

        for tag, item in tags_dict.items():
            if item["manifest_digest"] in manifest_to_keep:
                all_tags_to_keep.add(tag)
                continue
            match = tag_re.match(tag)
            if not match:
                print(f"::warning::image {image}:{tag} is invalid")
                continue
            tag_date = datetime.date(int(match["year"]), int(match["month"]), int(match["day"]))
            if tag_date < expiration_date:
                images_to_delete_candidates[image].add(tag)
    # try to keep things consistent between images
    result = []
    for image, tags in images_to_delete_candidates.items():
        tags_ = tags - all_tags_to_keep
        result.extend(f"{image}:{tag}" for tag in tags_)
    return sorted(result)


def delete_images(image_list: list[str], *, dry_run: bool = True) -> None:
    dry_run_str = " (dry-run)" if dry_run else ""
    for image in image_list:
        image_url = f"quay.io/pypa/{image}"
        print(f"deleting {image_url}{dry_run_str}")
        if dry_run:
            continue
        subprocess.run(
            ["skopeo", "delete", f"docker://{image_url}"],
            check=True,
            stdin=subprocess.DEVNULL,
        )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", dest="dry_run", action="store_true", help="dry run")
    args = parser.parse_args()
    expiration_date = datetime.datetime.now(datetime.UTC).date()
    if (expiration_date.month, expiration_date.day) == (2, 29):
        # This avoids constructing an invalid date when the target year is not a leap year.
        # Note: this means images may have a slightly different retention period when the
        # script is run on a leap day compared to other days.
        expiration_date = expiration_date.replace(day=28)
    expiration_date = expiration_date.replace(year=expiration_date.year - 5)
    print(f"expiration date: {expiration_date.isoformat()}")
    cibuildwheel_tags = get_cibuildwheel_tags()
    to_delete = get_images_to_delete(expiration_date, cibuildwheel_tags)
    delete_images(to_delete, dry_run=args.dry_run)


if __name__ == "__main__":
    main()

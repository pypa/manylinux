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
            if "@sha256:" in value:
                # pinned by sha256 e.g.
                # quay.io/pypa/manylinux2014_x86_64@sha256:0d25b049964b2549b83384036abdff06789a8c0b1e9ff003ec80f0d531f79e50  # 2026.07.19-1
                image, sha_tag = value[13:].split("@")
                _, tag = sha_tag.rsplit(" ", maxsplit=1)
            else:
                # pinned by tag e.g.
                # quay.io/pypa/manylinux2014_x86_64:2026.07.19-1
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
            tags = [version for version in git_tags.stdout.splitlines() if version]
            # remove duplicates, prefer patch version over minor version tag
            tags.sort(key=len, reverse=True)
            unique_versions = set()
            versions = []
            for tag in tags:
                version_ = Version(tag)
                if version_ < Version("1.11.1"):
                    # skip older cibuildwheel versions; only protect images from 1.10.0 and later
                    continue
                if Version("2.0a0") <= version_ < Version("v2.1.1"):
                    continue
                if version_.is_prerelease:
                    continue
                if version_ not in unique_versions:
                    unique_versions.add(version_)
                    versions.append(tag)
            versions.sort(key=Version)
            for version in versions:
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
        "musllinux_1_1_s390x:2022-10-12-4e18a23",  # cibuildwheel v2.11.1
        "musllinux_1_1_ppc64le:2024-06-03-e195670",  # cibuildwheel v2.19.0
        "musllinux_1_1_s390x:2024-06-03-e195670",  # cibuildwheel v2.19.0
    }
    tag_re = re.compile(r"^(?P<year>\d+)[-.](?P<month>\d+)[-.](?P<day>\d+)[-.]")
    images_to_delete_candidates = defaultdict(set)
    # keep the last tag before dropping python versions & cibuildwheel used tags
    all_tags_to_keep = {
        "2021-02-06-3d322a5",  # last tag before python 2.7 drop, cibuildwheel v1.11.1, v1.11.1.post1, v1.12.0
        "2021-05-01-28d233a",  # last tag before python 3.5 drop, cibuildwheel v1.11.1, v1.11.1.post1, v1.12.0
        "2021-05-05-b64d921",  # cibuildwheel v1.11.1, v1.11.1.post1, v1.12.0
        "2021-08-01-f71d505",  # cibuildwheel v2.1.1
        "2021-08-03-e7edb37",  # cibuildwheel v2.1.1
        "2021-09-05-5fd34b8",  # cibuildwheel v2.1.2
        "2021-09-06-7b0bd5d",  # cibuildwheel v2.1.2
        "2021-09-12-b124c44",  # cibuildwheel v2.1.2
        "2021-10-02-5ba76a5",  # cibuildwheel v2.1.3
        "2021-10-06-94da8f1",  # cibuildwheel v2.1.3
        "2021-10-10-790306f",  # cibuildwheel v2.2.0, v2.2.1, v2.2.2
        "2021-10-10-fee0ae1",  # cibuildwheel v2.2.0, v2.2.1, v2.2.2
        "2021-11-20-c4c639c",  # cibuildwheel v2.3.0
        "2021-11-20-f410d11",  # cibuildwheel v2.3.0
        "2021-12-11-951973d",  # cibuildwheel v2.3.1
        "2021-12-12-e5100b5",  # cibuildwheel v2.3.1
        "2022-03-31-361e6b6",  # cibuildwheel v2.4.0
        "2022-03-31-9afae1d",  # cibuildwheel v2.4.0
        "2022-04-03-9524524",  # cibuildwheel v2.5.0
        "2022-04-03-da6ecb3",  # cibuildwheel v2.5.0
        "2022-05-22-74adb27",  # cibuildwheel v2.6.0
        "2022-05-22-fbe07ea",  # cibuildwheel v2.6.0
        "2022-06-05-61145a4",  # cibuildwheel v2.6.1
        "2022-06-05-89b8e6d",  # cibuildwheel v2.6.1
        "2022-06-12-a846b05",  # cibuildwheel v2.7.0
        "2022-06-13-c365205",  # cibuildwheel v2.7.0
        "2022-06-26-9a2ca4b",  # cibuildwheel v2.8.0
        "2022-06-26-ddecca8",  # cibuildwheel v2.8.0
        "2022-07-17-51324db",  # cibuildwheel v2.8.1
        "2022-07-17-f8ddacc",  # cibuildwheel v2.8.1
        "2022-08-05-4535177",  # cibuildwheel v2.9.0, v2.10.0, v2.10.1, v2.10.2, v2.11.0, v2.11.1, v2.11.2, v2.11.3, v2.11.4, v2.12.0, v2.12.1, v2.12.2, v2.12.3, v2.13.0, v2.13.1, v2.14.0, v2.14.1, v2.15.0, v2.16.0, v2.16.1, v2.16.2, v2.16.3, v2.16.4, v2.16.5, v2.17.0, v2.18.0, v2.18.1, v2.19.0, v2.19.1, v2.19.2, v2.20.0, v2.21.0, v2.21.1, v2.21.2, v2.21.3, v2.22.0, v2.23.0, v2.23.1, v2.23.2, v2.23.3, v2.23.4
        "2022-08-08-7292f33",  # cibuildwheel v2.9.0
        "2022-08-09-51a01be",  # cibuildwheel v2.9.0
        "2022-09-07-2e53e4b",  # cibuildwheel v2.10.0, v2.10.1
        "2022-09-12-1a61614",  # cibuildwheel v2.10.0, v2.10.1
        "2022-09-18-2b8b451",  # cibuildwheel v2.10.2
        "2022-09-18-e2e56b7",  # cibuildwheel v2.10.2
        "2022-10-09-941e8b2",  # cibuildwheel v2.11.0
        "2022-10-09-d8a0859",  # cibuildwheel v2.11.0
        "2022-10-11-c03643c",  # cibuildwheel v2.11.1
        "2022-10-12-00e3958",  # cibuildwheel v2.11.1
        "2022-10-12-4e18a23",  # cibuildwheel v2.11.1
        "2022-10-12-b8b6ebc",  # cibuildwheel v2.11.1
        "2022-10-15-7701e25",  # cibuildwheel v2.11.2
        "2022-10-25-fbea779",  # cibuildwheel v2.11.2
        "2022-11-27-4b40699",  # cibuildwheel v2.11.3
        "2022-11-27-b2d7fda",  # cibuildwheel v2.11.3
        "2022-12-11-145d107",  # cibuildwheel v2.11.4
        "2022-12-11-f594764",  # cibuildwheel v2.11.4
        "2022-12-26-0d38463",  # cibuildwheel v2.12.0, v2.12.1, v2.12.2, v2.12.3, v2.13.0, v2.13.1, v2.14.0, v2.14.1, v2.15.0, v2.16.0, v2.16.1, v2.16.2, v2.16.3, v2.16.4, v2.16.5, v2.17.0, v2.18.0, v2.18.1, v2.19.0, v2.19.1, v2.19.2, v2.20.0, v2.21.0, v2.21.1, v2.21.2, v2.21.3, v2.22.0, v2.23.0, v2.23.1, v2.23.2, v2.23.3, v2.23.4
        "2023-01-03-129be5e",  # cibuildwheel v2.12.0
        "2023-01-14-0c345ba",  # cibuildwheel v2.12.0
        "2023-01-14-103cb93",  # cibuildwheel v2.12.0
        "2023-02-26-4ed41b6",  # cibuildwheel v2.12.1
        "2023-03-05-271004f",  # cibuildwheel v2.12.1
        "2023-04-16-157f52a",  # cibuildwheel v2.12.2, v2.12.3
        "2023-04-16-36ed6a7",  # cibuildwheel v2.12.2, v2.12.3
        "2023-05-01-496eb35",  # cibuildwheel v2.13.0
        "2023-05-24-3bf828e",  # cibuildwheel v2.13.0
        "2023-06-07-3623bb5",  # cibuildwheel v2.13.1
        "2023-06-08-775c518",  # cibuildwheel v2.13.1
        "2023-06-25-d2e0575",  # cibuildwheel v2.14.0, v2.14.1
        "2023-07-06-73b0312",  # cibuildwheel v2.14.0
        "2023-07-14-55e4124",  # cibuildwheel v2.14.1
        "2023-08-06-0a0ac62",  # cibuildwheel v2.15.0
        "2023-08-07-e3f636d",  # cibuildwheel v2.15.0
        "2023-09-12-f07b683",  # cibuildwheel v2.16.0, v2.16.1
        "2023-09-17-ae90a16",  # cibuildwheel v2.16.0
        "2023-09-24-36b93e4",  # cibuildwheel v2.16.1
        "2023-10-01-4095a57",  # cibuildwheel v2.16.2
        "2023-10-03-72cdc42",  # cibuildwheel v2.16.2
        "2023-12-10-cee9633",  # cibuildwheel v2.16.3, v2.16.4
        "2024-01-08-eb135ed",  # cibuildwheel v2.16.3
        "2024-01-23-12ffabc",  # cibuildwheel v2.16.4, v2.16.5
        "2024-01-28-7b6687a",  # cibuildwheel v2.16.5
        "2024-03-10-4935fcc",  # cibuildwheel v2.17.0
        "2024-03-10-b85029d",  # cibuildwheel v2.17.0
        "2024-04-29-76807b8",  # cibuildwheel v2.18.0, v2.18.1, v2.19.0, v2.19.1, v2.19.2, v2.20.0, v2.21.0, v2.21.1, v2.21.2, v2.21.3, v2.22.0, v2.23.0, v2.23.1, v2.23.2, v2.23.3, v2.23.4
        "2024-05-10-7415d48",  # cibuildwheel v2.18.0
        "2024-05-13-0983f6f",  # cibuildwheel v2.18, v2.18.1
        "2024-06-03-e195670",  # cibuildwheel v2.19.0
        "2024-06-06-99f15a7",  # cibuildwheel v2.19.0
        "2024.06.12-1",  # cibuildwheel v2.19.1
        "2024.07.02-0",  # cibuildwheel v2.19.2
        "2024.08.03-1",  # cibuildwheel v2.20.0
        "2024.09.09-0",  # cibuildwheel v2.21.0, v2.21.1
        "2024.09.16-1",  # cibuildwheel v2.21.1
        "2024.10.01-1",  # cibuildwheel v2.21.2
        "2024.10.07-1",  # cibuildwheel v2.21.3
        "2024.10.26-1",  # cibuildwheel v2.22.0, v2.23.0, v2.23.1, v2.23.2, v2.23.3, v2.23.4
        "2024.11.16-1",  # cibuildwheel v2.22.0
        "2025.02.28-1",  # cibuildwheel v2.23.0
        "2025.03.09-1",  # cibuildwheel v2.23.1
        "2025.03.23-1",  # cibuildwheel v2.23.2
        "2025.04.19-1",  # cibuildwheel v2.23.3, v2.23.4
        "2025.05.03-1",  # last tag before python 3.6/3.7 drop
        "2025-05-03-cdd80a2",  # last tag before python 3.6/3.7 drop
        "2025.06.08-1",  # cibuildwheel v3.0.0
        "2025.06.28-1",  # cibuildwheel v3.0.1
        "2025.07.23-1",  # cibuildwheel v3.1.0, v3.1.1
        "2025.07.27-1",  # cibuildwheel v3.1.2, v3.1.3
        "2025.08.15-1",  # cibuildwheel v3.1.4
        "2025.09.19-1",  # cibuildwheel v3.2.0
        "2025.10.10-1",  # cibuildwheel v3.2.1
        "2025.11.09-2",  # cibuildwheel v3.3.0
        "2026.01.04-1",  # cibuildwheel v3.3.1
        "2026.03.01-1",  # cibuildwheel v3.4.0
        "2026.03.20-1",  # cibuildwheel v3.4.1
        "2026.05.02-2",  # last tag before python 3.8/3.13t drop
        "2026.06.04-1",  # cibuildwheel v4.0.0, v4.1.0
        "2026.07.19-1",  # cibuildwheel v4.1.1
    }
    cibuildwheel_known_tags = {tag for tags in cibuildwheel_tags.values() for tag in tags}
    missing_tags = sorted(cibuildwheel_known_tags - all_tags_to_keep)
    if missing_tags:
        msg = f"missing known tags: {', '.join(missing_tags)}"
        raise ValueError(msg)
    images = [
        "manylinux1_i686",  # remove after 2029-04-29
        "manylinux1_x86_64",  # remove after 2029-04-29
        "manylinux2010_i686",  # remove after 2027-08-05
        "manylinux2010_x86_64",  # remove after 2027-08-05
        "manylinux2014_aarch64",
        "manylinux2014_i686",
        "manylinux2014_ppc64le",
        "manylinux2014_s390x",
        "manylinux2014_x86_64",
        "manylinux2014",
        "manylinux_2_24_aarch64",  # remove after 2027-12-20
        "manylinux_2_24_i686",  # remove after 2027-12-20
        "manylinux_2_24_ppc64le",  # remove after 2027-12-20
        "manylinux_2_24_s390x",  # remove after 2027-12-20
        "manylinux_2_24_x86_64",  # remove after 2027-12-20
        "manylinux_2_28_aarch64",
        "manylinux_2_28_i686",
        "manylinux_2_28_ppc64le",
        "manylinux_2_28_s390x",
        "manylinux_2_28_x86_64",
        "manylinux_2_28",
        "manylinux_2_31_armv7l",
        "manylinux_2_31",
        "manylinux_2_34_aarch64",
        "manylinux_2_34_i686",
        "manylinux_2_34_ppc64le",
        "manylinux_2_34_s390x",
        "manylinux_2_34_x86_64",
        "manylinux_2_34",
        "manylinux_2_35_armv7l",
        "manylinux_2_35",
        "manylinux_2_39_aarch64",
        "manylinux_2_39_riscv64",
        "manylinux_2_39",
        "musllinux_1_1_aarch64",  # remove after 2029-10-26
        "musllinux_1_1_i686",  # remove after 2029-10-26
        "musllinux_1_1_ppc64le",  # remove after 2029-10-26
        "musllinux_1_1_s390x",  # remove after 2029-10-26
        "musllinux_1_1_x86_64",  # remove after 2029-10-26
        "musllinux_1_2_aarch64",
        "musllinux_1_2_armv7l",
        "musllinux_1_2_i686",
        "musllinux_1_2_ppc64le",
        "musllinux_1_2_riscv64",
        "musllinux_1_2_s390x",
        "musllinux_1_2_x86_64",
        "musllinux_1_2",
    ]
    missing_images = sorted(set(cibuildwheel_tags.keys()) - set(images))
    if missing_images:
        for image in sorted(cibuildwheel_tags.keys()):
            print(f'        "{image}",')
        msg = f"Missing images: {', '.join(missing_images)}"
        raise RuntimeError(msg)
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
        try:
            subprocess.run(
                ["skopeo", "delete", f"docker://{image_url}"],
                check=True,
                stdin=subprocess.DEVNULL,
            )
        except subprocess.CalledProcessError:
            print(f"failed to delete {image_url}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", dest="dry_run", action="store_true", help="dry run")
    parser.add_argument(
        "--force", dest="force", action="store_true", help="don't ask for confirmation"
    )
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
    if not to_delete:
        print("nothing to delete")
        return
    if not args.force:
        delete_images(to_delete, dry_run=True)
    if not args.dry_run:
        if not args.force:
            confirm = input("Continue with deletion? (Y/N) ")
            if confirm.lower() != "y":
                print("skipping deletion")
                return
        delete_images(to_delete, dry_run=False)


if __name__ == "__main__":
    main()

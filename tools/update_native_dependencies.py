import argparse
import hashlib
import re
import subprocess

from pathlib import Path

import requests

from lastversion import latest
from lastversion.Version import Version


PROJECT_ROOT = Path(__file__).parent.parent.resolve(strict=True)
DOCKERFILE = PROJECT_ROOT / "docker" / "Dockerfile"


def _sha256(url):
    response = requests.get(
        url,
        allow_redirects=True,
        headers={"Accept": "application/octet-stream"},
        stream=True)
    response.raise_for_status()
    m = hashlib.sha256()
    for chunk in response.iter_content(chunk_size=65536):
        m.update(chunk)
    return m.hexdigest()


def _update_cpython(dry_run):
    lines = DOCKERFILE.read_text().splitlines()
    re_ = re.compile(r"^RUN.*/build-cpython.sh (?P<version>.*)$")
    for i in range(len(lines)):
        match = re_.match(lines[i])
        if match is None:
            continue
        current_version = Version(match["version"])
        latest_version = latest("python/cpython", major=f'{current_version.major}.{current_version.minor}', pre_ok=current_version.is_prerelease)
        if latest_version > current_version:
            root = f"Python-{latest_version}"
            url = f"https://www.python.org/ftp/python/{latest_version.major}.{latest_version.minor}.{latest_version.micro}"
            _sha256(f"{url}/{root}.tgz")
            lines[i] = lines[i].replace(match["version"], str(latest_version))
            message = f"Bump CPython {current_version} → {latest_version}"
            print(message)
            if not dry_run:
                DOCKERFILE.write_text("\n".join(lines) + "\n")
                subprocess.check_call(["git", "commit", "-am", message])


def _update_with_root(tool, dry_run):
    repo = {
        "autoconf": "autotools-mirror/autoconf",
        "automake": "autotools-mirror/automake",
        "libtool": "autotools-mirror/libtool",
        "git": "git/git",
        "openssl": "openssl/openssl",
    }
    major = {
        "openssl": "3.0",
    }
    only = {
        "autoconf": "~v?[0-9]+\.[0-9]+(\.[0-9]+)?$",
    }
    lines = DOCKERFILE.read_text().splitlines()
    re_ = re.compile(f"^RUN export {tool.upper()}_ROOT={tool}-(?P<version>\\S+) && \\\\$")
    for i in range(len(lines)):
        match = re_.match(lines[i])
        if match is None:
            continue
        current_version = Version(match["version"], char_fix_required=tool=="openssl")
        latest_version = latest(repo[tool], major=major.get(tool, None), only=only.get(tool, None))
        if latest_version > current_version:
            root = f"{tool}-{latest_version}"
            url = re.match(f"^    export {tool.upper()}_DOWNLOAD_URL=(?P<url>\\S+) && \\\\$", lines[i + 2])["url"]
            url = url.replace(f"${{{tool.upper()}_ROOT}}", root)
            sha256 = _sha256(f"{url}/{root}.tar.gz")
            lines[i + 0] = f"RUN export {tool.upper()}_ROOT={root} && \\"
            lines[i + 1] = f"    export {tool.upper()}_HASH={sha256} && \\"
            message = f"Bump {tool} {current_version} → {latest_version}"
            print(message)
            if not dry_run:
                DOCKERFILE.write_text("\n".join(lines) + "\n")
                subprocess.check_call(["git", "commit", "-am", message])
        break


def _update_sqlite(dry_run):
    lines = DOCKERFILE.read_text().splitlines()
    re_ = re.compile(f"^RUN export SQLITE_AUTOCONF_ROOT=sqlite-autoconf-(?P<version>\\S+) && \\\\$")
    for i in range(len(lines)):
        match = re_.match(lines[i])
        if match is None:
            continue
        version_int = int(match["version"])
        major = version_int // 1000000
        version_int -= major * 1000000
        minor = version_int // 10000
        version_int -= minor * 10000
        patch = version_int // 100
        current_version = Version(f"{major}.{minor}.{patch}")
        latest_dict = latest("sqlite/sqlite", output_format="dict")
        latest_version = latest_dict["version"]
        if latest_version > current_version:
            version_int = latest_version.major * 1000000 + latest_version.minor * 10000 + latest_version.micro * 100
            root = f"sqlite-autoconf-{version_int}"
            url = f"https://www.sqlite.org/{latest_dict['tag_date'].year}"
            sha256 = _sha256(f"{url}/{root}.tar.gz")
            lines[i + 0] = f"RUN export SQLITE_AUTOCONF_ROOT={root} && \\"
            lines[i + 1] = f"    export SQLITE_AUTOCONF_HASH={sha256} && \\"
            lines[i + 2] = f"    export SQLITE_AUTOCONF_DOWNLOAD_URL={url} && \\"
            message = f"Bump sqlite {current_version} → {latest_version}"
            print(message)
            if not dry_run:
                DOCKERFILE.write_text("\n".join(lines) + "\n")
                subprocess.check_call(["git", "commit", "-am", message])
        break


def _update_with_gh(tool, dry_run):
    repo = {
        "libxcrypt": "besser82/libxcrypt",
    }
    lines = DOCKERFILE.read_text().splitlines()
    re_ = re.compile(f"^RUN export {tool.upper()}_VERSION=(?P<version>\\S+) && \\\\$")
    for i in range(len(lines)):
        match = re_.match(lines[i])
        if match is None:
            continue
        current_version = Version(match["version"])
        latest_tag = latest(repo[tool], output_format="tag")
        latest_version = Version(latest_tag)
        if latest_version > current_version:
            url = re.match(f"^    export {tool.upper()}_DOWNLOAD_URL=(?P<url>\\S+) && \\\\$", lines[i + 2])["url"]
            sha256 = _sha256(f"{url}/{latest_tag}.tar.gz")
            lines[i + 0] = f"RUN export {tool.upper()}_VERSION={latest_version} && \\"
            lines[i + 1] = f"    export {tool.upper()}_HASH={sha256} && \\"
            message = f"Bump {tool} {current_version} → {latest_version}"
            print(message)
            if not dry_run:
                DOCKERFILE.write_text("\n".join(lines) + "\n")
                subprocess.check_call(["git", "commit", "-am", message])
        break


def _update_tcltk(dry_run):
    lines = DOCKERFILE.read_text().splitlines()
    re_ = re.compile("^RUN export TCL_ROOT=tcl(?P<version>\\S+) && \\\\$")
    for i in range(len(lines)):
        match = re_.match(lines[i])
        if match is None:
            continue
        current_version = Version(match["version"])
        latest_version = latest("tcltk/tcl", only="core-8-6-")
        if latest_version > current_version:
            root = f"tcl{latest_version}"
            url = re.match("^    export TCL_DOWNLOAD_URL=(?P<url>\\S+) && \\\\$", lines[i + 2])["url"]
            sha256 = _sha256(f"{url}/{root}-src.tar.gz")
            lines[i + 0] = f"RUN export TCL_ROOT={root} && \\"
            lines[i + 1] = f"    export TCL_HASH={sha256} && \\"
            root = f"tk{latest_version}"
            sha256 = _sha256(f"{url}/{root}-src.tar.gz")
            lines[i + 3] = f"    export TK_ROOT={root} && \\"
            lines[i + 4] = f"    export TK_HASH={sha256} && \\"
            message = f"Bump Tcl/Tk {current_version} → {latest_version}"
            print(message)
            if not dry_run:
                DOCKERFILE.write_text("\n".join(lines) + "\n")
                subprocess.check_call(["git", "commit", "-am", message])
        break


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", dest="dry_run", action="store_true", help="dry run")
    args = parser.parse_args()
    _update_cpython(args.dry_run)
    _update_sqlite(args.dry_run)
    _update_tcltk(args.dry_run)
    for tool in ["autoconf", "automake", "libtool", "git", "openssl"]:
        _update_with_root(tool, args.dry_run)
    for tool in ["libxcrypt"]:
        _update_with_gh(tool, args.dry_run)


if __name__ == "__main__":
    main()

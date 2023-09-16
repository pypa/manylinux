from __future__ import annotations

import argparse
import os
import json
import subprocess
import sys
from functools import cache
from pathlib import Path


HERE = Path(__file__).parent.resolve(strict=True)
PYTHON_TAGS = json.loads(HERE.joinpath("python_versions.json").read_text())
INSTALL_DIR = Path("/opt/python")
ARCH = os.environ["AUDITWHEEL_ARCH"]
POLICY = os.environ["AUDITWHEEL_POLICY"]
NO_CHECK = os.environ.get("MANYLINUX_INTERPRETERS_NO_CHECK", "0") == "1"


def sort_key(tag):
    python_tag, _ = tag.split("-")
    if python_tag.startswith(("cp", "pp")):
        return python_tag[:2], int(python_tag[2]), int(python_tag[3:])
    raise LookupError(tag)


@cache
def get_all_tags(no_check: bool = False):
    all_tags_ = set(p.name for p in INSTALL_DIR.iterdir() if p.is_dir())
    if POLICY.startswith("manylinux"):
        all_tags_ |= set(tag for tag in PYTHON_TAGS if ARCH in PYTHON_TAGS[tag])
    if no_check:
        all_tags_ |= set(PYTHON_TAGS.keys())
    all_tags = list(all_tags_)
    all_tags.sort(key=lambda tag: sort_key(tag))
    return all_tags


def add_parser_list(subparsers):
    description = "list available or installed interpreters"
    parser = subparsers.add_parser("list", description=description, help=description)
    parser.set_defaults(func=_list)
    parser.add_argument("-v", "--verbose", default=False, action="store_true", help="display additional information (--format=text only, ignored for --format=json)")
    parser.add_argument("-i", "--installed", default=False, action="store_true", help="only list installed interpreters")
    parser.add_argument("--format", choices=["text", "json"], default="text", help="text is not meant to be machine readable (i.e. the format is not stable)")


def get_info_from_path(path: Path):
    python = path / "bin" / "python"
    script = """
import json
import sys
pre_map = {"alpha": "a", "beta": "b", "candidate": "rc"}
pv = sys.version_info
pv_pre = pre_map.get(pv[3], "")
if pv_pre:
    pv_pre += str(pv[4])
iv = sys.implementation.version
iv_pre = pre_map.get(iv[3], "")
if iv_pre:
    iv_pre += str(iv[4])
info = {
    "pv": ".".join(str(p) for p in pv[:3]) + pv_pre,
    "i": sys.implementation.name,
    "iv": ".".join(str(p) for p in iv[:3]) + iv_pre,
}
print(json.dumps(info))
    """
    output = subprocess.run(
        [str(python), "-c", script],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
    ).stdout
    return json.loads(output)


def get_info_from_tag(tag):
    python_tag, _ = tag.split("-")
    if python_tag.startswith("pp"):
        return {
            "pv": f"{python_tag[2]}.{python_tag[3:]}",
            "i": "pypy",
            "iv": PYTHON_TAGS[tag][ARCH]["version"]
        }
    raise LookupError(tag)


def _list(args):
    tags = get_all_tags()
    if args.installed:
        tags = [tag for tag in tags if INSTALL_DIR.joinpath(tag).exists()]

    tag_infos = []
    for tag in tags:
        install_path = INSTALL_DIR.joinpath(tag)
        installed = install_path.exists()
        if installed:
            info = get_info_from_path(install_path)
        else:
            info = get_info_from_tag(tag)
        tag_info = {
            "identifier": tag,
            "installed": installed,
            "python_version": info["pv"],
            "implementation": info["i"],
            "implementation_version": info["iv"],
            "install_path": str(install_path),
        }
        tag_infos.append(tag_info)

    if args.format == "json":
        json.dump(tag_infos, sys.stdout, indent=2)
        return

    assert args.format == 'text'
    for tag in tag_infos:
        print(f"{tag['identifier']}{':' if args.verbose else ''}")
        if args.verbose:
            print(f"  installed:            {'yes' if tag['installed'] else 'no'}")
            print(f"  python version:       {tag['python_version']}")
            print(f"  implemention:         {tag['implementation']}")
            print(f"  implemention version: {tag['implementation_version']}")
            print(f"  install_path:         {tag['install_path']}")


def add_parser_ensure(subparsers):
    description = "make sure a list of interpreters are installed"
    parser = subparsers.add_parser("ensure", description=description, help=description)
    parser.set_defaults(func=ensure)
    parser.add_argument("tags", choices=get_all_tags(no_check=NO_CHECK), metavar="TAG", nargs='+', help="tag with format '<python tag>-<abi tag>' e.g. 'pp310-pypy310_pp73'")


def ensure_one(tag):
    install_path = INSTALL_DIR.joinpath(tag)
    if install_path.exists():
        print(f"'{tag}' already installed at '{install_path}'")
        return
    if tag not in get_all_tags() or ARCH not in PYTHON_TAGS[tag]:
        print(f"skipping '{tag}' for '{ARCH}' architecture")
        return
    print(f"installing '{tag}' at '{install_path}'")
    install_script = HERE / "download-and-install-interpreter.sh"
    tag_info = PYTHON_TAGS[tag][ARCH]
    download_url = tag_info["download_url"]
    sha256 = tag_info["sha256"]
    subprocess.run([str(install_script), tag, download_url, sha256], check=True)
    if not install_path.exists():
        print("installation failed", file=sys.stderr)
        exit(1)


def ensure(args):
    for tag in args.tags:
        ensure_one(tag)


def add_parser_ensure_all(subparsers):
    description = "make sure all interpreters are installed"
    parser = subparsers.add_parser("ensure-all", description=description, help=description)
    parser.set_defaults(func=ensure_all)


def ensure_all(args):
    for tag in get_all_tags():
        ensure_one(tag)


def main():
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(required=True)
    add_parser_ensure(subparsers)
    add_parser_ensure_all(subparsers)
    add_parser_list(subparsers)
    args = parser.parse_args()
    if not hasattr(args, "func"):
        parser.print_help()
        return
    args.func(args)


if __name__ == "__main__":
    main()

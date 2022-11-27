import os
import re
from pathlib import Path

import nox


@nox.session(python=["3.6", "3.7", "3.8", "3.9", "3.10", "3.11"])
def update_python_dependencies(session):
    session.install("pip-tools")
    env = os.environ.copy()
    # CUSTOM_COMPILE_COMMAND is a pip-compile option that tells users how to
    # regenerate the constraints files
    env["CUSTOM_COMPILE_COMMAND"] = f"nox -s {session.name}"
    session.run(
        "pip-compile",
        "--generate-hashes",
        "requirements.in",
        "--allow-unsafe",
        "--upgrade",
        "--output-file",
        f"docker/build_scripts/requirements{session.python}.txt",
        env=env,
    )


@nox.session(python="3.10")
def update_python_tools(session):
    session.install("pip-tools")
    env = os.environ.copy()
    # CUSTOM_COMPILE_COMMAND is a pip-compile option that tells users how to
    # regenerate the constraints files
    env["CUSTOM_COMPILE_COMMAND"] = f"nox -s {session.name}"
    session.run(
        "pip-compile",
        "--generate-hashes",
        "requirements-base-tools.in",
        "--upgrade",
        "--output-file",
        "docker/build_scripts/requirements-base-tools.txt",
        env=env,
    )
    tools = Path("requirements-tools.in").read_text().split("\n")
    for tool in tools:
        if tool.strip() == "":
            continue
        tmp_file = Path(session.create_tmp()) / f"{tool}.in"
        tmp_file.write_text(f"{tool}\n")
        session.run(
            "pip-compile",
            "--generate-hashes",
            str(tmp_file),
            "--upgrade",
            "--output-file",
            f"docker/build_scripts/requirements-tools/{tool}",
            env=env,
        )


@nox.session(python="3.10", reuse_venv=True)
def update_native_dependencies(session):
    session.install("lastversion!=1.6.0,!=2.0.0", "packaging", "requests")
    session.run("python", "update_native_dependencies.py", *session.posargs)

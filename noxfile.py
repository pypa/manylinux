import os
from pathlib import Path

import nox

nox.needs_version = ">=2024.4.15"
nox.options.default_venv_backend = "uv|virtualenv"


@nox.session
def update_python_dependencies(session):
    "Update the base and per-python dependencies lockfiles"
    if getattr(session.virtualenv, "venv_backend", "") != "uv":
        session.install("uv>=0.1.23")

    env = os.environ.copy()
    # CUSTOM_COMPILE_COMMAND is a pip-compile option that tells users how to
    # regenerate the constraints files
    env["UV_CUSTOM_COMPILE_COMMAND"] = f"nox -s {session.name}"

    for python_minor in range(7, 14):
        python_version = f"3.{python_minor}"
        session.run(
            "uv", "pip", "compile",
            f"--python-version={python_version}",
            "--generate-hashes",
            "--no-strip-markers",
            "requirements.in",
            "--upgrade",
            "--output-file",
            f"docker/build_scripts/requirements{python_version}.txt",
            env=env,
        )

    # tools
    python_version = "3.12"
    session.run(
        "uv", "pip", "compile",
        f"--python-version={python_version}",
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
            "uv", "pip", "compile",
            f"--python-version={python_version}",
            "--generate-hashes",
            str(tmp_file),
            "--upgrade",
            "--output-file",
            f"docker/build_scripts/requirements-tools/{tool}",
            env=env,
        )


@nox.session(python="3.12", reuse_venv=True)
def update_native_dependencies(session):
    "Update the native dependencies"
    script = "tools/update_native_dependencies.py"
    deps = nox.project.load_toml(script)["dependencies"]
    session.install(*deps)
    session.run("python", script, *session.posargs)


@nox.session(python="3.12", reuse_venv=True)
def update_interpreters_download(session):
    "Update all the Python interpreters"
    script = "tools/update_interpreters_download.py"
    deps = nox.project.load_toml(script)["dependencies"]
    session.install(*deps)
    session.run("python", script, *session.posargs)

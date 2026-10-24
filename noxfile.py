import os
from pathlib import Path

import nox

nox.needs_version = ">=2024.4.15"
nox.options.default_venv_backend = "uv|virtualenv"
nox.options.sessions = ["lint"]


@nox.session
def update_python_dependencies(session):
    """Update the base and per-python dependencies lock files"""
    if getattr(session.virtualenv, "venv_backend", "") != "uv":
        session.install("uv>=0.1.23")

    env = os.environ.copy()
    # CUSTOM_COMPILE_COMMAND is a pip-compile option that tells users how to
    # regenerate the constraints files
    env["UV_CUSTOM_COMPILE_COMMAND"] = f"nox -s {session.name}"

    def pip_compile(python_version_, input_, output_):
        session.run(
            "uv",
            "pip",
            "compile",
            f"--python-version={python_version_}",
            "--generate-hashes",
            "--no-strip-markers",
            input_,
            "--upgrade",
            "--output-file",
            output_,
            env=env,
        )

    for python_minor in range(9, 16):
        python_version = f"3.{python_minor}"
        packages = ["build", "packaging"]
        requirements = Path(session.create_tmp()) / "requirements.in"
        requirements.write_text("\n".join(packages) + "\n")
        output = f"docker/build_scripts/requirements{python_version}.txt"
        pip_compile(python_version, requirements, output)
        requirements_pip = Path(session.create_tmp()) / "requirements-pip.in"
        requirements_pip.write_text("pip\n")
        output = f"docker/build_scripts/requirements-pip{python_version}.txt"
        pip_compile(python_version, requirements_pip, output)

    # tools
    python_version = "3.14"
    requirements_certifi = Path(session.create_tmp()) / "requirements-certifi.in"
    requirements_certifi.write_text("certifi\n")
    output = "docker/build_scripts/requirements-certifi.txt"
    pip_compile(python_version, requirements_certifi, output)
    requirements_pipx = Path(session.create_tmp()) / "requirements-pipx.in"
    requirements_pipx.write_text("pipx\n")
    pip_compile(python_version, requirements_pipx, "docker/build_scripts/requirements-pipx.txt")
    tools = ["abi3audit", "auditwheel", "cmake", "patchelf", "swig", "uv", "wheel"]
    for tool in tools:
        tmp_file = Path(session.create_tmp()) / f"{tool}.in"
        tmp_file.write_text(f"{tool}\n")
        pip_compile(python_version, tmp_file, f"docker/build_scripts/requirements-tools/{tool}")


@nox.session(python="3.14", reuse_venv=True)
def update_native_dependencies(session):
    """Update the native dependencies"""
    script = "tools/update_native_dependencies.py"
    deps = nox.project.load_toml(script)["dependencies"]
    session.install(*deps)
    session.run("python", script, *session.posargs)


@nox.session(python="3.14", reuse_venv=True)
def update_interpreters_download(session):
    """Update all the Python interpreters"""
    script = "tools/update_interpreters_download.py"
    deps = nox.project.load_toml(script)["dependencies"]
    session.install(*deps)
    session.run("python", script, *session.posargs)


@nox.session(python="3.14", reuse_venv=True)
def update_static_clang(session):
    """Update known static clang versions"""
    script = "tools/update_static_clang.py"
    deps = nox.project.load_toml(script)["dependencies"]
    session.install(*deps)
    session.run("python", script, *session.posargs)


@nox.session(python="3.14", reuse_venv=True)
def lint(session: nox.Session) -> None:
    """Run linters on the codebase."""
    session.install("prek")
    session.run("prek", "run", "--all-files")

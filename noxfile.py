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

    packages = ["build", "packaging"]
    tools = ["abi3audit", "auditwheel", "cmake", "patchelf", "swig", "uv"]

    env = os.environ.copy()
    # CUSTOM_COMPILE_COMMAND is a pip-compile option that tells users how to
    # regenerate the constraints files
    env["UV_CUSTOM_COMPILE_COMMAND"] = f"nox -s {session.name}"

    def pip_compile(python_version_, input_, output_):
        output_ = f"docker/build_scripts/requirements/{output_}"
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

    tmp = Path(session.create_tmp())
    packages_req = tmp / "packages.in"
    packages_req.write_text("\n".join(packages) + "\n")
    pip_req = tmp / "pip.in"
    pip_req.write_text("pip\n")
    for python_minor in range(9, 16):
        python_version = f"3.{python_minor}"
        pip_compile(python_version, packages_req, f"{python_version}/packages.txt")
        pip_compile(python_version, pip_req, f"{python_version}/pip.txt")

    # tools
    python_version = "3.14"
    pipx_req = tmp / "pipx.in"
    pipx_req.write_text("pipx\n")
    pip_compile(python_version, pipx_req, "pipx.txt")
    for tool in tools:
        tool_req = tmp / f"{tool}.in"
        tool_req.write_text(f"{tool}\n")
        pip_compile(python_version, tool_req, f"tools/{tool}")

    # vendor certifi
    session.run("uv", "pip", "install", "-U", "--target=docker/vendor", "certifi")


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

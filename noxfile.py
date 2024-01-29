import nox
import locale


@nox.session(python=["2.7", "3.5", "3.6", "3.7", "3.8", "3.9"])
def update_python_dependencies(session):
    session.install("pip-tools")

    session.run(
        "pip-compile",
        "--generate-hashes",
        "requirements.in",
        "--allow-unsafe",
        "--upgrade",
        "--output-file",
        f"docker/build_scripts/requirements{session.python}.txt",
    )


@nox.session(python="3.9")
def update_python_tools(session):
    session.install("pip-tools")
    session.run(
        "pip-compile",
        "--generate-hashes",
        "requirements-tools.in",
        "--upgrade",
        "--output-file",
        f"docker/build_scripts/requirements-tools.txt",
    )


@nox.session(python="3.9", reuse_venv=True)
def update_native_dependencies(session):
    session.install("lastversion>=3.5.0", "packaging", "requests")
    session.run("python", "update_native_dependencies.py", *session.posargs)

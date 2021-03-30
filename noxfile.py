import nox
import locale


@nox.session(python=["3.6", "3.7", "3.8", "3.9", "3.10"])
def compile(session):
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
def tools(session):
    session.install("pip-tools")
    session.run(
        "pip-compile",
        "--generate-hashes",
        "requirements-tools.in",
        "--upgrade",
        "--output-file",
        f"docker/build_scripts/requirements-tools.txt",
    )

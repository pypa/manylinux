import nox


@nox.session(python=["3.5", "3.6", "3.7", "3.8", "3.9"])
def compile(session):
    session.install("pip-tools")

    # Needed by Python 3.5 and 3.6 in nox docker image
    session.env["LC_ALL"] = "C.UTF-8"
    session.env["LANG"] = "C.UTF-8"

    session.run(
        "pip-compile",
        "--generate-hashes",
        "requirements.in",
        "--allow-unsafe",
        "--output-file",
        f"docker/build_scripts/requirements{session.python}.txt",
    )

@nox.session(python="3.7")
def tools(session):
    session.install("pip-tools")
    session.run(
        "pip-compile",
        "--generate-hashes",
        "requirements-tools.in",
        "--allow-unsafe",
        "--output-file",
        f"docker/build_scripts/requirements-tools.txt",
    )

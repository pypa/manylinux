from pathlib import Path

import nox


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
        "requirements-base-tools.in",
        "--upgrade",
        "--output-file",
        "docker/build_scripts/requirements-base-tools.txt",
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
        )

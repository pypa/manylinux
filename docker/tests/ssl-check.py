# cf. https://github.com/pypa/manylinux/issues/53
import os
import subprocess
import sys
import tempfile
from urllib.request import urlopen

GOOD_SSL = "https://google.com"
BAD_SSL = [
    "https://self-signed.badssl.com",
    "https://dv-g3b-emudhra.we-have-a-problem.com/",
    "https://dv-g3b-aaa-emudhra.we-have-a-problem.com/",
    "https://dv-g3b-noct-emudhra.we-have-a-problem.com/",
    "https://dv-g3b-aaa-noct-emudhra.we-have-a-problem.com/",
]

print(f"Testing SSL certificate checking for Python: {sys.version}")

print(f"Connecting to {GOOD_SSL} should work")
urlopen(GOOD_SSL)
print("...it did, yay.")

for BAD_URL in BAD_SSL:
    print(f"Connecting to {BAD_URL} should fail")
    try:
        urlopen(BAD_URL)
        # If we get here then we failed:
        print("...it DIDN'T!!!!!11!!1one!")
        sys.exit(1)
    except OSError:
        print("...it did, yay.")

    env = os.environ.copy()
    env["PIP_GRAALPY_PATCHES_URL"] = "disabled"
    env_str = "(default environment)"
    with tempfile.TemporaryDirectory() as tmpdir:
        for _ in range(2):
            args = [
                sys.executable,
                "-m",
                "pip",
                "download",
                "--retries",
                "2",
                "--no-cache-dir",
                "--index-url",
                BAD_URL,
                "packaging",
            ]
            cmd = " ".join(args)

            print(f"{cmd!r} should fail {env_str}")
            result = subprocess.run(
                args,
                cwd=tmpdir,
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            concat_output = f"{result.stdout}\n{result.stderr}"
            if result.returncode == 0 or "CERTIFICATE_VERIFY_FAILED" not in concat_output:
                msg = f"{cmd!r} did not fail.\n{result.returncode}\n{concat_output}"
                raise AssertionError(msg)
            print("...it did, yay.")
            # remove SSL_CERT_FILE for next run
            env.pop("SSL_CERT_FILE", None)
            env_str = "(no SSL_CERT_FILE)"

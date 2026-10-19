"""Create a short-lived Modal sandbox with a runtime-only AnyCap secret.

Run locally with `uv run --with modal python examples/modal_sandbox.py`.
Create the `anycap` Modal secret with an `ANYCAP_API_KEY` entry beforehand.
"""

import modal


def main() -> None:
    app = modal.App.lookup("xiao-saurlax-computer", create_if_missing=True)
    image = modal.Image.from_registry("ghcr.io/saurlax/xiao-saurlax-computer:latest")
    sandbox = modal.Sandbox.create(
        "sleep",
        "infinity",
        app=app,
        image=image,
        secrets=[modal.Secret.from_name("anycap")],
        cpu=1,
        memory=1024,
        timeout=600,
    )
    try:
        process = sandbox.exec("anycap", "status")
        print(process.stdout.read(), end="")
        process.wait()
        if process.returncode != 0:
            raise SystemExit(process.returncode)
    finally:
        sandbox.terminate()


if __name__ == "__main__":
    main()

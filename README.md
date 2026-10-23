# xiao-saurlax-computer

A compact Linux toolbox for a13n environments, Modal Sandboxes, and Docker.

## Image

```text
ghcr.io/saurlax/xiao-saurlax-computer:latest
```

The image is published for `linux/amd64` and `linux/arm64`. Each build also has
a `sha-<full-commit>` tag. Use the image digest when an environment must stay on
an exact build, since rebuilding a commit can pick up newer base images.

Included:

- Debian 13 Trixie slim with Bash, Zsh, and UTF-8 support.
- Python 3.13 with pip and venv; Node.js 24 with npm and npx.
- AnyCap CLI 0.6.4, installed from checksum-verified upstream binaries.
- Headless `a13n-envd` with EIP/HTTP support and the a13n sandbox launchers.
- Git, SSH client, curl, wget, jq, ripgrep, fd, SQLite, archive tools, basic
  editors, and process/network diagnostics. Run `fd` rather than `fdfind`.

The working directory is `/workspace`. The default command is still Bash;
the entrypoint runs `tini` and the a13n bootstrap before the requested command.
No daemon starts unless requested. The container and daemon retain root; a13n
file operations and commands use the `sandbox` account (UID/GID 1000), which owns
`/workspace`. It omits desktop software, browsers, FFmpeg, compilers, and a Docker
daemon. Add those only if a task needs them.

## Runtime token injection

AnyCap natively reads `ANYCAP_API_KEY`. Supply it at runtime; there is no login
step and no token build argument. Do not run `anycap login --with-token` in the
Dockerfile or bake an authenticated config directory into an image.

For a local shell, read the key without putting its value in shell history:

```bash
read -rs -p 'AnyCap API key: ' ANYCAP_API_KEY; printf '\n'
export ANYCAP_API_KEY
docker run --rm -it --init \
  --env ANYCAP_API_KEY \
  --mount "type=bind,source=$PWD,target=/workspace" \
  ghcr.io/saurlax/xiao-saurlax-computer:latest
```

Inside the container:

```bash
anycap status
anycap --help
```

Alternatively, copy `.env.example` to `.env`, fill in the key, restrict the file
with `chmod 600 .env`, and pass `--env-file .env`. `.env` files are excluded
from Git and from the build context. An optional `ANYCAP_API_ENDPOINT` selects
a different AnyCap endpoint.

`ANYCAP_NO_UPDATE=1` disables automatic update checks so a running environment
uses the image's pinned CLI. Upgrade the version and checksums in the Dockerfile
and rebuild to update AnyCap.

## Modal

Create a Modal secret named `anycap` containing the key `ANYCAP_API_KEY` in the
Modal dashboard. The example passes it to the sandbox at creation time:

```bash
uv run --with modal python examples/modal_sandbox.py
```

This example creates a sandbox, checks AnyCap status, and always terminates the
sandbox afterward. Its maximum lifetime is 10 minutes. It does not persist files.
It requires an already authenticated Modal SDK on the machine running it.

### a13n

Set the Modal environment template's image to
`ghcr.io/saurlax/xiao-saurlax-computer:latest` and leave Desktop disabled.
Recreate an existing environment after changing the image: updating a tag does
not replace a running sandbox or an old filesystem snapshot.

a13n switched Modal execution to Envd/EIP in commit `68a0d437a` (PR #1168).
It explicitly launches `a13n-sandbox-entrypoint a13n-envd`, authenticates through
the generated `/var/lib/a13n-envd/http-token`, and executes sessions as UID/GID
1000. This image implements that headless contract without X11, VNC, or browser
packages. A separate token is generated at first HTTP startup with mode 0600;
the image contains no token, and a container restart preserves its token.

On a13n versions supporting environment variables, set `ANYCAP_API_KEY` in the
Modal template's environment variables. a13n forwards these defaults to shell
commands and subprocesses. Those template values are ordinary saved
configuration; use them only where its storage and access controls are suitable.
The standalone example above uses a Modal Secret instead. Never put a token in
the image name, a build argument, or a committed file.

The image itself provides no persistent storage. a13n manages stop/resume
filesystem snapshots; direct Modal users must configure Volumes or snapshots
separately. Keep credentials out of files so they are not captured in filesystem
snapshots.

## Local build and verification

```bash
docker buildx build --load -t xiao-saurlax-computer:local .
sh scripts/smoke-test.sh xiao-saurlax-computer:local
```

Smoke tests run offline with no real AnyCap token. They check tools, versions,
the MCP entry point, absence of saved credentials and desktop executables,
runtime environment injection, and the same headless launch used by Modal.
An authenticated HTTP EIP session executes AnyCap and writes a workspace file
as UID/GID 1000. Tests also verify rejection of unauthenticated requests,
protected HTTP credentials, clean shutdown, and container restart. They do not
make paid AnyCap API requests.

The envd binary is copied from the official multi-architecture `dev-slim` image
at a fixed manifest digest. Launcher sources and their Apache-2.0 license are
vendored under `runtime/`; see [runtime/README.md](runtime/README.md) for provenance.
Trixie matches the official envd runtime's libc rather than copying a newer
binary into Bookworm. To update envd, review the upstream protocol compatibility,
refresh the pinned digest and launchers, and rerun the EIP smoke tests.

## Publishing

GitHub Actions tests an amd64 image and publishes both architectures to GHCR on
pushes to `main`, version tags, and manual runs.
Pull requests only build and test. Publishing uses GitHub's built-in
`GITHUB_TOKEN`; no personal token or AnyCap key is needed in repository secrets.

GHCR packages are initially private. Set the package visibility to public after
the first publication so Modal can pull the image without registry credentials.

## References

- [AnyCap installation](https://docs.anycap.ai/getting-started/install/)
- [AnyCap environment variables](https://docs.anycap.ai/reference/environment-variables/)
- [AnyCap authentication](https://docs.anycap.ai/getting-started/authentication/)
- [Modal Sandbox creation](https://modal.com/docs/guide/sandbox)

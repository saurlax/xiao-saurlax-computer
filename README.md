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

- Debian 12 Bookworm slim with Bash, Zsh, and UTF-8 support.
- Python 3.13 with pip and venv; Node.js 24 with npm and npx.
- AnyCap CLI 0.6.4, installed from checksum-verified upstream binaries.
- Git, SSH client, curl, wget, jq, ripgrep, fd, SQLite, archive tools, basic
  editors, and process/network diagnostics. Run `fd` rather than `fdfind`.

The working directory is `/workspace`. The default command is Bash; no server
or daemon starts automatically. The image uses root for compatibility with
agent sandboxes. It omits desktop software, browsers, FFmpeg, compilers, and a
Docker daemon. Add those only if a task needs them.

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
`ghcr.io/saurlax/xiao-saurlax-computer:latest`. The image provides the default
guest Python path `/usr/local/bin/python3` expected by the a13n Modal provider.
An idle stop of 600 seconds is a reasonable starting point.

The currently inspected a13n Modal provider exposes image/CPU/memory/timeout
configuration but does **not** forward custom environment variables or Modal
Secrets into `Sandbox.create`. Changing the image alone therefore installs
AnyCap but does not authenticate it. Using runtime secrets through that provider
requires an a13n integration change; the standalone Modal example demonstrates
the supported SDK path. Do not put a token in the template image string or
build it into the image as a workaround.

The image itself provides no persistent storage. a13n manages stop/resume
filesystem snapshots; direct Modal users must configure Volumes or snapshots
separately. Keep credentials out of files so they are not captured in filesystem
snapshots.

## Local build and verification

```bash
docker buildx build --load -t xiao-saurlax-computer:local .
sh scripts/smoke-test.sh xiao-saurlax-computer:local
```

Smoke tests run offline with no real token. They check tools, runtime versions,
the MCP entry point, the absence of saved AnyCap credentials, and runtime
environment injection. They do not make paid AnyCap API requests.

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

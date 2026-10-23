#!/bin/sh
set -eu

image=${1:-xiao-saurlax-computer:local}

# No real token or external API request is needed to check the image.
docker run --rm --network none "$image" /bin/bash -euc '
    test "$PWD" = /workspace
    test "${ANYCAP_NO_UPDATE:-}" = 1
    test -z "${ANYCAP_API_KEY:-}"
    for tool in bash zsh git ssh curl wget jq rg fd less nano vi ps ip ping \
        dig nc unzip zip xz sqlite3 file tree tini setpriv a13n-envd \
        a13n-sandbox-entrypoint a13n-sandbox-init; do
        command -v "$tool" >/dev/null
    done
    python3 -c "import ssl, sqlite3, venv; import sys; assert sys.version_info[:2] == (3, 13)"
    node -e "if (process.versions.node.split(\".\")[0] !== \"24\") process.exit(1)"
    npm --version
    npx --version
    anycap --version
    a13n-envd --version
    anycap mcp --help >/dev/null
    test ! -e /root/.anycap
    test ! -e /workspace/.env
    test ! -e /var/lib/a13n-envd/http-token
    test ! -e /home/sandbox/.anycap
    for tool in Xvfb openbox x11vnc websockify chromium; do
        ! command -v "$tool"
    done
'

# Confirm the image accepts runtime-only injection. This is a dummy value.
docker run --rm --network none --env ANYCAP_API_KEY=smoke-test-placeholder \
    "$image" python3 -c \
    'import os; assert os.environ["ANYCAP_API_KEY"] == "smoke-test-placeholder"'

# Match a13n Modal's explicit headless launch, without publishing any port.
container="xiao-envd-smoke-$$"
cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; }
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
docker run -d --name "$container" --network none \
    --env A13N_ENVD_DEVICE_ID=headless-smoke \
    --env A13N_ENVD_TRANSPORT=http \
    --env A13N_ENVD_HTTP_BIND=127.0.0.1:8888 \
    --env A13N_ENVD_HTTP_PLAINTEXT_SCOPE=loopback \
    "$image" sh -c 'exec a13n-sandbox-entrypoint a13n-envd' >/dev/null
probe="$(dirname "$0")/envd-probe.py"
docker exec -i "$container" python3 - < "$probe"
token_before=$(docker exec "$container" sha256sum /var/lib/a13n-envd/http-token)
docker stop "$container" >/dev/null
test "$(docker inspect --format '{{.State.ExitCode}}' "$container")" = 0
docker start "$container" >/dev/null
docker exec -i "$container" python3 - < "$probe"
test "$token_before" = "$(docker exec "$container" sha256sum /var/lib/a13n-envd/http-token)"
docker exec "$container" test -f /workspace/envd-smoke.txt

printf 'Smoke tests passed for %s\n' "$image"

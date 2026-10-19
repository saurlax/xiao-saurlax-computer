#!/bin/sh
set -eu

image=${1:-xiao-saurlax-computer:local}

# No real token or external API request is needed to check the image.
docker run --rm --network none "$image" /bin/bash -euc '
    test "$PWD" = /workspace
    test "${ANYCAP_NO_UPDATE:-}" = 1
    test -z "${ANYCAP_API_KEY:-}"
    for tool in bash zsh git ssh curl wget jq rg fd less nano vi ps ip ping \
        dig nc unzip zip xz sqlite3 file tree tini; do
        command -v "$tool" >/dev/null
    done
    python3 -c "import ssl, sqlite3, venv; import sys; assert sys.version_info[:2] == (3, 13)"
    node -e "if (process.versions.node.split(\".\")[0] !== \"24\") process.exit(1)"
    npm --version
    npx --version
    anycap --version
    anycap mcp --help >/dev/null
    test ! -e /root/.anycap
    test ! -e /workspace/.env
'

# Confirm the image accepts runtime-only injection. This is a dummy value.
docker run --rm --network none --env ANYCAP_API_KEY=smoke-test-placeholder \
    "$image" python3 -c \
    'import os; assert os.environ["ANYCAP_API_KEY"] == "smoke-test-placeholder"'

printf 'Smoke tests passed for %s\n' "$image"

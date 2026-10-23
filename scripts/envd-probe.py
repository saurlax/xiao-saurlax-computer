"""Offline EIP smoke test, executed inside the running headless container."""

import json
import pathlib
import time
import urllib.error
import urllib.request


endpoint = "http://127.0.0.1:8888/eip/control"
credential = pathlib.Path("/var/lib/a13n-envd/http-token")
deadline = time.monotonic() + 30
while True:
    try:
        urllib.request.urlopen(urllib.request.Request(endpoint, data=b"{}"), timeout=2)
        raise AssertionError("Unauthenticated EIP request was accepted")
    except urllib.error.HTTPError as error:
        assert error.code == 401, error.code
        break
    except urllib.error.URLError:
        if time.monotonic() >= deadline:
            raise
        time.sleep(0.1)

assert credential.stat().st_mode & 0o777 == 0o600
assert not pathlib.Path("/home/sandbox/.anycap").exists()


def call(method, params, session=None):
    body = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
    if session is not None:
        body["eip_session"] = session
    request = urllib.request.Request(
        endpoint,
        data=json.dumps(body).encode(),
        headers={
            "Content-Type": "application/json",
            "Authorization": "Bearer " + credential.read_text().strip(),
        },
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        result = json.load(response)
    assert "error" not in result, (method, result.get("error"))
    return result["result"]


descriptor = call("initialize", {
    "supported_protocol_versions": ["0.3"],
    "expected_device_id": "headless-smoke",
    "client": {"name": "xiao-saurlax-smoke", "version": "1"},
})["descriptor"]
session = call("session.open", {
    "expected_device_id": "headless-smoke",
    "expected_generation": descriptor["generation"],
    "protocol_version": "0.3",
    "working_directory": "/workspace",
    "required_methods": ["shell.exec"],
})["descriptor"]["session_id"]
try:
    result = call("shell.exec", {
        "context": {"operation_id": "smoke-shell", "timeout_ms": 15000},
        "request": {
            "command": {
                "kind": "shell",
                "profile_id": "default",
                "script": "set -eu; test $(id -u):$(id -g) = 1000:1000; "
                          "test $PWD = /workspace; "
                          "test $ANYCAP_API_KEY = smoke-test-placeholder; "
                          "anycap --version; anycap mcp --help >/dev/null; "
                          "printf ready > /workspace/envd-smoke.txt; "
                          "test $(cat /workspace/envd-smoke.txt) = ready; "
                          "test ! -r /var/lib/a13n-envd/http-token",
            },
            # a13n forwards template variables to EIP commands in this field.
            "environment": {"set": {
                "ANYCAP_API_KEY": "smoke-test-placeholder", "ANYCAP_NO_UPDATE": "1",
            }},
        },
    }, session)
    assert result["status"]["exit_code"] == 0, result
finally:
    call("session.close", {}, session)

print("Headless EIP authentication, UID 1000 shell, workspace and AnyCap injection passed")

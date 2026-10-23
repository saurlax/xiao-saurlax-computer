# Headless a13n runtime provenance

`a13n-sandbox-entrypoint` and `a13n-sandbox-init` are unmodified copies from
`converge-ai-labs/agent-foundation` commit
`f459f05975b69b64f3efd20b5e141f72004f0843`, under
`deploy/docker/images/sandbox/{entrypoint.sh,init-skills.sh}`.
`LICENSE.a13n` is the upstream Apache-2.0 license at that commit.

The Dockerfile copies only `/usr/local/bin/a13n-envd` from the official image:

```
ghcr.io/converge-ai-labs/a13n-sandbox:dev-slim@sha256:a8c3ac9c30651e5cba99200bb9289ea9c4ad099c48ffed355fb592c8823119a4
```

The manifest includes Linux amd64 and arm64. No upstream desktop, browser,
daemon state, or credentials are copied. The launchers initialize optional
workspace skills and the runtime HTTP credential before executing the requested
command. No bundled skills are currently included in this image.

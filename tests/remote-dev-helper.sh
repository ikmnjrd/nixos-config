#!/usr/bin/env bash

set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
helper="${root}/hosts/nixos/remote-dev-helper.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

mkdir -p "${tmp}/bin" "${tmp}/home"

cat >"${tmp}/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"is-active"* ]]; then
  echo inactive
  exit 3
fi
exit 0
EOF
cat >"${tmp}/bin/ss" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "${tmp}/bin/systemctl" "${tmp}/bin/ss"

run_helper() {
  HOME="${tmp}/home" \
  XDG_STATE_HOME="${tmp}/state" \
  PATH="${tmp}/bin:${PATH}" \
  REMOTE_DEV_PORT_MIN=43100 \
  REMOTE_DEV_PORT_MAX=43110 \
  bash "${helper}" "$@"
}

source_dir="$(run_helper register test-host example-app feature)"
if run_helper register test-host example-app feature >/dev/null 2>&1; then
  echo "duplicate slot registration unexpectedly succeeded" >&2
  exit 1
fi
cat >"${source_dir}/.remote-dev.json" <<'EOF'
{
  "version": 1,
  "project": "example-app",
  "runner": {
    "type": "compose",
    "files": ["compose.yaml"]
  },
  "ports": {
    "api": {
      "env": "REMOTE_DEV_API_PORT",
      "scheme": "http",
      "health": {"path": "/health"}
    },
    "web": {
      "env": "REMOTE_DEV_WEB_PORT",
      "scheme": "http",
      "health": {"path": "/"}
    }
  },
  "secrets": [".env.local"]
}
EOF

run_helper configure test-host example-app feature >/dev/null
state="${tmp}/state/remote-dev/slots/test-host/example-app/feature.json"
api_port="$(jq -r '.ports.api.port' "${state}")"
web_port="$(jq -r '.ports.web.port' "${state}")"
[[ "${api_port}" != "${web_port}" ]]
[[ "${api_port}" -ge 43100 && "${api_port}" -le 43110 ]]
[[ "${web_port}" -ge 43100 && "${web_port}" -le 43110 ]]

printf 'TOKEN=test\n' |
  run_helper secret-write test-host example-app feature .env.local
[[ "$(stat -c '%a' "${source_dir}/.env.local")" == "600" ]]

echo "remote-dev helper tests passed"

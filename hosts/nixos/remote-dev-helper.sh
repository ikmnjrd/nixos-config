set -euo pipefail

base="${HOME}/workspace/remote-dev"
state_root="${XDG_STATE_HOME:-${HOME}/.local/state}/remote-dev"
slots_root="${state_root}/slots"
lock_file="${state_root}/state.lock"
port_min="${REMOTE_DEV_PORT_MIN:-43000}"
port_max="${REMOTE_DEV_PORT_MAX:-43999}"

die() {
  printf 'remote-dev-helper: %s\n' "$*" >&2
  exit 1
}

validate_id() {
  [[ "$1" =~ ^[a-z0-9][a-z0-9_.-]*$ ]] ||
    die "invalid identifier: $1"
  [[ "${#1}" -le 48 ]] || die "identifier is longer than 48 characters: $1"
}

validate_relative_path() {
  local value="$1" part
  [[ -n "${value}" && "${value}" != /* ]] || die "invalid relative path: ${value}"
  IFS='/' read -r -a parts <<<"${value}"
  for part in "${parts[@]}"; do
    [[ -n "${part}" && "${part}" != ".." ]] || die "invalid relative path: ${value}"
  done
}

slot_dir() {
  printf '%s/%s/%s/%s\n' "${base}" "$1" "$2" "$3"
}

source_dir() {
  printf '%s/src\n' "$(slot_dir "$1" "$2" "$3")"
}

state_file() {
  printf '%s/%s/%s/%s.json\n' "${slots_root}" "$1" "$2" "$3"
}

env_file() {
  printf '%s/environment\n' "$(slot_dir "$1" "$2" "$3")"
}

unit_name() {
  local checksum
  checksum="$(printf '%s' "$1/$2/$3" | cksum | awk '{print $1}')"
  printf 'remote-dev-%s-%s-%s-%s.service\n' "$1" "$2" "$3" "${checksum}"
}

compose_project() {
  local checksum value
  checksum="$(printf '%s' "$1/$2/$3" | cksum | awk '{print $1}')"
  value="rd-${checksum}-$1-$2-$3"
  printf '%.63s\n' "${value}"
}

require_slot() {
  local file
  file="$(state_file "$1" "$2" "$3")"
  [[ -f "${file}" ]] || die "slot is not registered: $1/$2/$3"
}

validate_config() {
  local config="$1"
  jq -e '
    .version == 1
    and (.project | type == "string" and length > 0)
    and (.runner.type == "compose" or .runner.type == "command")
    and (
      if .runner.type == "compose" then
        ((.runner.files // ["compose.yaml"]) | type == "array" and length > 0)
      else
        (.runner.command | type == "array" and length > 0)
      end
    )
    and ((.ports // {}) | type == "object")
    and all((.ports // {}) | to_entries[];
      (.value.env | type == "string" and test("^[A-Z_][A-Z0-9_]*$"))
    )
    and ((.secrets // []) | type == "array")
  ' "${config}" >/dev/null || die "invalid .remote-dev.json"
}

port_is_reserved() {
  local candidate="$1" file
  while IFS= read -r file; do
    jq -e --argjson port "${candidate}" \
      '.ports // {} | any(.port == $port)' "${file}" >/dev/null && return 0
  done < <(find "${slots_root}" -type f -name '*.json' -print)
  return 1
}

port_is_listening() {
  ss -H -ltn | awk '{print $4}' | grep -Eq "(^|:)$1$"
}

allocate_port() {
  local current_state="${1:-}" candidate
  for ((candidate = port_min; candidate <= port_max; candidate++)); do
    if ! port_is_reserved "${candidate}" &&
      { [[ -z "${current_state}" ]] ||
        ! jq -e --argjson port "${candidate}" \
          '.ports // {} | any(.port == $port)' "${current_state}" >/dev/null; } &&
      ! port_is_listening "${candidate}"; then
      printf '%s\n' "${candidate}"
      return
    fi
  done
  die "no free port in ${port_min}-${port_max}"
}

write_environment() {
  local host="$1" project="$2" slot="$3" state="$4"
  local file tmp name env port
  file="$(env_file "${host}" "${project}" "${slot}")"
  tmp="$(mktemp "${file}.tmp.XXXXXX")"
  {
    printf 'COMPOSE_PROJECT_NAME=%q\n' "$(compose_project "${host}" "${project}" "${slot}")"
    while IFS=$'\t' read -r name env port; do
      [[ -n "${name}" ]] || continue
      printf '%s=%q\n' "${env}" "${port}"
    done < <(jq -r '.ports | to_entries[] | [.key, .value.env, (.value.port | tostring)] | @tsv' "${state}")
  } >"${tmp}"
  chmod 0600 "${tmp}"
  mv -f -- "${tmp}" "${file}"
}

cmd_register() {
  local host="$1" project="$2" slot="$3" source file tmp
  validate_id "${host}"
  validate_id "${project}"
  validate_id "${slot}"
  source="$(source_dir "${host}" "${project}" "${slot}")"
  file="$(state_file "${host}" "${project}" "${slot}")"
  mkdir -p -- "$(dirname -- "${file}")"
  chmod 0700 "${state_root}" "${slots_root}"
  exec 9>"${lock_file}"
  flock 9
  [[ ! -e "${file}" ]] || die "slot is already registered: ${host}/${project}/${slot}"
  mkdir -p -- "${source}"
  tmp="$(mktemp "${file}.tmp.XXXXXX")"
  jq -n \
    --arg host "${host}" \
    --arg project "${project}" \
    --arg slot "${slot}" \
    --arg source "${source}" \
    '{host: $host, project: $project, slot: $slot, source: $source, ports: {}}' \
    >"${tmp}"
  mv -f -- "${tmp}" "${file}"
  printf '%s\n' "${source}"
}

cmd_configure() {
  local host="$1" project="$2" slot="$3"
  local source config file tmp existing_ports name entry port
  validate_id "${host}"
  validate_id "${project}"
  validate_id "${slot}"
  require_slot "${host}" "${project}" "${slot}"
  source="$(source_dir "${host}" "${project}" "${slot}")"
  config="${source}/.remote-dev.json"
  file="$(state_file "${host}" "${project}" "${slot}")"
  mkdir -p -- "$(dirname -- "${file}")"
  [[ -f "${config}" ]] || die "source has no .remote-dev.json"
  validate_config "${config}"

  exec 9>"${lock_file}"
  flock 9
  existing_ports="$(jq -c '.ports // {}' "${file}")"
  tmp="$(mktemp "${file}.tmp.XXXXXX")"
  jq -n \
    --arg host "${host}" \
    --arg project "${project}" \
    --arg slot "${slot}" \
    --arg source "${source}" \
    --slurpfile config "${config}" \
    --argjson ports '{}' \
    '{host: $host, project: $project, slot: $slot, source: $source, config: $config[0], ports: $ports}' \
    >"${tmp}"

  while IFS= read -r name; do
    entry="$(jq -c --arg name "${name}" '.ports[$name]' "${config}")"
    port="$(jq -r --arg name "${name}" '.[$name].port // empty' <<<"${existing_ports}")"
    [[ -n "${port}" ]] || port="$(allocate_port "${tmp}")"
    jq --arg name "${name}" --argjson entry "${entry}" --argjson port "${port}" \
      '.ports[$name] = ($entry + {port: $port})' "${tmp}" >"${tmp}.next"
    mv -f -- "${tmp}.next" "${tmp}"
  done < <(jq -r '.ports // {} | keys[]' "${config}")

  mv -f -- "${tmp}" "${file}"
  write_environment "${host}" "${project}" "${slot}" "${file}"
  cmd_status "${host}" "${project}" "${slot}"
}

load_environment() {
  local file
  file="$(env_file "$1" "$2" "$3")"
  [[ -f "${file}" ]] || die "slot is not configured"
  set -a
  # shellcheck disable=SC1090
  source "${file}"
  set +a
}

compose_args() {
  local file="$1" compose_file
  COMPOSE_ARGS=()
  while IFS= read -r compose_file; do
    validate_relative_path "${compose_file}"
    COMPOSE_ARGS+=(-f "${compose_file}")
  done < <(jq -r '.config.runner.files[]? // empty' "${file}")
  if [[ "${#COMPOSE_ARGS[@]}" -eq 0 ]]; then
    COMPOSE_ARGS=(-f compose.yaml)
  fi
}

stop_unit() {
  local unit="$1"
  systemctl --user stop "${unit}" >/dev/null 2>&1 || true
  systemctl --user reset-failed "${unit}" >/dev/null 2>&1 || true
}

compose_down() {
  local host="$1" project="$2" slot="$3" volumes="${4:-false}"
  local file source
  file="$(state_file "${host}" "${project}" "${slot}")"
  source="$(source_dir "${host}" "${project}" "${slot}")"
  [[ -f "${file}" && -d "${source}" ]] || return
  [[ "$(jq -r '.config.runner.type // empty' "${file}")" == "compose" ]] || return
  load_environment "${host}" "${project}" "${slot}"
  compose_args "${file}"
  if [[ "${volumes}" == "true" ]]; then
    (cd "${source}" && docker compose "${COMPOSE_ARGS[@]}" down --remove-orphans --volumes) || true
  else
    (cd "${source}" && docker compose "${COMPOSE_ARGS[@]}" down --remove-orphans) || true
  fi
}

verify_secrets() {
  local file="$1" source="$2" secret
  while IFS= read -r secret; do
    [[ -n "${secret}" ]] || continue
    validate_relative_path "${secret}"
    [[ -f "${source}/${secret}" ]] || die "secret is not synced: ${secret}"
  done < <(jq -r '.config.secrets[]?' "${file}")
}

start_unit() {
  local host="$1" project="$2" slot="$3"
  local file source unit runner build env_name env_value
  local -a systemd_args command
  file="$(state_file "${host}" "${project}" "${slot}")"
  source="$(source_dir "${host}" "${project}" "${slot}")"
  unit="$(unit_name "${host}" "${project}" "${slot}")"
  runner="$(jq -r '.config.runner.type' "${file}")"
  verify_secrets "${file}" "${source}"
  load_environment "${host}" "${project}" "${slot}"

  systemd_args=(
    --user
    --unit="${unit%.service}"
    --collect
    --property=Restart=no
    --working-directory="${source}"
  )
  systemd_args+=(--setenv="COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME}")
  while IFS= read -r env_name; do
    [[ -n "${env_name}" ]] || continue
    env_value="${!env_name}"
    systemd_args+=(--setenv="${env_name}=${env_value}")
  done < <(jq -r '.ports[].env' "${file}")

  if [[ "${runner}" == "compose" ]]; then
    compose_args "${file}"
    command=(docker compose "${COMPOSE_ARGS[@]}" up)
    build="$(jq -r '.config.runner.build // false' "${file}")"
    [[ "${build}" == "true" ]] && command+=(--build)
  else
    mapfile -t command < <(jq -r '.config.runner.command[]' "${file}")
    command=(nix develop --command "${command[@]}")
  fi

  systemd-run "${systemd_args[@]}" -- "${command[@]}"
}

wait_for_health() {
  local host="$1" project="$2" slot="$3"
  local file unit name scheme path timeout port deadline url
  file="$(state_file "${host}" "${project}" "${slot}")"
  unit="$(unit_name "${host}" "${project}" "${slot}")"

  while IFS= read -r name; do
    scheme="$(jq -r --arg name "${name}" '.ports[$name].scheme // "http"' "${file}")"
    path="$(jq -r --arg name "${name}" '.ports[$name].health.path // "/"' "${file}")"
    timeout="$(jq -r --arg name "${name}" '.ports[$name].health.timeoutSeconds // 120' "${file}")"
    port="$(jq -r --arg name "${name}" '.ports[$name].port' "${file}")"
    deadline=$((SECONDS + timeout))
    until ((SECONDS >= deadline)); do
      if ! systemctl --user is-active --quiet "${unit}"; then
        journalctl --user-unit "${unit}" -n 50 --no-pager >&2 || true
        die "runner exited before ${name} became healthy"
      fi
      if [[ "${scheme}" == "tcp" ]]; then
        if timeout 1 bash -c "</dev/tcp/127.0.0.1/${port}" 2>/dev/null; then
          break
        fi
      else
        url="${scheme}://127.0.0.1:${port}${path}"
        if curl --fail --silent --show-error --max-time 2 "${url}" >/dev/null 2>&1; then
          break
        fi
      fi
      sleep 1
    done
    ((SECONDS < deadline)) || {
      journalctl --user-unit "${unit}" -n 50 --no-pager >&2 || true
      die "health check timed out: ${name}"
    }
  done < <(jq -r '.ports | keys[]' "${file}")
}

cmd_up() {
  local host="$1" project="$2" slot="$3" unit
  require_slot "${host}" "${project}" "${slot}"
  unit="$(unit_name "${host}" "${project}" "${slot}")"
  stop_unit "${unit}"
  start_unit "${host}" "${project}" "${slot}"
  wait_for_health "${host}" "${project}" "${slot}"
  cmd_status "${host}" "${project}" "${slot}"
}

cmd_down() {
  local host="$1" project="$2" slot="$3"
  require_slot "${host}" "${project}" "${slot}"
  stop_unit "$(unit_name "${host}" "${project}" "${slot}")"
  compose_down "${host}" "${project}" "${slot}"
}

cmd_restart() {
  cmd_down "$1" "$2" "$3"
  cmd_up "$1" "$2" "$3"
}

cmd_status() {
  local host="$1" project="$2" slot="$3" file unit state name scheme port path
  require_slot "${host}" "${project}" "${slot}"
  file="$(state_file "${host}" "${project}" "${slot}")"
  unit="$(unit_name "${host}" "${project}" "${slot}")"
  state="$(systemctl --user is-active "${unit}" 2>/dev/null || true)"
  printf 'slot: %s/%s/%s\n' "${host}" "${project}" "${slot}"
  printf 'state: %s\n' "${state:-inactive}"
  while IFS= read -r name; do
    scheme="$(jq -r --arg name "${name}" '.ports[$name].scheme // "http"' "${file}")"
    port="$(jq -r --arg name "${name}" '.ports[$name].port' "${file}")"
    path="$(jq -r --arg name "${name}" '.ports[$name].health.path // "/"' "${file}")"
    if [[ "${scheme}" == "tcp" ]]; then
      printf '%s: tcp://127.0.0.1:%s\n' "${name}" "${port}"
    else
      printf '%s: %s://127.0.0.1:%s%s\n' "${name}" "${scheme}" "${port}" "${path}"
    fi
  done < <(jq -r '.ports | keys[]' "${file}")
}

cmd_logs() {
  local host="$1" project="$2" slot="$3" follow="${4:-}"
  local -a args=(--user-unit "$(unit_name "${host}" "${project}" "${slot}")" -n 200 --no-pager)
  [[ "${follow}" == "--follow" ]] && args+=(--follow)
  journalctl "${args[@]}"
}

cmd_secret_write() {
  local host="$1" project="$2" slot="$3" relative="$4"
  local source target tmp
  require_slot "${host}" "${project}" "${slot}"
  validate_relative_path "${relative}"
  source="$(source_dir "${host}" "${project}" "${slot}")"
  target="${source}/${relative}"
  mkdir -p -- "$(dirname -- "${target}")"
  tmp="$(mktemp "${target}.tmp.XXXXXX")"
  cat >"${tmp}"
  chmod 0600 "${tmp}"
  mv -f -- "${tmp}" "${target}"
}

cmd_destroy() {
  local host="$1" project="$2" slot="$3" purge="${4:-}"
  local dir file
  require_slot "${host}" "${project}" "${slot}"
  stop_unit "$(unit_name "${host}" "${project}" "${slot}")"
  if [[ "${purge}" == "--purge-volumes" ]]; then
    compose_down "${host}" "${project}" "${slot}" true
  else
    compose_down "${host}" "${project}" "${slot}" false
  fi
  dir="$(slot_dir "${host}" "${project}" "${slot}")"
  file="$(state_file "${host}" "${project}" "${slot}")"
  rm -rf -- "${dir}"
  rm -f -- "${file}"
}

usage() {
  cat <<'EOF'
Usage: remote-dev-helper <command> ...

Commands:
  doctor
  register <host> <project> <slot>
  configure <host> <project> <slot>
  secret-write <host> <project> <slot> <relative-path>
  up|down|restart|status <host> <project> <slot>
  logs <host> <project> <slot> [--follow]
  destroy <host> <project> <slot> [--purge-volumes]
EOF
}

mkdir -p -- "${slots_root}"
chmod 0700 "${state_root}" "${slots_root}"

case "${1:-}" in
  doctor)
    docker version >/dev/null
    systemctl --user is-system-running >/dev/null 2>&1 || true
    printf 'remote-dev helper is ready\n'
    ;;
  register) shift; cmd_register "$@" ;;
  configure) shift; cmd_configure "$@" ;;
  secret-write) shift; cmd_secret_write "$@" ;;
  up) shift; cmd_up "$@" ;;
  down) shift; cmd_down "$@" ;;
  restart) shift; cmd_restart "$@" ;;
  status) shift; cmd_status "$@" ;;
  logs) shift; cmd_logs "$@" ;;
  destroy) shift; cmd_destroy "$@" ;;
  help|-h|--help|"") usage ;;
  *) usage >&2; exit 1 ;;
esac

#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_linux-contenedores · v0.7.1                              ║
# ║  Función: verificar postura de seguridad de contenedores      ║
# ║  Emite: xek/finding@v1 · read-only (docker/podman inspect)    ║
# ║                                                                ║
# ║  Variables entorno:                                            ║
# ║    XEK_SUDO            comando de escalada (default: sudo -A)  ║
# ║    XDG_RUNTIME_DIR     base sandbox                            ║
# ║    XEK_CUADERNO        path al cuaderno de artefactos          ║
# ║                                                                ║
# ║  Uso:                                                          ║
# ║    xek-linux-contenedores.sh --mode {dry-run|sandbox|real}    ║
# ║                                                                ║
# ║  Exit codes:                                                  ║
# ║    0 = sin findings · 1 = findings · 2 = config error         ║
# ║    3 = --mode ausente · 4 = invocación ilegal                 ║
# ╚══════════════════════════════════════════════════════════════╝
set -euo pipefail

SLUG="XEK_linux-contenedores"
VERSION="0.7.1"
MODE=""
OVERRIDE_GATE=""
SUDO="${XEK_SUDO:-sudo -A}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)             MODE="${2:-}"; shift 2 ;;
    --mode=*)           MODE="${1#*=}"; shift ;;
    --target)           shift 2 ;;
    --target=*)         shift ;;
    --target-tipo)      shift 2 ;;
    --target-tipo=*)    shift ;;
    --override-gate=*)  OVERRIDE_GATE="${1#*=}"; shift ;;
    --override-gate)    OVERRIDE_GATE="${2:-}"; shift 2 ;;
    -h|--help)          sed -n '2,25p' "$0"; exit 0 ;;
    *)                  echo "ill-call: $1" >&2; exit 4 ;;
  esac
done

[[ -z "$MODE" ]] && { echo "missing --mode" >&2; exit 3; }
case "$MODE" in
  dry-run|sandbox|real) ;;
  *) echo "ill-call: --mode '$MODE' (use dry-run|sandbox|real)" >&2; exit 4 ;;
esac

SANDBOX_BASE="${XDG_RUNTIME_DIR:-/tmp}/xek-sandbox/${SLUG}"
RUN_ID="$(date +%s)-$$"
SANDBOX="$SANDBOX_BASE/$RUN_ID"

preflight() {
  local fail=0 bin
  for bin in bash jq grep find; do
    command -v "$bin" >/dev/null 2>&1 || { echo "PREFLIGHT FAIL: $bin absent" >&2; fail=1; }
  done
  return "$fail"
}

if [[ "$MODE" == "dry-run" ]]; then
  preflight || exit 2
  echo "## ${SLUG} v${VERSION} · plan dry-run"
  echo "checks: ctr-001..007 (runtime, rootless, privileged, mem-limits, docker.sock, digest-pin, daemon.json[real])"
  exit 0
fi

preflight || exit 2

FINDINGS_JSON='[]'
add_finding() {
  local id="$1" sev="$2" msg="$3" rem="${4:-}"
  FINDINGS_JSON="$(jq -c \
    --arg id "$id" --arg sev "$sev" --arg msg "$msg" --arg rem "$rem" \
    '. + [ {id:$id, severity:$sev, message:$msg}
           + (if $rem != "" then {remediation:$rem} else {} end) ]' \
    <<<"$FINDINGS_JSON")"
}
check() {
  local id="$1" sev="$2" msg="$3" rem="$4" cmd="$5"
  bash -c "$cmd" >/dev/null 2>&1 || add_finding "$id" "$sev" "$msg" "$rem"
}

check ctr-001 info "Sin runtime de contenedores (docker/podman)" \
  "Skill aplicable a hosts con docker o podman" \
  "command -v docker >/dev/null || command -v podman >/dev/null"
check ctr-002 high "Daemon no rootless / sin userns-remap" \
  "Ejecutar el runtime en modo rootless o configurar userns-remap" \
  "docker info --format '{{.SecurityOptions}}' 2>/dev/null | grep -qE 'rootless|name=userns' || podman info --format '{{.Host.Security.Rootless}}' 2>/dev/null | grep -qi true"
check ctr-003 critical "Contenedor en ejecución con --privileged" \
  "Eliminar --privileged; conceder solo capabilities concretas" \
  "test \"\$(docker ps -q 2>/dev/null | xargs -r docker inspect --format '{{.HostConfig.Privileged}}' 2>/dev/null | grep -c true)\" -eq 0"
check ctr-004 medium "Contenedor en ejecución sin límite de memoria" \
  "Definir --memory para evitar agotamiento de recursos del host" \
  "test -z \"\$(docker ps -q 2>/dev/null | xargs -r docker inspect --format '{{.Name}} {{.HostConfig.Memory}}' 2>/dev/null | awk '\$2==0')\""
check ctr-005 critical "Socket docker montado dentro de un contenedor" \
  "No montar /var/run/docker.sock en contenedores (escape al host)" \
  "test -z \"\$(docker ps -q 2>/dev/null | xargs -r docker inspect --format '{{range .Mounts}}{{.Source}}{{end}}' 2>/dev/null | grep docker.sock)\""
check ctr-006 medium "Imagen sin pinning por digest (tag :latest o mutable)" \
  "Fijar imágenes por digest (@sha256:...) para reproducibilidad" \
  "test -z \"\$(docker ps --format '{{.Image}}' 2>/dev/null | grep -vE '@sha256:' | grep -E ':latest\$|^[^:@]+\$')\""

# ctr-007 · privilegiado · solo_modo:[real] · informativo (no falla sin escalada).
if [[ "$MODE" == "real" ]]; then
  check ctr-007 info "daemon.json no inspeccionable sin escalada" \
    "Revisar /etc/docker/daemon.json con privilegios (no exponer secretos)" \
    "$SUDO test -f /etc/docker/daemon.json 2>/dev/null && echo present || echo absent-or-no-priv"
fi

NUM="$(jq 'length' <<<"$FINDINGS_JSON")"
EXIT=0
[[ "$NUM" -gt 0 ]] && EXIT=1

emit_doc() {
  jq -n \
    --arg schema "xek/finding@v1" --arg slug "$SLUG" --arg ver "$VERSION" \
    --arg ts "$(date -Iseconds)" --arg modo "$MODE" --arg target "$(hostname)" \
    --argjson ec "$EXIT" --argjson f "$FINDINGS_JSON" \
    '{schema:$schema, slug:$slug, version:$ver, timestamp:$ts, modo:$modo,
      target:$target, exit_code:$ec, findings:$f}'
}

if [[ "$MODE" == "sandbox" ]]; then
  mkdir -p "$SANDBOX"
  emit_doc | tee "$SANDBOX/findings.json"
  echo "findings: $SANDBOX/findings.json" >&2
  exit "$EXIT"
fi

if [[ "$MODE" == "real" ]]; then
  LAST="$(find "$SANDBOX_BASE" -maxdepth 1 -mindepth 1 -type d -not -name "$RUN_ID" -mmin -1440 2>/dev/null | head -1 || true)"
  if [[ -z "$LAST" && -z "$OVERRIDE_GATE" ]]; then
    echo "gate: sandbox previo no encontrado en 24h · usar --override-gate=AUTO_<ts>" >&2
    exit 2
  fi
  OUT_DIR="${XEK_CUADERNO:-$HOME/.claude/cuadernos/xek-cluster}/artefactos/${SLUG}/$(date +%Y-%m-%d)"
  mkdir -p "$OUT_DIR"
  emit_doc | tee "$OUT_DIR/findings.json"
  {
    echo "# Informe ${SLUG} · $(date -Iseconds)"
    echo "findings: $NUM"
    echo '```json'; cat "$OUT_DIR/findings.json"; echo '```'
  } > "$OUT_DIR/informe.md"
  echo "informe: $OUT_DIR/informe.md" >&2
  exit "$EXIT"
fi

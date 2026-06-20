#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_linux-energia · v0.7.1                                    ║
# ║  Función: verificar postura de gestión de energía del host    ║
# ║  Emite: xek/finding@v1 · read-only (/sys + systemctl)         ║
# ║                                                                ║
# ║  Variables entorno:                                            ║
# ║    XEK_SUDO            comando de escalada (default: sudo -A)  ║
# ║    XDG_RUNTIME_DIR     base sandbox                            ║
# ║    XEK_CUADERNO        path al cuaderno de artefactos          ║
# ║                                                                ║
# ║  Uso:                                                          ║
# ║    xek-linux-energia.sh --mode {dry-run|sandbox|real}         ║
# ║                                                                ║
# ║  Exit codes:                                                  ║
# ║    0 = sin findings · 1 = findings · 2 = config error         ║
# ║    3 = --mode ausente · 4 = invocación ilegal                 ║
# ╚══════════════════════════════════════════════════════════════╝
set -euo pipefail

SLUG="XEK_linux-energia"
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
  echo "checks: ene-001..006 (gestor, governor, gestor activo, estados suspensión, sleep.conf, tlp-stat[real])"
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

check ene-001 info "Sin gestor de energía (TLP/power-profiles-daemon)" \
  "Instalar TLP o power-profiles-daemon para gestión de energía" \
  "command -v tlp >/dev/null || command -v powerprofilesctl >/dev/null"
check ene-002 low "Governor de CPU fuera del set esperado" \
  "Configurar un cpufreq governor (powersave/schedutil/performance)" \
  "cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null | grep -qE '^(performance|powersave|schedutil|ondemand|conservative)\$'"
check ene-003 medium "Gestor de energía no activo" \
  "Habilitar y arrancar tlp.service o power-profiles-daemon.service" \
  "systemctl is-active tlp.service 2>/dev/null | grep -qx active || systemctl is-active power-profiles-daemon.service 2>/dev/null | grep -qx active"
check ene-004 low "Sin estados de suspensión soportados" \
  "Verificar soporte de suspensión del kernel (/sys/power/state)" \
  "grep -qE 'mem|standby|freeze' /sys/power/state 2>/dev/null"
check ene-005 low "Sin configuración de sleep de systemd" \
  "Definir /etc/systemd/sleep.conf o un drop-in en sleep.conf.d/" \
  "test -f /etc/systemd/sleep.conf || ls /etc/systemd/sleep.conf.d/*.conf 2>/dev/null | grep -q . || systemd-analyze cat-config systemd/sleep.conf >/dev/null 2>&1"

# ene-006 · privilegiado · solo_modo:[real] · informativo (no falla sin escalada).
if [[ "$MODE" == "real" ]]; then
  check ene-006 high "Estado de TLP no verificable sin escalada" \
    "Revisar 'tlp-stat -s' con privilegios para confirmar TLP_ENABLE" \
    "$SUDO tlp-stat -s 2>/dev/null | grep -qi 'TLP_ENABLE' || echo no-priv-or-absent"
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

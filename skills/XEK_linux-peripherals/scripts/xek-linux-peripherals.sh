#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_linux-peripherals · v0.7.1                                ║
# ║  Función: verificar postura de periféricos (audio/bluetooth)  ║
# ║  Emite: xek/finding@v1 · read-only                            ║
# ║                                                                ║
# ║  Variables entorno:                                            ║
# ║    XEK_SUDO            comando de escalada (default: sudo -A)  ║
# ║    XDG_RUNTIME_DIR     base sandbox                            ║
# ║    XEK_CUADERNO        path al cuaderno de artefactos          ║
# ║                                                                ║
# ║  Uso:                                                          ║
# ║    xek-linux-peripherals.sh --mode {dry-run|sandbox|real}     ║
# ║                                                                ║
# ║  Exit codes:                                                  ║
# ║    0 = sin findings · 1 = findings · 2 = config error         ║
# ║    3 = --mode ausente · 4 = invocación ilegal                 ║
# ╚══════════════════════════════════════════════════════════════╝
set -euo pipefail

SLUG="XEK_linux-peripherals"
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
  echo "checks: peripherals-001..008 (audio, grupos, pairings, bluetoothctl, pipewire, input, usb, firmware[real])"
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

check peripherals-001 info "Sin stack de audio detectable (pipewire/pulse/alsa)" \
  "Instalar y arrancar un servidor de audio (PipeWire recomendado)" \
  "pw-cli info 0 >/dev/null 2>&1 || pactl info >/dev/null 2>&1 || aplay -l >/dev/null 2>&1"
check peripherals-002 low "Usuario no está en grupos audio/bluetooth" \
  "Añadir el usuario a los grupos audio/bluetooth si requiere acceso directo" \
  "groups 2>/dev/null | grep -qE '\b(audio|bluetooth)\b'"
check peripherals-003 low "Emparejamientos bluetooth obsoletos (>90 días)" \
  "Revisar y eliminar emparejamientos bluetooth sin uso en /var/lib/bluetooth" \
  "test \"\$(find /var/lib/bluetooth -name info -mtime +90 2>/dev/null | wc -l)\" -eq 0"
check peripherals-004 info "bluetoothctl ausente (gestión bluetooth limitada)" \
  "Instalar bluez/bluetoothctl si el host usa bluetooth" \
  "command -v bluetoothctl >/dev/null 2>&1"
check peripherals-005 info "Propiedades de PipeWire no legibles" \
  "Verificar PipeWire en ejecución (pw-cli) para rate/quantum" \
  "pw-cli enum-params 0 Props 2>/dev/null | grep -qE 'rate|quantum'"
check peripherals-006 info "Sin dispositivos de entrada enumerados por el kernel" \
  "Verificar /proc/bus/input/devices (subsistema input)" \
  "test -s /proc/bus/input/devices"
check peripherals-007 info "Sin dispositivos USB enumerados vía sysfs" \
  "Verificar /sys/bus/usb/devices (enumeración USB)" \
  "test \"\$(ls -d /sys/bus/usb/devices/*/ 2>/dev/null | wc -l)\" -gt 0"

# peripherals-008 · privilegiado · solo_modo:[real] · informativo (no falla sin escalada).
if [[ "$MODE" == "real" ]]; then
  check peripherals-008 medium "Firmware solicitado por el kernel no verificable sin escalada" \
    "Revisar 'dmesg | grep firmware' con privilegios (failed/missing)" \
    "$SUDO dmesg 2>/dev/null | grep -i 'firmware' | grep -iqv 'failed\|missing' || echo no-priv-or-clean"
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

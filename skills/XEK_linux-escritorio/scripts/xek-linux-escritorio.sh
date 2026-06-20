#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_linux-escritorio · v0.7.1                                 ║
# ║  Función: verificar postura del entorno de escritorio (host)  ║
# ║  Emite: xek/finding@v1 · read-only (XDG + D-Bus de usuario)   ║
# ║                                                                ║
# ║  Variables entorno:                                            ║
# ║    XEK_SUDO            comando de escalada (default: sudo -A)  ║
# ║    XDG_RUNTIME_DIR     base sandbox                            ║
# ║    XEK_CUADERNO        path al cuaderno de artefactos          ║
# ║                                                                ║
# ║  Uso:                                                          ║
# ║    xek-linux-escritorio.sh --mode {dry-run|sandbox|real}      ║
# ║                                                                ║
# ║  Exit codes:                                                  ║
# ║    0 = sin findings · 1 = findings · 2 = config error         ║
# ║    3 = --mode ausente · 4 = invocación ilegal                 ║
# ╚══════════════════════════════════════════════════════════════╝
set -euo pipefail

SLUG="XEK_linux-escritorio"
VERSION="0.7.1"
MODE=""
OVERRIDE_GATE=""

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
  echo "checks: esc-001..006 (desktop env, XDG dirs, display server, portal, user-dirs, perms XDG_RUNTIME_DIR)"
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

check esc-001 info "XDG_CURRENT_DESKTOP no definido" \
  "Sesión sin entorno de escritorio declarado (¿headless?)" \
  "test -n \"\${XDG_CURRENT_DESKTOP:-}\""
check esc-002 low "Directorios base XDG ausentes" \
  "Crear XDG_CONFIG_HOME, XDG_DATA_HOME y XDG_RUNTIME_DIR" \
  "test -d \"\${XDG_CONFIG_HOME:-\$HOME/.config}\" && test -d \"\${XDG_DATA_HOME:-\$HOME/.local/share}\" && test -d \"\${XDG_RUNTIME_DIR:-/run/user/\$(id -u)}\""
check esc-003 info "Servidor gráfico no determinable (wayland/x11)" \
  "Revisar el tipo de sesión (loginctl) o WAYLAND_DISPLAY/DISPLAY" \
  "loginctl show-session \"\$(loginctl | awk -v u=\"\$USER\" '\$3==u{print \$1; exit}')\" -p Type 2>/dev/null | grep -qE 'Type=(wayland|x11)' || test -n \"\${WAYLAND_DISPLAY:-}\${DISPLAY:-}\""
check esc-004 low "xdg-desktop-portal no disponible" \
  "Instalar/activar xdg-desktop-portal para sandboxing de apps" \
  "busctl --user list 2>/dev/null | grep -q 'org.freedesktop.portal.Desktop' || systemctl --user is-active xdg-desktop-portal.service 2>/dev/null | grep -qx active"
check esc-005 low "Sin user-dirs.dirs (XDG user dirs)" \
  "Generar ~/.config/user-dirs.dirs (xdg-user-dirs-update)" \
  "test -f \"\${XDG_CONFIG_HOME:-\$HOME/.config}/user-dirs.dirs\""
check esc-006 medium "XDG_RUNTIME_DIR sin permisos 0700 del usuario" \
  "XDG_RUNTIME_DIR debe ser 0700 y propiedad del usuario (aislamiento)" \
  "test \"\$(stat -c '%a %u' \"\${XDG_RUNTIME_DIR:-/run/user/\$(id -u)}\" 2>/dev/null)\" = \"700 \$(id -u)\""

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

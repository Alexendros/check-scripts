#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_linux-backup · v0.7.1                                     ║
# ║  Función: verificar postura de backup del host (3-2-1)         ║
# ║  Emite: xek/finding@v1 · read-only                            ║
# ║                                                                ║
# ║  Variables entorno:                                            ║
# ║    XEK_SUDO            comando de escalada (default: sudo -A)  ║
# ║    XDG_RUNTIME_DIR     base sandbox                            ║
# ║    XEK_CUADERNO        path al cuaderno de artefactos          ║
# ║                                                                ║
# ║  Uso:                                                          ║
# ║    xek-linux-backup.sh --mode {dry-run|sandbox|real}          ║
# ║                                                                ║
# ║  Exit codes:                                                  ║
# ║    0 = sin findings · 1 = findings · 2 = config error         ║
# ║    3 = --mode ausente · 4 = invocación ilegal                 ║
# ╚══════════════════════════════════════════════════════════════╝
set -euo pipefail

SLUG="XEK_linux-backup"
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
  echo "checks: bkp-001..bkp-006 (herramienta, timer/cron, retención, snapshot, restore-test, offsite 3-2-1)"
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

check bkp-001 high "Sin herramienta de backup (restic/borg/duplicity)" \
  "Instalar y configurar una herramienta de backup" \
  "command -v restic >/dev/null || command -v borg >/dev/null || command -v duplicity >/dev/null"
check bkp-002 high "Sin timer/cron programado de backup" \
  "Programar el backup vía systemd timer o cron" \
  "systemctl list-timers --all 2>/dev/null | grep -qiE 'backup|restic|borg' || grep -rqiE 'restic|borg|duplicity|backup' /etc/cron.d /etc/crontab 2>/dev/null"
check bkp-003 medium "Sin política de retención declarada (forget --keep-*)" \
  "Declarar retención (--keep-daily/weekly/monthly) y prune" \
  "grep -rqE 'forget.*--keep-(daily|weekly|monthly)|--prune' /etc/systemd \$HOME/.config/systemd /etc/cron.d 2>/dev/null"
check bkp-004 high "Sin snapshot reciente verificable (restic snapshots)" \
  "Ejecutar un backup y verificar que aparece al menos un snapshot" \
  "restic snapshots --json --latest 1 2>/dev/null | jq -e 'length > 0' >/dev/null"
check bkp-005 medium "Sin evidencia de restore-test periódico" \
  "Programar y registrar pruebas de restauración (restic check / restore)" \
  "find /var/log \$HOME/.local/state -maxdepth 3 \\( -iname '*restore*test*' -o -iname '*restic*check*' \\) 2>/dev/null | grep -q ."
check bkp-006 medium "Sin segunda copia/offsite (principio 3-2-1)" \
  "Configurar un segundo destino o backend remoto (s3/b2/sftp/rest)" \
  "test \"\$(grep -rhoE 'RESTIC_REPOSITORY[0-9]?=[^ ]+|(s3|b2|sftp|rest|azure|gs):[^ ]+' /etc/systemd \$HOME/.config/systemd /etc/environment 2>/dev/null | sort -u | grep -c .)\" -ge 2"

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

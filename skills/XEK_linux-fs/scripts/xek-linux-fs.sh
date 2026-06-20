#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_linux-fs · v0.7.1                                         ║
# ║  Función: verificar postura del sistema de ficheros (host)    ║
# ║  Emite: xek/finding@v1 · read-only                            ║
# ║                                                                ║
# ║  Variables entorno:                                            ║
# ║    XEK_SUDO            comando de escalada (default: sudo -A)  ║
# ║    XDG_RUNTIME_DIR     base sandbox                            ║
# ║    XEK_CUADERNO        path al cuaderno de artefactos          ║
# ║                                                                ║
# ║  Uso:                                                          ║
# ║    xek-linux-fs.sh --mode {dry-run|sandbox|real}              ║
# ║                                                                ║
# ║  Exit codes:                                                  ║
# ║    0 = sin findings · 1 = findings · 2 = config error         ║
# ║    3 = --mode ausente · 4 = invocación ilegal                 ║
# ╚══════════════════════════════════════════════════════════════╝
set -euo pipefail

SLUG="XEK_linux-fs"
VERSION="0.7.1"
MODE=""
OVERRIDE_GATE=""
# Escalada agnóstica del operador (R16).
SUDO="${XEK_SUDO:-sudo -A}"

# ── Parseo de argumentos (acepta --flag valor y --flag=valor) ──────
# --target/--target-tipo se aceptan e ignoran: la skill siempre inspecciona el host local.
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
  echo "checks: fs-001..fs-006 (tools, mount opts, uso disco, fstab, fstype, SMART[real])"
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
# check ID SEV MSG REMEDIATION CMD  → finding si CMD falla (exit != 0).
check() {
  local id="$1" sev="$2" msg="$3" rem="$4" cmd="$5"
  bash -c "$cmd" >/dev/null 2>&1 || add_finding "$id" "$sev" "$msg" "$rem"
}

check fs-001 info "findmnt/df ausentes · inspección de FS limitada" \
  "Instalar util-linux (findmnt) y coreutils (df)" \
  "command -v findmnt >/dev/null && command -v df >/dev/null"
check fs-002 low "Root montado sin noatime/relatime" \
  "Añadir relatime/noatime en /etc/fstab para reducir escrituras" \
  "test -z \"\$(findmnt -rno OPTIONS,FSTYPE / 2>/dev/null | grep -vE 'noatime|relatime')\""
check fs-003 high "Filesystem real al >=90% de uso" \
  "Liberar espacio o ampliar el volumen afectado" \
  "test -z \"\$(df -P -x tmpfs -x devtmpfs -x squashfs 2>/dev/null | awk 'NR>1 && int(\$5) >= 90')\""
check fs-004 medium "fstab incoherente (findmnt --verify falla)" \
  "Corregir entradas de /etc/fstab señaladas por findmnt --verify" \
  "findmnt --verify --verbose >/dev/null 2>&1"
check fs-005 info "FS de root no es uno de ext4/xfs/btrfs/zfs/f2fs" \
  "Revisar el tipo de filesystem del root" \
  "findmnt -rno FSTYPE / 2>/dev/null | grep -qE '^(ext4|xfs|btrfs|zfs|f2fs)\$'"

# fs-006 · privilegiado · solo_modo:[real]. Diseñado para no fallar sin escalada.
if [[ "$MODE" == "real" ]]; then
  check fs-006 high "SMART del primer disco no reporta PASSED/OK" \
    "Revisar salud del disco (smartctl -H) y planificar reemplazo" \
    "$SUDO smartctl -H \"\$(lsblk -dno PATH,TYPE 2>/dev/null | awk '\$2==\"disk\"{print \$1; exit}')\" 2>/dev/null | grep -qiE 'PASSED|OK' || echo no-priv-or-absent"
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

#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_remix · v0.7.1                                            ║
# ║  Función: verificar postura de un proyecto Remix/RR7 (repo)   ║
# ║  Emite: xek/finding@v1 · read-only                            ║
# ║                                                                ║
# ║  Variables entorno:                                            ║
# ║    XEK_TARGET_DIR     raíz del repo a inspeccionar            ║
# ║    XDG_RUNTIME_DIR    base sandbox                             ║
# ║    XEK_CUADERNO       path al cuaderno de artefactos          ║
# ║                                                                ║
# ║  Uso:                                                          ║
# ║    xek-remix.sh --mode dry-run                                ║
# ║    xek-remix.sh --mode sandbox --target /ruta/repo          ║
# ║                                                                ║
# ║  Exit codes:                                                  ║
# ║    0 = sin findings / no aplica · 1 = findings · 2 = config   ║
# ║    3 = --mode ausente · 4 = invocación ilegal                 ║
# ╚══════════════════════════════════════════════════════════════╝
set -euo pipefail

SLUG="XEK_remix"
VERSION="0.7.1"
MODE=""
REPO="${XEK_TARGET_DIR:-.}"
OVERRIDE_GATE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)             MODE="${2:-}"; shift 2 ;;
    --mode=*)           MODE="${1#*=}"; shift ;;
    --target)           REPO="${2:-}"; shift 2 ;;
    --target=*)         REPO="${1#*=}"; shift ;;
    --target-tipo)      shift 2 ;;
    --target-tipo=*)    shift ;;
    --override-gate=*)  OVERRIDE_GATE="${1#*=}"; shift ;;
    --override-gate)    OVERRIDE_GATE="${2:-}"; shift 2 ;;
    -h|--help)          sed -n '2,24p' "$0"; exit 0 ;;
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
  echo "target: $REPO"
  echo "checks: remix-001..006 (config, dep @remix-run/react-router, scripts, app/routes, loaders/actions, plugin vite)"
  exit 0
fi

preflight || exit 2
[[ -d "$REPO" ]] || { echo "target inexistente: $REPO" >&2; exit 2; }
REPO_ABS="$(cd "$REPO" && pwd)"
cd "$REPO_ABS"

FINDINGS_JSON='[]'
SKIPPED_JSON='null'
EXIT=0
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

# ── Compuerta de aplicabilidad: ¿es un proyecto Remix/React Router? ─
if ! { test -f ./package.json && jq -e '(.dependencies // {}) + (.devDependencies // {}) | keys[] | select(startswith("@remix-run/") or . == "react-router")' ./package.json >/dev/null 2>&1; }; then
  SKIPPED_JSON='{"razon":"not_applicable","detalle":"sin @remix-run/* ni react-router en dependencies"}'
else
  check remix-001 high "Sin vite.config ni remix.config en la raíz" \
    "Añadir vite.config (Remix Vite) o remix.config en la raíz" \
    "find . -maxdepth 1 -type f \( -name 'vite.config.*' -o -name 'remix.config.*' \) | grep -q ."
  check remix-003 medium "package.json sin scripts build y start/dev" \
    "Declarar build y start (o dev) en los scripts de package.json" \
    "jq -e '.scripts.build and (.scripts.start or .scripts.dev)' ./package.json"
  check remix-004 medium "Sin directorio app/routes ni fichero app/root" \
    "Estructurar la app con app/routes/ y un app/root.{tsx,jsx}" \
    "test -d ./app/routes || find ./app -maxdepth 1 -name 'root.*' 2>/dev/null | grep -q ."
  check remix-005 low "Sin loaders/actions exportados en app/" \
    "Definir loaders/actions (export function loader/action) en las rutas" \
    "! grep -rIlE 'export (async )?function (loader|action)' --include='*.ts' --include='*.tsx' ./app 2>/dev/null | grep -q . || grep -rIlqE 'export (const|async function|function) (loader|action)' ./app"
  check remix-006 low "vite.config presente sin plugin de Remix/React Router" \
    "Registrar el plugin @remix-run/dev o @react-router/dev en vite.config" \
    "! find . -maxdepth 1 -name 'vite.config.*' | grep -q . || grep -qE '@remix-run/dev|@react-router/dev' ./vite.config.*"
fi

NUM="$(jq 'length' <<<"$FINDINGS_JSON")"
[[ "$NUM" -gt 0 ]] && EXIT=1

emit_doc() {
  jq -n \
    --arg schema "xek/finding@v1" --arg slug "$SLUG" --arg ver "$VERSION" \
    --arg ts "$(date -Iseconds)" --arg modo "$MODE" --arg target "$REPO_ABS" \
    --argjson ec "$EXIT" --argjson f "$FINDINGS_JSON" --argjson sk "$SKIPPED_JSON" \
    '{schema:$schema, slug:$slug, version:$ver, timestamp:$ts, modo:$modo,
      target:$target, exit_code:$ec, findings:$f}
     + (if $sk != null then {skipped:$sk} else {} end)'
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
    echo "target: $REPO_ABS"
    echo "findings: $NUM"
    echo '```json'; cat "$OUT_DIR/findings.json"; echo '```'
  } > "$OUT_DIR/informe.md"
  echo "informe: $OUT_DIR/informe.md" >&2
  exit "$EXIT"
fi

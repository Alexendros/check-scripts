#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_nextjs · v0.7.1                                           ║
# ║  Función: verificar postura de un proyecto Next.js (repo)     ║
# ║  Emite: xek/finding@v1 · read-only                            ║
# ║                                                                ║
# ║  Variables entorno:                                            ║
# ║    XEK_TARGET_DIR     raíz del repo a inspeccionar            ║
# ║    XDG_RUNTIME_DIR    base sandbox                             ║
# ║    XEK_CUADERNO       path al cuaderno de artefactos          ║
# ║                                                                ║
# ║  Uso:                                                          ║
# ║    xek-nextjs.sh --mode dry-run                               ║
# ║    xek-nextjs.sh --mode sandbox --target /ruta/repo          ║
# ║                                                                ║
# ║  Exit codes:                                                  ║
# ║    0 = sin findings / no aplica · 1 = findings · 2 = config   ║
# ║    3 = --mode ausente · 4 = invocación ilegal                 ║
# ╚══════════════════════════════════════════════════════════════╝
set -euo pipefail

SLUG="XEK_nextjs"
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
  echo "checks: nextjs-001..006 (next.config, dep next, scripts, router app/pages, next/image, output:export+middleware)"
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

# ── Compuerta de aplicabilidad: ¿es un proyecto Next.js? ───────────
if ! { test -f ./package.json && jq -e '.dependencies.next // .devDependencies.next' ./package.json >/dev/null 2>&1; }; then
  SKIPPED_JSON='{"razon":"not_applicable","detalle":"next no está en dependencies/devDependencies"}'
else
  check nextjs-001 high "Sin fichero next.config en la raíz" \
    "Añadir next.config.{js,mjs,ts} en la raíz del proyecto" \
    "find . -maxdepth 1 -type f -name 'next.config.*' | grep -q ."
  check nextjs-003 medium "package.json sin scripts build y start" \
    "Declarar los scripts build y start en package.json" \
    "jq -e '.scripts.build and .scripts.start' ./package.json"
  check nextjs-004 medium "Sin directorio de rutas (app/ o pages/)" \
    "Crear el directorio app/ (App Router) o pages/ (Pages Router)" \
    "test -d ./app || test -d ./src/app || test -d ./pages || test -d ./src/pages"
  check nextjs-005 low "Uso de <img> sin next/image en componentes" \
    "Usar el componente next/image para optimización de imágenes" \
    "! grep -rIlE '<img[[:space:]]' --include='*.tsx' --include='*.jsx' ./app ./src/app ./pages ./src/pages 2>/dev/null | grep -q . || grep -rIlq 'next/image' ."
  check nextjs-006 low "output:export con middleware (incompatible en export estático)" \
    "El export estático (output:export) no soporta middleware; revisar" \
    "! grep -qE \"output:[[:space:]]*['\\\"]export['\\\"]\" ./next.config.* 2>/dev/null || ! find . -maxdepth 2 -name 'middleware.*' | grep -q ."
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

#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_a11y-web · v0.7.1                                         ║
# ║  Función: verificar accesibilidad de un HTML renderizado      ║
# ║  Emite: xek/finding@v1 · read-only (sobre artefacto HTML)     ║
# ║                                                                ║
# ║  Variables entorno:                                            ║
# ║    XEK_TARGET_HTML    ruta al HTML renderizado a inspeccionar ║
# ║    XDG_RUNTIME_DIR    base sandbox                             ║
# ║    XEK_CUADERNO       path al cuaderno de artefactos          ║
# ║                                                                ║
# ║  Uso:                                                          ║
# ║    xek-a11y-web.sh --mode dry-run                             ║
# ║    xek-a11y-web.sh --mode sandbox --target /ruta/index.html  ║
# ║                                                                ║
# ║  Exit codes:                                                  ║
# ║    0 = sin findings / no aplica · 1 = findings · 2 = config   ║
# ║    3 = --mode ausente · 4 = invocación ilegal                 ║
# ╚══════════════════════════════════════════════════════════════╝
set -euo pipefail

SLUG="XEK_a11y-web"
VERSION="0.7.1"
MODE=""
TARGET="${XEK_TARGET_HTML:-}"
OVERRIDE_GATE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)             MODE="${2:-}"; shift 2 ;;
    --mode=*)           MODE="${1#*=}"; shift ;;
    --target)           TARGET="${2:-}"; shift 2 ;;
    --target=*)         TARGET="${1#*=}"; shift ;;
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
  for bin in bash jq grep awk; do
    command -v "$bin" >/dev/null 2>&1 || { echo "PREFLIGHT FAIL: $bin absent" >&2; fail=1; }
  done
  return "$fail"
}

if [[ "$MODE" == "dry-run" ]]; then
  preflight || exit 2
  echo "## ${SLUG} v${VERSION} · plan dry-run"
  echo "target: ${TARGET:-<sin --target>}"
  echo "checks: a11y-001..008 (html lang, img alt, h1 único, jerarquía headings, roles, input label, well-formed, nav)"
  exit 0
fi

preflight || exit 2

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

# ── Compuerta de aplicabilidad: ¿hay artefacto HTML? ───────────────
if [[ -z "$TARGET" || ! -f "$TARGET" ]]; then
  SKIPPED_JSON='{"razon":"not_applicable","detalle":"sin artefacto HTML (--target fichero)"}'
else
  export HTML="$TARGET"
  check a11y-001 high "Elemento <html> sin atributo lang" \
    "Declarar el idioma con <html lang=\"...\">" \
    "grep -qiE '<html[^>]+lang=.[a-z]' \"\$HTML\""
  check a11y-002 high "Imagen <img> sin atributo alt" \
    "Añadir texto alternativo (alt) a todas las imágenes" \
    "! grep -oiE '<img[^>]*>' \"\$HTML\" | grep -viqE 'alt='"
  check a11y-003 medium "No hay exactamente un <h1> en la página" \
    "Mantener un único <h1> por página" \
    "test \"\$(grep -oiE '<h1[ >]' \"\$HTML\" | wc -l)\" -eq 1"
  check a11y-004 medium "Saltos en la jerarquía de encabezados (hN)" \
    "No saltar niveles de encabezado (h2 tras h1, etc.)" \
    "grep -oiE '<h[1-6][ >]' \"\$HTML\" | grep -oiE '[1-6]' | awk 'NR>1 && \$0 > prev+1 {bad=1} {prev=\$0} END {exit bad+0}'"
  check a11y-005 low "Atributo role con valor no estándar (ARIA)" \
    "Usar solo roles ARIA válidos" \
    "! grep -oiE 'role=.[a-z]+' \"\$HTML\" | grep -viqE 'role=.(button|navigation|main|banner|contentinfo|complementary|search|dialog|alert|list|listitem|tab|tabpanel|tablist|menu|menuitem|region|form|article|heading|img|link|presentation|none|status|switch|checkbox|radio|tooltip|grid|row|cell|combobox|option|progressbar|slider|textbox|tree|treeitem|toolbar|group|figure|table)'"
  check a11y-006 medium "Campo <input> sin label asociable" \
    "Asociar cada input con un label (id/for, aria-label o aria-labelledby)" \
    "! grep -oiE '<input[^>]*>' \"\$HTML\" | grep -viqE '(id=|aria-label|aria-labelledby|type=.hidden|type=.submit|type=.button)'"
  if command -v xmllint >/dev/null 2>&1; then
    check a11y-007 medium "HTML mal formado (errores graves de parseo)" \
      "Corregir el marcado para que el HTML sea bien formado" \
      "xmllint --html --noout \"\$HTML\" 2>/dev/null; test \$? -le 1"
  fi
  check a11y-008 low "Sin landmark de navegación (<nav> o role=navigation)" \
    "Marcar la navegación con <nav> o role=navigation" \
    "grep -qiE '<nav[ >]|role=.navigation.' \"\$HTML\""
fi

NUM="$(jq 'length' <<<"$FINDINGS_JSON")"
[[ "$NUM" -gt 0 ]] && EXIT=1

emit_doc() {
  jq -n \
    --arg schema "xek/finding@v1" --arg slug "$SLUG" --arg ver "$VERSION" \
    --arg ts "$(date -Iseconds)" --arg modo "$MODE" --arg target "${TARGET:-}" \
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
    echo "target: ${TARGET:-}"
    echo "findings: $NUM"
    echo '```json'; cat "$OUT_DIR/findings.json"; echo '```'
  } > "$OUT_DIR/informe.md"
  echo "informe: $OUT_DIR/informe.md" >&2
  exit "$EXIT"
fi

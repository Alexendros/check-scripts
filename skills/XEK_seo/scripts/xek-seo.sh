#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_seo · v0.7.1                                              ║
# ║  Función: verificar SEO técnico de un HTML renderizado        ║
# ║  Emite: xek/finding@v1 · read-only (HTML + URL opcional)      ║
# ║                                                                ║
# ║  Variables entorno:                                            ║
# ║    XEK_TARGET_HTML    ruta al HTML renderizado                ║
# ║    XEK_BASE_URL       URL base del sitio (robots/sitemap)      ║
# ║    XDG_RUNTIME_DIR    base sandbox                             ║
# ║    XEK_CUADERNO       path al cuaderno de artefactos          ║
# ║                                                                ║
# ║  Uso:                                                          ║
# ║    xek-seo.sh --mode dry-run                                 ║
# ║    xek-seo.sh --mode sandbox --target page.html \             ║
# ║      --base-url https://ejemplo.com                          ║
# ║                                                                ║
# ║  Exit codes:                                                  ║
# ║    0 = sin findings / no aplica · 1 = findings · 2 = config   ║
# ║    3 = --mode ausente · 4 = invocación ilegal                 ║
# ╚══════════════════════════════════════════════════════════════╝
set -euo pipefail

SLUG="XEK_seo"
VERSION="0.7.1"
MODE=""
TARGET="${XEK_TARGET_HTML:-}"
BASE_URL="${XEK_BASE_URL:-}"
OVERRIDE_GATE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)             MODE="${2:-}"; shift 2 ;;
    --mode=*)           MODE="${1#*=}"; shift ;;
    --target)           TARGET="${2:-}"; shift 2 ;;
    --target=*)         TARGET="${1#*=}"; shift ;;
    --base-url)         BASE_URL="${2:-}"; shift 2 ;;
    --base-url=*)       BASE_URL="${1#*=}"; shift ;;
    --target-tipo)      shift 2 ;;
    --target-tipo=*)    shift ;;
    --override-gate=*)  OVERRIDE_GATE="${1#*=}"; shift ;;
    --override-gate)    OVERRIDE_GATE="${2:-}"; shift 2 ;;
    -h|--help)          sed -n '2,26p' "$0"; exit 0 ;;
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
  for bin in bash jq grep sed; do
    command -v "$bin" >/dev/null 2>&1 || { echo "PREFLIGHT FAIL: $bin absent" >&2; fail=1; }
  done
  return "$fail"
}

if [[ "$MODE" == "dry-run" ]]; then
  preflight || exit 2
  echo "## ${SLUG} v${VERSION} · plan dry-run"
  echo "target: ${TARGET:-<sin --target>} · base-url: ${BASE_URL:-<sin --base-url>}"
  echo "checks: seo-001..008 (title, meta description, canonical, robots, sitemap, JSON-LD, OpenGraph, hreflang)"
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
  check seo-001 medium "No hay exactamente un <title> en la página" \
    "Definir un único <title> descriptivo" \
    "test \"\$(grep -oiE '<title>[^<]+</title>' \"\$HTML\" | wc -l)\" -eq 1"
  check seo-002 medium "Sin <meta name=description> con contenido" \
    "Añadir una meta description única y descriptiva" \
    "grep -qiE '<meta[^>]+name=.description.[^>]+content=.[^\"]+' \"\$HTML\""
  check seo-003 medium "Sin <link rel=canonical> absoluto" \
    "Declarar una URL canónica absoluta (https://...)" \
    "grep -qiE '<link[^>]+rel=.canonical.[^>]+href=.https?://' \"\$HTML\""
  check seo-006 low "JSON-LD presente pero no es JSON válido" \
    "Corregir el bloque structured data (application/ld+json)" \
    "! grep -qiE '<script[^>]+type=.application/ld.json.' \"\$HTML\" || { grep -oziE '<script[^>]+type=.application/ld.json.[^>]*>[^<]+' \"\$HTML\" | sed -E 's/<script[^>]*>//' | jq -e . >/dev/null; }"
  check seo-007 low "Sin Open Graph (og:title/og:type/og:url)" \
    "Añadir las meta Open Graph og:title, og:type y og:url" \
    "grep -qiE 'property=.og:title.' \"\$HTML\" && grep -qiE 'property=.og:type.' \"\$HTML\" && grep -qiE 'property=.og:url.' \"\$HTML\""
  check seo-008 low "hreflang declarado sin URL absoluta" \
    "Usar URLs absolutas en los <link rel=alternate hreflang>" \
    "! grep -iE '<link[^>]+rel=.alternate.[^>]+hreflang=' \"\$HTML\" || grep -qiE '<link[^>]+rel=.alternate.[^>]+hreflang=[^>]+href=.https?://' \"\$HTML\""

  # Checks que requieren el sitio en vivo (curl); se omiten sin --base-url.
  if [[ -n "$BASE_URL" ]] && command -v curl >/dev/null 2>&1; then
    export BASE_URL
    check seo-004 low "robots.txt no responde 200" \
      "Publicar un robots.txt accesible (HTTP 200)" \
      "test \"\$(curl -s -o /dev/null -w '%{http_code}' \"\$BASE_URL/robots.txt\")\" = 200"
    if command -v xmllint >/dev/null 2>&1; then
      check seo-005 low "sitemap.xml ausente o mal formado" \
        "Publicar un sitemap.xml válido (urlset/sitemapindex)" \
        "curl -s \"\$BASE_URL/sitemap.xml\" | xmllint --noout - && curl -s \"\$BASE_URL/sitemap.xml\" | grep -qiE '<urlset|<sitemapindex'"
    fi
  fi
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

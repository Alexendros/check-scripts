#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_perf-web · v0.7.1                                         ║
# ║  Función: verificar performance web de un HTML renderizado    ║
# ║  Emite: xek/finding@v1 · read-only (HTML + URL opcional)      ║
# ║                                                                ║
# ║  Variables entorno:                                            ║
# ║    XEK_TARGET_HTML    ruta al HTML renderizado                ║
# ║    XEK_URL            URL en vivo (cabeceras de respuesta)     ║
# ║    XDG_RUNTIME_DIR    base sandbox                             ║
# ║    XEK_CUADERNO       path al cuaderno de artefactos          ║
# ║                                                                ║
# ║  Uso:                                                          ║
# ║    xek-perf-web.sh --mode dry-run                            ║
# ║    xek-perf-web.sh --mode sandbox --target page.html \        ║
# ║      --url https://ejemplo.com                               ║
# ║                                                                ║
# ║  Exit codes:                                                  ║
# ║    0 = sin findings / no aplica · 1 = findings · 2 = config   ║
# ║    3 = --mode ausente · 4 = invocación ilegal                 ║
# ╚══════════════════════════════════════════════════════════════╝
set -euo pipefail

SLUG="XEK_perf-web"
VERSION="0.7.1"
MODE=""
TARGET="${XEK_TARGET_HTML:-}"
URL="${XEK_URL:-}"
OVERRIDE_GATE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)             MODE="${2:-}"; shift 2 ;;
    --mode=*)           MODE="${1#*=}"; shift ;;
    --target)           TARGET="${2:-}"; shift 2 ;;
    --target=*)         TARGET="${1#*=}"; shift ;;
    --url)              URL="${2:-}"; shift 2 ;;
    --url=*)            URL="${1#*=}"; shift ;;
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
  for bin in bash jq grep find; do
    command -v "$bin" >/dev/null 2>&1 || { echo "PREFLIGHT FAIL: $bin absent" >&2; fail=1; }
  done
  return "$fail"
}

if [[ "$MODE" == "dry-run" ]]; then
  preflight || exit 2
  echo "## ${SLUG} v${VERSION} · plan dry-run"
  echo "target: ${TARGET:-<sin --target>} · url: ${URL:-<sin --url>}"
  echo "checks: perf-001..008 (lazy img, width/height, script defer/async, preconnect, preload, cache-control, compresión, peso HTML)"
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
  check perf-001 medium "Imágenes sin loading=lazy (más de una)" \
    "Marcar las imágenes below-the-fold con loading=lazy" \
    "test \"\$(grep -oiE '<img[^>]*>' \"\$HTML\" | grep -viE 'loading=.lazy' | wc -l)\" -le 1"
  check perf-002 medium "Imágenes <img> sin width/height (provocan CLS)" \
    "Declarar width y height en las imágenes para reservar espacio" \
    "! grep -oiE '<img[^>]*>' \"\$HTML\" | grep -viqE '(width=.*height=|height=.*width=)'"
  check perf-003 medium "Scripts <script src> sin defer/async/module" \
    "Cargar los scripts con defer, async o type=module" \
    "! grep -oiE '<script[^>]+src=[^>]*>' \"\$HTML\" | grep -viqE '(defer|async|type=.module)'"
  check perf-004 low "Sin resource hints (preconnect/dns-prefetch)" \
    "Añadir preconnect/dns-prefetch a orígenes de terceros críticos" \
    "grep -qiE '<link[^>]+rel=.(preconnect|dns-prefetch).' \"\$HTML\""
  check perf-005 low "Sin <link rel=preload> de recursos críticos" \
    "Precargar recursos críticos (fuentes, hero) con rel=preload" \
    "grep -qiE '<link[^>]+rel=.preload.' \"\$HTML\""
  check perf-008 medium "Documento HTML supera 256 KB" \
    "Reducir el tamaño del HTML inicial (code splitting, menos inline)" \
    "test \"\$(find \"\$HTML\" -printf '%s')\" -le 256000"

  # Checks que requieren el sitio en vivo (curl); se omiten sin --url.
  if [[ -n "$URL" ]] && command -v curl >/dev/null 2>&1; then
    export URL
    check perf-006 low "Respuesta sin cabecera Cache-Control" \
      "Servir el recurso con una cabecera Cache-Control adecuada" \
      "curl -sI \"\$URL\" | grep -qiE '^cache-control:'"
    check perf-007 low "Respuesta sin compresión (gzip/br/zstd)" \
      "Activar compresión (gzip/brotli/zstd) en el servidor/CDN" \
      "curl -sI -H 'Accept-Encoding: gzip, br' \"\$URL\" | grep -qiE '^content-encoding:.*(gzip|br|zstd)'"
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

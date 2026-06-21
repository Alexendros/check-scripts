#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_cookies · v0.7.1                                          ║
# ║  Función: verificar cookies/consentimiento de una página web  ║
# ║  Emite: xek/finding@v1 · read-only (HTML + cabeceras)         ║
# ║                                                                ║
# ║  Variables entorno:                                            ║
# ║    XEK_TARGET_HTML    ruta al HTML renderizado                ║
# ║    XEK_HEADERS        ruta a las cabeceras HTTP guardadas      ║
# ║    XDG_RUNTIME_DIR    base sandbox                             ║
# ║    XEK_CUADERNO       path al cuaderno de artefactos          ║
# ║                                                                ║
# ║  Uso:                                                          ║
# ║    xek-cookies.sh --mode dry-run                             ║
# ║    xek-cookies.sh --mode sandbox --target page.html \         ║
# ║      --headers resp.headers                                   ║
# ║                                                                ║
# ║  Exit codes:                                                  ║
# ║    0 = sin findings / no aplica · 1 = findings · 2 = config   ║
# ║    3 = --mode ausente · 4 = invocación ilegal                 ║
# ╚══════════════════════════════════════════════════════════════╝
set -euo pipefail

SLUG="XEK_cookies"
VERSION="0.7.1"
MODE=""
TARGET="${XEK_TARGET_HTML:-}"
HEADERS_FILE="${XEK_HEADERS:-}"
OVERRIDE_GATE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)             MODE="${2:-}"; shift 2 ;;
    --mode=*)           MODE="${1#*=}"; shift ;;
    --target)           TARGET="${2:-}"; shift 2 ;;
    --target=*)         TARGET="${1#*=}"; shift ;;
    --headers)          HEADERS_FILE="${2:-}"; shift 2 ;;
    --headers=*)        HEADERS_FILE="${1#*=}"; shift ;;
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
  for bin in bash jq grep awk; do
    command -v "$bin" >/dev/null 2>&1 || { echo "PREFLIGHT FAIL: $bin absent" >&2; fail=1; }
  done
  return "$fail"
}

if [[ "$MODE" == "dry-run" ]]; then
  preflight || exit 2
  echo "## ${SLUG} v${VERSION} · plan dry-run"
  echo "target: ${TARGET:-<sin --target>} · headers: ${HEADERS_FILE:-<sin --headers>}"
  echo "checks: cookies-001..008 (banner, Secure/HttpOnly/SameSite, tracking sin consentimiento, scripts, enlace política, Max-Age)"
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
  check cookies-001 medium "Sin banner/CMP de consentimiento de cookies en el HTML" \
    "Implementar un banner de consentimiento (CMP) conforme a RGPD/ePrivacy" \
    "grep -qiE '(cookie-consent|cookie-banner|cmp|consent|aceptar cookies|gestionar cookies|cookiebot|onetrust)' \"\$HTML\""
  check cookies-006 medium "Scripts de tracking embebidos en el HTML" \
    "Cargar los scripts de tracking solo tras consentimiento" \
    "! grep -oiE 'src=.https?://[^\"[:space:]]+' \"\$HTML\" | grep -qiE '(googletagmanager|google-analytics|connect.facebook|doubleclick|hotjar|clarity.ms)'"
  check cookies-007 low "Sin enlace a política de cookies/privacidad" \
    "Enlazar la política de cookies/privacidad desde la página" \
    "grep -qiE '<a[^>]+href=[^>]*(cookies|privacidad|privacy|politica)' \"\$HTML\""

  if [[ -n "$HEADERS_FILE" && -f "$HEADERS_FILE" ]]; then
    export HEADERS="$HEADERS_FILE"
    check cookies-002 high "Cookie sin atributo Secure" \
      "Marcar todas las cookies con el atributo Secure" \
      "! grep -iE '^set-cookie:' \"\$HEADERS\" | grep -viqE 'Secure'"
    check cookies-003 high "Cookie sin atributo HttpOnly" \
      "Marcar las cookies de sesión con HttpOnly" \
      "! grep -iE '^set-cookie:' \"\$HEADERS\" | grep -viqE 'HttpOnly'"
    check cookies-004 high "Cookie sin atributo SameSite" \
      "Declarar SameSite=(Lax|Strict|None) en todas las cookies" \
      "! grep -iE '^set-cookie:' \"\$HEADERS\" | grep -viqE 'SameSite=(Lax|Strict|None)'"
    check cookies-005 medium "Cookies de tracking presentes en las cabeceras" \
      "No fijar cookies de tracking sin consentimiento previo" \
      "! grep -iE '^set-cookie:' \"\$HEADERS\" | grep -qiE '(_ga|_gid|_fbp|_gcl_au|IDE|_uetsid|mp_[a-z0-9]+_mixpanel)'"
    check cookies-008 medium "Cookie con Max-Age superior a un año" \
      "Limitar la vida de las cookies (Max-Age) a lo estrictamente necesario" \
      "grep -iE '^set-cookie:' \"\$HEADERS\" | grep -oiE 'Max-Age=[0-9]+' | grep -oiE '[0-9]+' | awk '\$0 > 31536000 {bad=1} END {exit bad+0}'"
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

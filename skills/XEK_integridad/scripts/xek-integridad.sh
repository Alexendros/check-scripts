#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_integridad · v0.7.1                                       ║
# ║  Función: integridad de cadena de suministro (repo)           ║
# ║  Emite: xek/finding@v1 · read-only                            ║
# ║                                                                ║
# ║  Variables entorno:                                            ║
# ║    XEK_TARGET_DIR     raíz del repo a inspeccionar            ║
# ║    XDG_RUNTIME_DIR    base sandbox                             ║
# ║    XEK_CUADERNO       path al cuaderno de artefactos          ║
# ║                                                                ║
# ║  Uso:                                                          ║
# ║    xek-integridad.sh --mode dry-run                          ║
# ║    xek-integridad.sh --mode sandbox --target /ruta/repo      ║
# ║                                                                ║
# ║  Exit codes:                                                  ║
# ║    0 = sin findings · 1 = findings · 2 = config error         ║
# ║    3 = --mode ausente · 4 = invocación ilegal                 ║
# ╚══════════════════════════════════════════════════════════════╝
set -euo pipefail

SLUG="XEK_integridad"
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
  echo "checks: integridad-001..006 (SRI, hashes npm/pnpm lock, provenance SLSA, firma, pinning a SHA)"
  exit 0
fi

preflight || exit 2
[[ -d "$REPO" ]] || { echo "target inexistente: $REPO" >&2; exit 2; }
REPO_ABS="$(cd "$REPO" && pwd)"
cd "$REPO_ABS"

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

check integridad-001 high "Script externo de CDN sin atributo integrity (SRI)" \
  "Añadir integrity (SRI) a los <script> con src de CDN en HTML" \
  "! grep -rilE '<script[^>]+src=.https?://' . --include=\"*.html\" | xargs -r grep -LE '<script[^>]+src=.https?://[^>]+integrity=' | grep -q ."
check integridad-002 high "package-lock.json con paquetes resueltos sin hash integrity" \
  "Regenerar el lockfile npm para incluir hashes de integridad" \
  "! test -f ./package-lock.json || jq -e '[.. | objects | select(has(\"resolved\")) | select(has(\"integrity\") | not)] | length == 0' ./package-lock.json"
check integridad-003 high "pnpm-lock.yaml sin hashes de integridad" \
  "Regenerar el lockfile pnpm para incluir hashes (campo integrity)" \
  "! test -f ./pnpm-lock.yaml || grep -qE 'integrity:' ./pnpm-lock.yaml"
check integridad-004 medium "Sin provenance/attestation SLSA en los workflows de CI" \
  "Generar provenance SLSA o attestations en CI (attest-build-provenance)" \
  "grep -rilE 'slsa-framework/slsa-github-generator|actions/attest-build-provenance|attestations:[[:space:]]*write' ./.github/workflows | grep -q ."
check integridad-005 medium "Sin firma de releases (sigstore/cosign/gh attestation) en CI" \
  "Firmar releases/artefactos con sigstore/cosign en CI" \
  "grep -rilE 'sigstore|cosign sign|gh attestation' ./.github/workflows | grep -q ."
check integridad-006 medium "GitHub Actions pinneadas a tag mutable (@vN) en vez de SHA" \
  "Pinnear las actions a un SHA completo en lugar de un tag mutable" \
  "! grep -rhE '^[[:space:]]*uses:[[:space:]]*[^@]+@v[0-9]' ./.github/workflows | grep -q ."

NUM="$(jq 'length' <<<"$FINDINGS_JSON")"
EXIT=0
[[ "$NUM" -gt 0 ]] && EXIT=1

emit_doc() {
  jq -n \
    --arg schema "xek/finding@v1" --arg slug "$SLUG" --arg ver "$VERSION" \
    --arg ts "$(date -Iseconds)" --arg modo "$MODE" --arg target "$REPO_ABS" \
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
    echo "target: $REPO_ABS"
    echo "findings: $NUM"
    echo '```json'; cat "$OUT_DIR/findings.json"; echo '```'
  } > "$OUT_DIR/informe.md"
  echo "informe: $OUT_DIR/informe.md" >&2
  exit "$EXIT"
fi

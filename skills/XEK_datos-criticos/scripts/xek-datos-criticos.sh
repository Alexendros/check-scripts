#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_datos-criticos · v0.7.1                                   ║
# ║  Función: detección de datos críticos versionados (repo)      ║
# ║  Emite: xek/finding@v1 · read-only (git index/grep)           ║
# ║                                                                ║
# ║  Variables entorno:                                            ║
# ║    XEK_TARGET_DIR     raíz del repo a inspeccionar            ║
# ║    XDG_RUNTIME_DIR    base sandbox                             ║
# ║    XEK_CUADERNO       path al cuaderno de artefactos          ║
# ║                                                                ║
# ║  Uso:                                                          ║
# ║    xek-datos-criticos.sh --mode dry-run                      ║
# ║    xek-datos-criticos.sh --mode sandbox --target /ruta/repo  ║
# ║                                                                ║
# ║  Exit codes:                                                  ║
# ║    0 = sin findings · 1 = findings · 2 = config error         ║
# ║    3 = --mode ausente · 4 = invocación ilegal                 ║
# ╚══════════════════════════════════════════════════════════════╝
set -euo pipefail

SLUG="XEK_datos-criticos"
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
  for bin in bash jq git grep find; do
    command -v "$bin" >/dev/null 2>&1 || { echo "PREFLIGHT FAIL: $bin absent" >&2; fail=1; }
  done
  return "$fail"
}

if [[ "$MODE" == "dry-run" ]]; then
  preflight || exit 2
  echo "## ${SLUG} v${VERSION} · plan dry-run"
  echo "target: $REPO"
  echo "checks: datos-001..006 (.env versionado, .gitignore, claves PEM, tokens cloud, credenciales, PII en fixtures)"
  exit 0
fi

preflight || exit 2
[[ -d "$REPO" ]] || { echo "target inexistente: $REPO" >&2; exit 2; }
REPO_ABS="$(cd "$REPO" && pwd)"
cd "$REPO_ABS"
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "not a git repo: $REPO_ABS" >&2
  exit 2
fi

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

check datos-001 high "Fichero .env (no ejemplo) versionado en el índice git" \
  "Eliminar el .env del índice (git rm --cached) y rotar los secretos" \
  "! git ls-files --error-unmatch '*.env' '.env' '.env.*' 2>/dev/null | grep -vE '\.env\.(example|sample|template)\$' | grep -q ."
check datos-002 medium ".gitignore no ignora ficheros .env" \
  "Añadir una regla .env al .gitignore para evitar commits accidentales" \
  "test -f ./.gitignore && grep -qE '(^|/)\.env' ./.gitignore"
check datos-003 high "Clave privada PEM (BEGIN PRIVATE KEY) versionada" \
  "Eliminar la clave del repo, rotarla y guardarla en un secret manager" \
  "! git grep -lE 'BEGIN ([A-Z ]+ )?PRIVATE KEY' -- . 2>/dev/null | grep -q ."
check datos-004 high "Token de proveedor cloud hardcoded (AWS/Google/GitHub)" \
  "Eliminar el token, rotarlo y usar variables de entorno o secret manager" \
  "! git grep -lE '(AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|ghp_[0-9A-Za-z]{36})' -- . 2>/dev/null | grep -q ."
check datos-005 high "Credencial hardcoded en código (password/secret/api_key/token)" \
  "Externalizar la credencial a variables de entorno o secret manager" \
  "! git grep -liE '(password|secret|api_?key|token)[\"[:space:]]*[:=][\"[:space:]]*[A-Za-z0-9/_+-]{12,}' -- '*.js' '*.ts' '*.py' '*.go' '*.rb' 2>/dev/null | grep -q ."
check datos-006 medium "PII (email real) en fixtures/tests (fuera de example/test)" \
  "Sustituir emails reales por dominios example/test en fixtures" \
  "! grep -rhoiE '[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}' . --include=\"*fixture*\" --include=\"*.spec.*\" --include=\"*.test.*\" 2>/dev/null | grep -viE '@(example|test|localhost)' | grep -q ."

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

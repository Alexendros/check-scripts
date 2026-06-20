#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_repo-higiene · v0.7.1                                     ║
# ║  Función: verificar higiene de repositorio (read-only)        ║
# ║  Emite: xek/finding@v1                                         ║
# ║                                                                ║
# ║  Variables entorno:                                            ║
# ║    XEK_TARGET_DIR     raíz del repo a inspeccionar            ║
# ║    XDG_RUNTIME_DIR    base sandbox                             ║
# ║    XEK_CUADERNO       path al cuaderno de artefactos          ║
# ║                                                                ║
# ║  Uso:                                                          ║
# ║    xek-repo-higiene.sh --mode dry-run                         ║
# ║    xek-repo-higiene.sh --mode sandbox --target /ruta/repo     ║
# ║    xek-repo-higiene.sh --mode real    --target /ruta/repo     ║
# ║                                                                ║
# ║  Exit codes:                                                  ║
# ║    0 = sin findings · 1 = findings · 2 = config error         ║
# ║    3 = --mode ausente · 4 = invocación ilegal                 ║
# ╚══════════════════════════════════════════════════════════════╝
set -euo pipefail

SLUG="XEK_repo-higiene"
VERSION="0.7.1"
MODE=""
REPO="${XEK_TARGET_DIR:-.}"
OVERRIDE_GATE=""

# ── Parseo de argumentos (acepta --flag valor y --flag=valor) ──────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)             MODE="${2:-}"; shift 2 ;;
    --mode=*)           MODE="${1#*=}"; shift ;;
    --target)           REPO="${2:-}"; shift 2 ;;
    --target=*)         REPO="${1#*=}"; shift ;;
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

# ── Preflight · binarios requeridos ────────────────────────────────
preflight() {
  local fail=0 bin
  for bin in bash jq git grep find; do
    if ! command -v "$bin" >/dev/null 2>&1; then
      echo "PREFLIGHT FAIL: $bin absent" >&2
      fail=1
    fi
  done
  return "$fail"
}

# ── dry-run · plan sin recorrer el árbol ───────────────────────────
if [[ "$MODE" == "dry-run" ]]; then
  preflight || exit 2
  echo "## ${SLUG} v${VERSION} · plan dry-run"
  echo "target: $REPO"
  echo "checks: repo-001..repo-008 (readme, license, contributing, gitignore,"
  echo "        changelog, ci-workflow, sin .env versionado, sin binarios grandes)"
  exit 0
fi

# ── sandbox + real ─────────────────────────────────────────────────
preflight || exit 2
if [[ ! -d "$REPO" ]]; then
  echo "target inexistente: $REPO" >&2
  exit 2
fi
if ! git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "not a git repo: $REPO" >&2
  exit 2
fi

# Acumulador de findings (solo checks que FALLAN → problema reportable).
FINDINGS_JSON='[]'
add_finding() {
  local id="$1" sev="$2" msg="$3" rem="${4:-}"
  FINDINGS_JSON="$(jq -c \
    --arg id "$id" --arg sev "$sev" --arg msg "$msg" --arg rem "$rem" \
    '. + [ {id:$id, severity:$sev, message:$msg}
           + (if $rem != "" then {remediation:$rem} else {} end) ]' \
    <<<"$FINDINGS_JSON")"
}

# check ID SEV MSG REMEDIATION -- comando...  (comando exit 0 = pass)
check() {
  local id="$1" sev="$2" msg="$3" rem="$4"; shift 4
  if bash -c "$1" >/dev/null 2>&1; then
    :
  else
    add_finding "$id" "$sev" "$msg" "$rem"
  fi
}

check repo-001 high   "README ausente en la raíz" \
  "Añadir un README.md con propósito, instalación y uso" \
  "find '$REPO' -maxdepth 1 -iregex '.*/readme\(\.md\|\.rst\|\.txt\)?' | grep -q ."
check repo-002 high   "LICENSE ausente en la raíz" \
  "Añadir un fichero LICENSE (p.ej. MIT, Apache-2.0)" \
  "find '$REPO' -maxdepth 1 -iregex '.*/licen[sc]e\(\.md\|\.txt\)?' | grep -q ."
check repo-003 medium "CONTRIBUTING ausente en raíz o .github/" \
  "Documentar cómo contribuir en CONTRIBUTING.md" \
  "find '$REPO' '$REPO/.github' -maxdepth 1 -iname 'contributing*' 2>/dev/null | grep -q ."
check repo-004 medium ".gitignore ausente en la raíz" \
  "Añadir un .gitignore acorde al stack" \
  "test -f '$REPO/.gitignore'"
check repo-005 low    "CHANGELOG ausente en la raíz" \
  "Mantener un CHANGELOG (formato Keep a Changelog)" \
  "find '$REPO' -maxdepth 1 -iname 'changelog*' | grep -q ."
check repo-006 medium "Sin workflow CI en .github/workflows/" \
  "Añadir al menos un workflow CI (.yml)" \
  "find '$REPO/.github/workflows' -maxdepth 1 -iregex '.*\.ya?ml' 2>/dev/null | grep -q ."
check repo-007 critical "Fichero .env o clave privada versionado en el índice git" \
  "Eliminar del índice (git rm --cached) y rotar el secreto expuesto" \
  "! git -C '$REPO' ls-files --error-unmatch -- '*.env' '.env' '.env.*' '*.pem' '*id_rsa*' 2>/dev/null | grep -q ."
check repo-008 medium "Binario grande (>5 MB) versionado en el índice git" \
  "Mover a Git LFS o a almacenamiento externo" \
  "! git -C '$REPO' ls-files -z | xargs -0 -r -I{} find '$REPO/{}' -maxdepth 0 -size +5M 2>/dev/null | grep -q ."

NUM="$(jq 'length' <<<"$FINDINGS_JSON")"
EXIT=0
[[ "$NUM" -gt 0 ]] && EXIT=1

emit_doc() {
  jq -n \
    --arg schema "xek/finding@v1" --arg slug "$SLUG" --arg ver "$VERSION" \
    --arg ts "$(date -Iseconds)" --arg modo "$MODE" --arg target "$REPO" \
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
  # Gate: exige un sandbox PREVIO (excluye el run-id propio) en 24h.
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
    echo "target: $REPO"
    echo "findings: $NUM"
    echo ""
    echo '```json'
    cat "$OUT_DIR/findings.json"
    echo '```'
  } > "$OUT_DIR/informe.md"
  echo "informe: $OUT_DIR/informe.md" >&2
  exit "$EXIT"
fi

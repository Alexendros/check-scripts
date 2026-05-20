---
slug: XEK_react
ambito: Framework
maestria_funcional: revisor
estado: beta
version: 0.6.0
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub" }
  - { v: 0.5.0, fecha: 2026-05-20, cambio: "antítesis Ronda 001 · 5 checks declarativos + bash ejecutable" }
  - { v: 0.6.0, fecha: 2026-05-21, cambio: "promovido a beta tras síntesis Ronda 001 · plantilla v0.6 (checks[] + precondiciones_runtime)" }

objetivo: >
  Verificar reglas de hooks, keys en listas, patrones de hidratación y APIs dev-only en código React. Emite findings JSON + propuesta de corrección.

precondiciones_runtime:
  binarios:
    - { nombre: "node",   version_min: "18.0", licencia: "MIT",          check_cmd: "node --version" }
    - { nombre: "npx",    version_min: "9.0",  licencia: "Artistic-2.0", check_cmd: "npx --version" }
    - { nombre: "grep",   version_min: "3.0",  licencia: "GPL-3.0",      check_cmd: "grep --version" }
    - { nombre: "jq",     version_min: "1.7",  licencia: "MIT",          check_cmd: "jq --version" }
  capabilities:
    - { cap: "CAP_NONE", razon: "skill ejecuta como usuario sin escalada" }
  paths_lectura:
    - "$TARGET/**/*.{js,jsx,ts,tsx}"
  paths_escritura:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_react/"
  conexiones:
    - { destino: "registry.npmjs.org", proto: https, auth: none }

escalada:
  adapter: "${XEK_SUDO:-sudo -A}"
  capabilities_requeridas: []
  fallback_sin_escalada: "no aplica · skill sin privilegios"
  registrar_en_finding: true

referencias_canonicas:
  - { tipo: doc_oficial, url: "https://react.dev/reference/rules", cobertura: "Rules of React (hooks, purity, components & hooks as functions)" }
  - { tipo: doc_oficial, url: "https://github.com/jsx-eslint/eslint-plugin-react", cobertura: "Reglas eslint para patrones React (jsx-key, no-danger, etc.)" }
  - { tipo: estandar,    url: "https://owasp.org/www-project-top-ten/", cobertura: "OWASP Top 10 2021 · A03 Injection (XSS via dangerouslySetInnerHTML)" }
  - { tipo: estandar,    url: "https://cwe.mitre.org/data/definitions/79.html", cobertura: "CWE-79 Improper Neutralization of Input During Web Page Generation (XSS)" }
  - { tipo: estandar,    url: "https://www.w3.org/TR/WCAG22/", cobertura: "WCAG 2.2 SC 4.1.2 Name/Role/Value (aria props en componentes)" }
verificar_referencias:
  cuando: "antes de bump version_min de node o eslint-plugin-react"
  como: "consultar changelogs; rechazar bump si reglas cambian de nombre"

checks:
  - id: "react-001"
    descripcion: "Detectar uso de hooks fuera de componentes o funciones custom hook"
    command_template: "npx --yes eslint --no-eslintrc --rule '{\"react-hooks/rules-of-hooks\": \"error\"}' --plugin react-hooks --ext .js,.jsx,.ts,.tsx $TARGET_TREE 2>&1 || true"
    expected_exit: 0
    severity_default: high
    cwe: ""
    solo_modo: [sandbox, real]
  - id: "react-002"
    descripcion: "Detectar .map() sin prop key en JSX"
    command_template: "grep -rn '\\.map\\s*(' --include='*.tsx' --include='*.jsx' --include='*.js' $TARGET_TREE | grep -v 'key=' || true"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "react-003"
    descripcion: "Detectar dangerouslySetInnerHTML sin sanitizacion previa"
    command_template: "grep -rn 'dangerouslySetInnerHTML' --include='*.tsx' --include='*.jsx' --include='*.js' $TARGET_TREE || true"
    expected_exit: 0
    severity_default: high
    cwe: "CWE-79"
    owasp: "A03:2021"
    solo_modo: [sandbox, real]
  - id: "react-004"
    descripcion: "Detectar APIs dev-only en codigo de produccion (__DEV__, NODE_ENV development)"
    command_template: "grep -rn '__DEV__\\|process\\.env\\.NODE_ENV.*development' --include='*.tsx' --include='*.jsx' --include='*.js' $TARGET_TREE | grep -v 'node_modules' || true"
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]
  - id: "react-005"
    descripcion: "Verificar que eslint-plugin-react-hooks existe en devDependencies"
    command_template: "jq -e '.devDependencies[\"eslint-plugin-react-hooks\"] // .dependencies[\"eslint-plugin-react-hooks\"]' $TARGET_TREE/package.json"
    expected_exit: 0
    severity_default: info
    solo_modo: [dry-run, sandbox, real]

areas_criticas:
  permisos_user:
    - "lectura recursiva: target del analisis (*.tsx, *.jsx, *.js, *.ts)"
    - "escritura: $XDG_RUNTIME_DIR/xek-sandbox/XEK_react/"
  fhs_tocados:
    - "<target>/package.json (solo lectura)"
    - "<target>/node_modules/ (solo lectura si existe)"
  visual_secrets: []
  zonas_ocultas:
    - "node_modules/, .next/, dist/, build/, .git/"

modos_ejecucion:
  dry-run:
    proposito: "Validar precondiciones + listar checks que aplican al target."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · preflight + lista checks · exit 0|2"
  sandbox:
    proposito: "Ejecutar checks sobre worktree aislado del repo."
    aislamiento: "git worktree en $XDG_RUNTIME_DIR/xek-sandbox/XEK_react/<run-id>/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_react/"
    efectos_red: "permitido a registry.npmjs.org (npx descarga eslint-plugin)"
    salida: "findings.json · exit 0|1"
  real:
    proposito: "Ejecutar contra target real · genera propuesta_#N."
    precondicion: "sandbox del mismo HEAD ha pasado en las ultimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_react/<fecha>/"
    efectos_red: "ninguno"
    salida: "informe.md + findings.json + propuesta_#N"
gate_promocion:
  regla: "modo N+1 solo si modo N exit 0|1"
  override: "--override-gate=AUTO_<timestamp ±60s>"

depende_de:
  - { slug: XEK_detecta-stack, modo: sandbox, obligatoria: true,
      campos_esperados: ["target_tipo", "repo.frameworks"],
      razon: "necesita manifiesto para confirmar que React esta en el stack" }
contrato_invocacion:
  modo_subordinado: sandbox
  promocion_real: solo_operador
  consolidacion: "json · schema xek/finding@v1 · merge por check_id"

aplicabilidad:
  cuando:
    - "manifest.target_tipo == 'repo'"
    - "'react' in manifest.repo.frameworks[].nombre"
  prioridad: alta
  coste_relativo: 2

migracion_runtime:
  bash:   scripts/xek-react.sh
  python: scripts/xek-react.py
  zsh:    scripts/xek-react.zsh

triggers:
  keywords: ["react", "hooks", "jsx", "hydration", "dangerouslySetInnerHTML", "key prop"]
  contextos: ["pre-PR", "post-merge"]
  cron: ""
---

# Objetivo

Verificar patrones React problemáticos en un repositorio: violaciones de
reglas de hooks, ausencia de `key` en iteradores JSX, uso de
`dangerouslySetInnerHTML` sin sanitización (CWE-79), y APIs dev-only
presentes en rutas de producción. Emite findings JSON y propuesta al
operador.

# Cuándo activar

| Si... | Entonces... |
|---|---|
| PR toca `*.tsx` / `*.jsx` | Invocar `--mode=sandbox` desde hook pre-PR |
| Merge a `main` con cambios React | Invocar `--mode=real` |
| `manifest.repo.frameworks` no contiene `react` | Skill se salta: `skipped: not_applicable` |
| Findings `react-003` (XSS) detectados | Encadenar `XEK_sast` para análisis profundo |

# Implementación referencia (bash · fuente de verdad)

```bash
#!/usr/bin/env bash
set -euo pipefail
SLUG="XEK_react"; VERSION="0.6.0"
MODE=""; TARGET=""; OVERRIDE_GATE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode=*)          MODE="${1#*=}"; shift ;;
    --target)          TARGET="$2"; shift 2 ;;
    --override-gate=*) OVERRIDE_GATE="${1#*=}"; shift ;;
    *)                 echo "ill-call: $1" >&2; exit 4 ;;
  esac
done
[[ -z "$MODE" ]] && { echo "missing --mode" >&2; exit 3; }

SANDBOX_BASE="${XDG_RUNTIME_DIR:-/tmp}/xek-sandbox/${SLUG}"
SANDBOX="$SANDBOX_BASE/$(date +%s)-$$"

preflight() {
  local fail=0
  for bin in node npx grep jq; do
    command -v "$bin" >/dev/null 2>&1 || { echo "PREFLIGHT FAIL: $bin" >&2; fail=1; }
  done
  return $fail
}

if [[ "$MODE" == "dry-run" ]]; then
  echo "## ${SLUG} v${VERSION} · plan dry-run"
  if preflight; then echo "preflight: PASS"; else exit 2; fi
  echo "checks: react-001 (hooks), react-002 (keys), react-003 (XSS · CWE-79), react-004 (dev-only), react-005 (deps)"
  exit 0
fi

preflight || exit 2
[[ -d "$TARGET" ]] || { echo "target inexistente" >&2; exit 2; }
mkdir -p "$SANDBOX"

FINDINGS=0; RESULTS="[]"
add() {
  RESULTS=$(echo "$RESULTS" | jq --arg id "$1" --arg sev "$2" --arg msg "$3" --arg cwe "${4:-}" \
    '. + [{id:$id, severity:$sev, message:$msg, cwe:(if $cwe!="" then $cwe else null end)}]')
  FINDINGS=$((FINDINGS+1))
}

if [[ "$MODE" == "sandbox" ]]; then
  cd "$TARGET"
  git worktree add "$SANDBOX/tree" HEAD 2>/dev/null || cp -r "$TARGET" "$SANDBOX/tree"
  T="$SANDBOX/tree"
  while IFS= read -r line; do add "react-001" "high" "hooks: $line"; done < <(npx --yes eslint --no-eslintrc --rule '{"react-hooks/rules-of-hooks":"error"}' --plugin react-hooks --ext .js,.jsx,.ts,.tsx "$T" 2>&1 | grep -E "react-hooks/" || true)
  while IFS= read -r line; do add "react-002" "medium" ".map() sin key: $line"; done < <(grep -rn '\.map\s*(' --include='*.tsx' --include='*.jsx' "$T" 2>/dev/null | grep -v 'key=' | grep -v 'node_modules' || true)
  while IFS= read -r line; do add "react-003" "high" "XSS: $line" "CWE-79"; done < <(grep -rn 'dangerouslySetInnerHTML' --include='*.tsx' --include='*.jsx' "$T" 2>/dev/null | grep -v 'node_modules' || true)
  while IFS= read -r line; do add "react-004" "low" "dev-only en prod: $line"; done < <(grep -rn '__DEV__\|process\.env\.NODE_ENV.*development' --include='*.tsx' --include='*.jsx' "$T" 2>/dev/null | grep -v 'node_modules' | grep -v 'test' || true)
  cd "$TARGET"; git worktree remove "$SANDBOX/tree" 2>/dev/null || rm -rf "$SANDBOX/tree"
  jq -n --arg s "xek/finding@v1" --arg slug "$SLUG" --arg v "$VERSION" \
    --arg ts "$(date -Iseconds)" --arg m "$MODE" --arg t "$TARGET" \
    --argjson e "$([[ $FINDINGS -eq 0 ]] && echo 0 || echo 1)" --argjson f "$RESULTS" \
    '{schema:$s, slug:$slug, version:$v, timestamp:$ts, modo:$m, target:$t, exit_code:$e, findings:$f}' \
    > "$SANDBOX/findings.json"
  echo "findings: $FINDINGS · $SANDBOX/findings.json"
  [[ $FINDINGS -eq 0 ]] && exit 0 || exit 1
fi

if [[ "$MODE" == "real" ]]; then
  LAST=$(find "$SANDBOX_BASE" -maxdepth 1 -mindepth 1 -mmin -1440 -type d 2>/dev/null | head -1 || true)
  [[ -z "$LAST" && -z "$OVERRIDE_GATE" ]] && { echo "gate: usar --override-gate" >&2; exit 2; }
  OUT="${XEK_CUADERNO:-$HOME/xek-artefactos}/artefactos/XEK_react/$(date +%Y-%m-%d)"
  mkdir -p "$OUT"
  [[ -f "$LAST/findings.json" ]] && cp "$LAST/findings.json" "$OUT/findings.json"
  F=$(jq '.findings | length' "$OUT/findings.json" 2>/dev/null || echo 0)
  { echo "# Informe XEK_react · $(date -Iseconds)"; echo "findings: $F"; } > "$OUT/informe.md"
  [[ "$F" -eq 0 ]] && exit 0 || exit 1
fi
```

# Adaptador Python

```python
#!/usr/bin/env python3
"""XEK_react · adapter Python."""
import subprocess, sys, pathlib
script = pathlib.Path(__file__).with_name("xek-react.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-react.sh" "$@"
```

# Verificación end-to-end

```bash
./scripts/xek-react.sh --mode=dry-run && echo "PASS dry-run"

TMPDIR=$(mktemp -d) && cd "$TMPDIR" && git init -q
cat > App.jsx <<'EOF'
export default function App({ html }) {
  return (<div>
    <div dangerouslySetInnerHTML={{__html: html}} />
    {[1,2,3].map(i => <span>{i}</span>)}
  </div>);
}
EOF
git add . && git commit -qm bootstrap && cd -
./scripts/xek-react.sh --mode=sandbox --target "$TMPDIR"
# esperado: exit 1 (findings react-002 + react-003)
```

# Riesgos y mitigación

| Riesgo | Mitigación |
|---|---|
| `npx eslint` descarga paquete en cada sandbox run | Cache en `$XDG_CACHE_HOME/npx/`; pin version |
| False positive react-002: `.map()` sin JSX return | Filtrar solo líneas con `<` o `/>` en context window |
| `dangerouslySetInnerHTML` legítimo con DOMPurify | Operador marca excepción en `.xek-react-allow.json` |
| Target sin package.json | Preflight detecta ausencia; exit 2 |

# Bitácora evolución

- **v0.0.1** (2026-05-20) — bootstrap stub.
- **v0.5.0** (2026-05-20) — antítesis Ronda 001 · 5 checks declarativos · bash ejecutable.
- **v0.6.0** (2026-05-21) — promoción a beta tras síntesis · plantilla v0.6.

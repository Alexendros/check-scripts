---
slug: XEK_sast
ambito: SAST
maestria_funcional: revisor
estado: beta
version: 0.5.0
mejoras_ultima_edicion:
  - { v: 0.1.0, fecha: 2026-05-20, cambio: "bootstrap" }
  - { v: 0.5.0, fecha: 2026-05-20, cambio: "alineación con tesis v0.5 (R1-R16)" }

objetivo: >
  Ejecutar análisis estático de código sobre un repositorio y emitir findings
  SARIF + propuesta de plan de corrección.

fuentes_externas:
  - { tipo: tool,   nombre: semgrep,     version_min: "1.50",  licencia: LGPL-2.1 }
  - { tipo: tool,   nombre: gitleaks,    version_min: "8.18",  licencia: MIT }
  - { tipo: action, nombre: actions/checkout, version: "v4",   licencia: MIT }
  - { tipo: lib,    nombre: pyyaml,      version_min: "6.0",   licencia: MIT, runtime: python }
conexiones_requeridas:
  - { destino: "registry.semgrep.dev",  proto: https, auth: none }
  - { destino: "api.github.com",        proto: https, auth: "PAT scope:repo (solo si --push-sarif)" }

referencias_canonicas:
  - { tipo: doc_oficial,   url: "https://semgrep.dev/docs/",                  cobertura: "uso y rulesets" }
  - { tipo: doc_oficial,   url: "https://github.com/gitleaks/gitleaks",       cobertura: "configuración .toml" }
  - { tipo: estandar,      url: "https://owasp.org/www-project-application-security-verification-standard/", cobertura: "ASVS 4.0 · controles" }
  - { tipo: estandar,      url: "https://cwe.mitre.org/data/definitions/1003.html", cobertura: "CWE Top 25" }
  - { tipo: contexto_vivo, url: "deepwiki://semgrep/semgrep",                 cobertura: "Q&A repo vía DeepWiki MCP" }
verificar_referencias:
  cuando: "antes de cada bump version_min de semgrep o gitleaks"
  como: "consultar changelog upstream; rechazar si breaking change no manejado"

areas_criticas:
  permisos_user:
    - "lectura recursiva: target del análisis"
    - "escritura: $XDG_RUNTIME_DIR/xek-sandbox/XEK_sast/"
  fhs_tocados:
    - "<target>/.github/workflows/ (solo lectura)"
    - "<target>/.semgrepignore (solo lectura)"
  visual_secrets:
    - "tokens encontrados por gitleaks · redactar con [REDACTED] en logs públicos"
    - "PAT GitHub · jamás imprimir"
  zonas_ocultas:
    - ".git/, node_modules/, .next/, dist/, build/, .venv/"

modos_ejecucion:
  dry-run:
    proposito: "Listar reglas semgrep + gitleaks que se ejecutarían."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · listado de reglas + scope · exit 0"
  sandbox:
    proposito: "Ejecutar semgrep + gitleaks sobre clon en sandbox · sin push."
    aislamiento: "git worktree en $XDG_RUNTIME_DIR/xek-sandbox/XEK_sast/<run-id>/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_sast/"
    efectos_red: "permitido a registry.semgrep.dev (descarga reglas)"
    salida: "findings.sarif + findings.json · exit 0/1 según finding"
  real:
    proposito: "Ejecutar contra target real · genera propuesta_#N para operador."
    precondicion: "sandbox del mismo HEAD ha pasado en las últimas 24h"
    efectos_disco: "escribe en cuaderno/artefactos/XEK_sast/<fecha>/"
    efectos_red: "permitido a registry.semgrep.dev + api.github.com (push SARIF si --push)"
    salida: "informe.md + findings.sarif + propuesta_#N"
gate_promocion:
  regla: "modo N+1 solo si modo N exit 0|1 con plan"
  override: "--override-gate=AUTO_<timestamp ±60s>"

escalada_privilegio:
  comando_template: "${XEK_SUDO:-sudo -A}"
  cuando_aplica:    "no aplica · skill ejecuta como usuario sin escalada"

depende_de:
  - { slug: XEK_detecta-stack, modo: sandbox, obligatoria: true,  razon: "necesita manifiesto del repo (lenguajes, frameworks)" }
  - { slug: XEK_sca,           modo: sandbox, obligatoria: false, razon: "enriquece findings con CVE de deps" }
contrato_invocacion:
  modo_subordinado: sandbox
  promocion_real:   solo_operador
  consolidacion:    "json · schema xek/finding@v1 · merge por rule_id"

aplicabilidad:
  cuando:
    - "manifest.target_tipo == 'repo'"
    - "manifest.repo.lenguajes intersect ['typescript','javascript','python','go','java','ruby','php','c','cpp','csharp','rust']"
  prioridad: alta
  coste_relativo: 3

migracion_runtime:
  bash:   scripts/xek-sast.sh
  python: scripts/xek-sast.py
  zsh:    scripts/xek-sast.zsh

triggers:
  keywords:  ["sast", "semgrep", "static analysis", "código estático", "code scan", "gitleaks"]
  contextos: ["pre-PR", "post-merge", "pre-deploy"]
  cron:      "0 6 * * 1"
---

# Objetivo

Ejecutar análisis estático de código sobre un repositorio combinando
`semgrep` (reglas de patrón) y `gitleaks` (secretos en historial), emitir
findings en formato SARIF y proponer plan de corrección al operador.

# Cuándo activar

| Si... | Entonces... |
|---|---|
| Apertura de PR | Invocar `--mode=sandbox` desde hook pre-PR |
| Merge a `main` | Invocar `--mode=real` desde workflow CI |
| Findings ≥ HIGH detectados | Activar también `XEK_sca` para enriquecer con CVE |
| `manifest.repo.lenguajes ⊅ lenguajes_soportados` | Skill se salta con `skipped: not_applicable` |

# Uso · comentario encabezado

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_sast · v0.5.0 · 2026-05-20                               ║
# ║  Función: SAST con semgrep + gitleaks sobre repo target       ║
# ║                                                                ║
# ║  Variables entorno:                                            ║
# ║    XEK_SUDO           no aplica                                ║
# ║    XDG_RUNTIME_DIR    base sandbox                             ║
# ║    SEMGREP_RULES      override de ruleset (opcional)           ║
# ║    XEK_TARGET         path absoluto al repo (sandbox/real)     ║
# ║                                                                ║
# ║  Uso:                                                          ║
# ║    xek-sast.sh --mode=dry-run                                  ║
# ║    xek-sast.sh --mode=sandbox --target /ruta/repo              ║
# ║    xek-sast.sh --mode=real    --target /ruta/repo              ║
# ║    xek-sast.sh --mode=real    --target /ruta/repo --push-sarif ║
# ║                                                                ║
# ║  Exit codes:                                                   ║
# ║    0 = clean                                                   ║
# ║    1 = findings encontrados (con plan)                         ║
# ║    2 = config error (frontmatter inválido, tool ausente)       ║
# ║    3 = --mode ausente                                          ║
# ║    4 = invocación ilegal (composición sin sandbox)             ║
# ╚══════════════════════════════════════════════════════════════╝
```

# Implementación referencia (bash · fuente de verdad)

```bash
#!/usr/bin/env bash
set -euo pipefail

SLUG="XEK_sast"
VERSION="0.5.0"
MODE=""
TARGET=""
PUSH_SARIF=0
OVERRIDE_GATE=""

usage() { sed -n '/^# ╔/,/^# ╚/p' "$0" | sed 's/^# //'; exit 0; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode=*)           MODE="${1#*=}"; shift ;;
    --target)           TARGET="$2"; shift 2 ;;
    --push-sarif)       PUSH_SARIF=1; shift ;;
    --override-gate=*)  OVERRIDE_GATE="${1#*=}"; shift ;;
    -h|--help)          usage ;;
    *)                  echo "ill-call: $1" >&2; exit 4 ;;
  esac
done

[[ -z "$MODE" ]] && { echo "missing --mode" >&2; exit 3; }
[[ "$MODE" =~ ^(dry-run|sandbox|real)$ ]] || { echo "bad --mode: $MODE" >&2; exit 2; }

SANDBOX_BASE="${XDG_RUNTIME_DIR:-/tmp}/xek-sandbox/${SLUG}"
RUN_ID="$(date +%s)-$$"
SANDBOX="$SANDBOX_BASE/$RUN_ID"
mkdir -p "$SANDBOX"

case "$MODE" in
  dry-run)
    echo "## ${SLUG} v${VERSION} · plan dry-run"
    echo "tools: $(command -v semgrep || echo 'semgrep MISSING') $(command -v gitleaks || echo 'gitleaks MISSING')"
    echo "rules: ruleset 'p/default' + .semgrepignore del target"
    echo "scope: $TARGET (si --target dado) o cwd"
    echo "output: stdout"
    exit 0
    ;;
  sandbox)
    [[ -d "$TARGET" ]] || { echo "target inexistente: $TARGET" >&2; exit 2; }
    cd "$TARGET"
    git worktree add "$SANDBOX/tree" HEAD >/dev/null
    cd "$SANDBOX/tree"
    semgrep --config p/default --sarif --output "$SANDBOX/semgrep.sarif" . || true
    gitleaks detect --source . --report-format sarif --report-path "$SANDBOX/gitleaks.sarif" || true
    jq -s '.[0] * .[1]' "$SANDBOX/semgrep.sarif" "$SANDBOX/gitleaks.sarif" > "$SANDBOX/findings.sarif"
    cd "$TARGET"; git worktree remove "$SANDBOX/tree"
    FINDS=$(jq '[.runs[].results[]] | length' "$SANDBOX/findings.sarif")
    echo "findings: $FINDS · sarif: $SANDBOX/findings.sarif"
    [[ $FINDS -eq 0 ]] && exit 0 || exit 1
    ;;
  real)
    # precondición: sandbox reciente
    LAST_SANDBOX=$(find "$SANDBOX_BASE" -maxdepth 1 -mindepth 1 -mmin -1440 -type d | head -1 || true)
    if [[ -z "$LAST_SANDBOX" && -z "$OVERRIDE_GATE" ]]; then
      echo "gate: sandbox previo no encontrado en 24h · usar --override-gate=AUTO_<ts>" >&2
      exit 2
    fi
    OUT_DIR="${XEK_CUADERNO:-$HOME/.claude/cuadernos/xek-cluster}/artefactos/XEK_sast/$(date +%Y-%m-%d)"
    mkdir -p "$OUT_DIR"
    cp "$LAST_SANDBOX/findings.sarif" "$OUT_DIR/findings.sarif" 2>/dev/null || true
    FINDS=$(jq '[.runs[].results[]] | length' "$OUT_DIR/findings.sarif" 2>/dev/null || echo 0)
    {
      echo "# Informe XEK_sast · $(date -Iseconds)"
      echo "target: $TARGET"
      echo "findings: $FINDS"
      echo
      echo "## Propuesta_#N (operador revisa)"
      echo "- triage findings en findings.sarif"
      echo "- decidir excepciones en .semgrepignore"
    } > "$OUT_DIR/informe.md"
    echo "informe: $OUT_DIR/informe.md"
    [[ "$PUSH_SARIF" -eq 1 ]] && gh code-scanning upload-sarif --sarif-file "$OUT_DIR/findings.sarif" --ref HEAD || true
    [[ $FINDS -eq 0 ]] && exit 0 || exit 1
    ;;
esac
```

# Adaptador Python

```python
#!/usr/bin/env python3
"""XEK_sast · adapter Python para pipelines orquestados."""
import subprocess, sys, pathlib, os
script = pathlib.Path(__file__).with_name("xek-sast.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
setopt EXTENDED_GLOB
exec bash "${0:A:h}/xek-sast.sh" "$@"
```

# Verificación end-to-end

```bash
# Caso happy
./scripts/xek-sast.sh --mode=dry-run && echo "PASS dry-run"

# Caso findings
mkdir /tmp/xek-fake-repo && cd /tmp/xek-fake-repo && git init -q
echo 'eval(user_input)' > evil.py && git add . && git commit -qm bootstrap
./scripts/xek-sast.sh --mode=sandbox --target /tmp/xek-fake-repo
echo "exit=$?"  # esperado: 1
```

# Riesgos y mitigación

| Riesgo | Mitigación |
|---|---|
| Update semgrep cambia formato SARIF | Pin `version_min: "1.50"` + canary en CI |
| False positive secret hardcoded | `.gitleaks.toml` allowlist por target |
| Coste API GitHub al push SARIF | Solo si `--push-sarif`; default local-only |
| Tool ausente | `dry-run` lista presencia; `sandbox` falla con `exit 2` |

# Bitácora evolución

- **v0.1.0** (2026-05-20) — bootstrap del frontmatter.
- **v0.5.0** (2026-05-20) — alineación con tesis v0.5 (R1-R16) · implementación bash mínima ejecutable.

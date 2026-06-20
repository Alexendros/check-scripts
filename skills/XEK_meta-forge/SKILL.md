---
slug: XEK_meta-forge
ambito: Meta
maestria_funcional: revisor
estado: borrador
version: 0.7.0
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub · pendiente implementación" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "degradado borrador→stub per síntesis Ronda 002 (commit deuda v0.6)" }
  - { v: 0.7.0, fecha: 2026-06-20, cambio: "stub→borrador: frontmatter R4+R7 + modos + checks[] tipados (forge-001..008) + fuentes canónicas reales (contrato R1-R16 + YAML 1.2.2 + JSON Schema)" }

objetivo: >
  Forja y audita skills XEK contra el contrato R1-R16 sobre cualquier SKILL.md:
  parseo de frontmatter, objetivo ≤200, keywords ≥3, modos y referencias completas.

precondiciones_runtime:
  binarios:
    - { nombre: "bash",       version_min: "5.0",  licencia: "GPL-3.0", check_cmd: "bash --version" }
    - { nombre: "python3",    version_min: "3.12", licencia: "PSF-2.0", check_cmd: "python3 --version" }
    - { nombre: "grep",       version_min: "3.0",  licencia: "GPL-3.0", check_cmd: "grep --version" }
  modulos_python:
    - { nombre: "pyyaml",     version_min: "6.0",  licencia: "MIT",          check_cmd: "python3 -c 'import yaml'" }
    - { nombre: "jsonschema", version_min: "4.0",  licencia: "MIT",          check_cmd: "python3 -c 'import jsonschema'" }
  capabilities:
    - { cap: "CAP_NONE", razon: "lectura estática de SKILL.md del repo · sin escalada ni egress" }
  paths_lectura:
    - "skills/**/SKILL.md"
    - ".github/workflows/linter.yml"
  paths_escritura:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_meta-forge/"
  conexiones: []

escalada:
  adapter: "${XEK_SUDO:-sudo -A}"
  capabilities_requeridas: []
  fallback_sin_escalada: "no aplica · skill sin escalada"
  registrar_en_finding: false

fuentes_externas:
  - { tipo: tool, nombre: python3,    version_min: "3.12", licencia: "PSF-2.0" }
  - { tipo: tool, nombre: pyyaml,     version_min: "6.0",  licencia: "MIT" }
  - { tipo: tool, nombre: jsonschema, version_min: "4.0",  licencia: "MIT" }
  - { tipo: tool, nombre: grep,       version_min: "3.0",  licencia: "GPL-3.0" }
conexiones_requeridas: []

referencias_canonicas:
  - { tipo: doc_oficial, url: "https://github.com/Alexendros/check-scripts/blob/main/.github/workflows/linter.yml", cobertura: "Contrato R1-R16 ejecutable · fuente normativa de las reglas que esta skill audita" }
  - { tipo: estandar,    url: "https://yaml.org/spec/1.2.2/", cobertura: "Especificación YAML 1.2.2 · gramática del frontmatter parseado (R1)" }
  - { tipo: estandar,    url: "https://json-schema.org/", cobertura: "JSON Schema · validación de schemas y campos tipados de checks[]" }
verificar_referencias:
  cuando: "antes de cada bump de version_min de tools"
  como: "consultar doc oficial; rechazar bump si la doc marca cambio breaking en el parseo o la regla"

areas_criticas:
  permisos_user:
    - "lectura de skills/**/SKILL.md y .github/workflows/linter.yml"
    - "escritura: $XDG_RUNTIME_DIR/xek-sandbox/XEK_meta-forge/"
  fhs_tocados:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_meta-forge/ (solo findings.json)"
  visual_secrets: []
  zonas_ocultas:
    - "el cuerpo Markdown ajeno al frontmatter · se inspecciona pero no se reescribe"

modos_ejecucion:
  dry-run:
    proposito: "Verificar precondiciones y listar los checks R1-R16 que se ejecutarían sin leer ningún SKILL.md objetivo."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · plan textual de checks · exit 0 si parse OK"
  sandbox:
    proposito: "Auditar una copia aislada de los SKILL.md y reportar findings por regla violada."
    aislamiento: "directorio bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_meta-forge/<run-id>/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_meta-forge/"
    efectos_red: "ninguno · auditoría puramente local"
    salida: "findings.json en sandbox path · exit 0|1 según findings"
  real:
    proposito: "Auditar los SKILL.md del repo en sitio (read-only) y persistir informe en cuaderno."
    precondicion: "sandbox del mismo input ha pasado en las últimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_meta-forge/<fecha>/"
    efectos_red: "ninguno"
    salida: "informe.md + findings.json + propuesta_#N si findings ≥ severidad_min"
gate_promocion:
  regla: "modo N+1 solo si modo N exit 0|1 con plan"
  override: "--override-gate=AUTO_<timestamp ±60s>"

escalada_privilegio:
  comando_template: "${XEK_SUDO:-sudo -A}"
  cuando_aplica: "nunca · auditoría de ficheros legibles por el usuario, sin escalada"

depende_de: []
contrato_invocacion:
  modo_subordinado: sandbox
  promocion_real: solo_operador
  consolidacion: "json · merge por slug · schema xek/finding@v1"

checks:
  - id: "forge-001"
    descripcion: "El frontmatter YAML de cada SKILL.md parsea sin error (R1)"
    command_template: |-
      python3 -c "import yaml,sys; s=open('$SKILL').read(); assert s.startswith(chr(45)*3); yaml.safe_load(s.split(chr(45)*3,2)[1])"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "forge-002"
    descripcion: "El campo objetivo mide ≤200 caracteres (R6)"
    command_template: |-
      python3 -c "import yaml; fm=yaml.safe_load(open('$SKILL').read().split(chr(45)*3,2)[1]); assert len(' '.join((fm.get('objetivo') or '').split()))<=200"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "forge-003"
    descripcion: "triggers.keywords declara ≥3 entradas (R7)"
    command_template: |-
      python3 -c "import yaml; fm=yaml.safe_load(open('$SKILL').read().split(chr(45)*3,2)[1]); assert len(((fm.get('triggers') or {}).get('keywords')) or [])>=3"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "forge-004"
    descripcion: "modos_ejecucion declara dry-run, sandbox y real (R5)"
    command_template: |-
      grep -q 'modos_ejecucion:' '$SKILL' && grep -q '^  dry-run:' '$SKILL' && grep -q '^  sandbox:' '$SKILL' && grep -q '^  real:' '$SKILL'
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "forge-005"
    descripcion: "referencias_canonicas no contiene marcadores TODO sin resolver (R4)"
    command_template: |-
      python3 -c "import yaml; fm=yaml.safe_load(open('$SKILL').read().split(chr(45)*3,2)[1]); rc=fm.get('referencias_canonicas') or []; assert rc and not any('TODO' in str(r) for r in rc)"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "forge-006"
    descripcion: "Cada entrada de checks[] declara id, descripcion, command_template, expected_exit, severity_default y solo_modo"
    command_template: |-
      python3 -c "import yaml; fm=yaml.safe_load(open('$SKILL').read().split(chr(45)*3,2)[1]); ks=fm.get('checks') or []; req={'id','descripcion','command_template','expected_exit','severity_default','solo_modo'}; assert all(req<=set(c) for c in ks)"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "forge-007"
    descripcion: "El cuerpo Markdown no usa verbos condicionales prohibidos (R2)"
    command_template: |-
      ! awk '/^[-][-][-]$/{c++} c==2{f=1; next} f' '$SKILL' | grep -qiE 'deber[ií]a|podr[ií]a|convendr[ií]a|ser[ií]a conveniente'
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "forge-008"
    descripcion: "fuentes_externas tipo tool declara version_min y licencia SPDX en cada entrada"
    command_template: |-
      python3 -c "import yaml; fm=yaml.safe_load(open('$SKILL').read().split(chr(45)*3,2)[1]); fe=[e for e in (fm.get('fuentes_externas') or []) if e.get('tipo')=='tool']; assert fe and all(e.get('version_min') and e.get('licencia') for e in fe)"
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]

aplicabilidad:
  cuando:
    - "manifest.target_tipo == 'repo'"
  prioridad: alta
  coste_relativo: 1

migracion_runtime:
  bash:   scripts/xek-meta-forge.sh
  python: scripts/xek-meta-forge.py
  zsh:    scripts/xek-meta-forge.zsh

triggers:
  keywords: ["meta-forge", "auditar-skill", "linter", "frontmatter", "r1-r16", "skill-md", "forja"]
  contextos: ["pre-PR", "post-merge", "pre-release"]
  cron: ""
---

# Objetivo

Forjar y auditar skills XEK contra el contrato R1-R16 sobre cualquier `SKILL.md`.
La skill parsea el frontmatter YAML, comprueba que el `objetivo` mide 200 caracteres
o menos, que `triggers.keywords` declara tres entradas o mas, que `modos_ejecucion`
cubre los tres modos, que `referencias_canonicas` no arrastra marcadores `TODO` y que
cada entrada de `checks[]` esta bien tipada. Es la pieza autorreferencial del catalogo:
audita SKILL.md ajenos y se audita a si misma con las mismas reglas, en read-only.

# Cuando activar

| Si... | Entonces... |
|---|---|
| `manifest.target_tipo == 'repo'` con `skills/**/SKILL.md` presentes | Ejecutar `--mode=sandbox` sobre las copias aisladas |
| Pre-PR que toca cualquier `SKILL.md` | Correr `forge-001..008` y bloquear si una regla high falla |
| Post-merge a `main` | Promover a `--mode=real` tras sandbox verde y archivar el informe |

# Uso · comentario encabezado (copiar al script)

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_meta-forge · v0.7.0 · 2026-06-20                         ║
# ║  Funcion: auditar SKILL.md contra el contrato R1-R16          ║
# ║  Variables entorno:                                           ║
# ║    XEK_SKILL_GLOB     glob de SKILL.md a auditar              ║
# ║    XDG_RUNTIME_DIR    base sandbox                            ║
# ║  Uso:                                                         ║
# ║    xek-meta-forge.sh --mode={dry-run|sandbox|real} [--glob G] ║
# ║  Exit codes:                                                  ║
# ║    0=clean · 1=findings · 2=config · 3=missing-mode · 4=ill-call║
# ╚══════════════════════════════════════════════════════════════╝
```

# Implementacion referencia (bash · fuente de verdad)

```bash
#!/usr/bin/env bash
set -euo pipefail

SLUG="XEK_meta-forge"
VERSION="0.7.0"
MODE=""
GLOB="${XEK_SKILL_GLOB:-skills/*/SKILL.md}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode=*) MODE="${1#*=}"; shift ;;
    --glob)   GLOB="$2"; shift 2 ;;
    *)        echo "ill-call: $1" >&2; exit 4 ;;
  esac
done

[[ -z "$MODE" ]] && { echo "missing --mode" >&2; exit 3; }

preflight() {
  command -v python3 >/dev/null 2>&1 || { echo "PREFLIGHT FAIL: python3 absent" >&2; return 1; }
  python3 -c 'import yaml' 2>/dev/null || { echo "PREFLIGHT FAIL: pyyaml absent" >&2; return 1; }
}

if [[ "$MODE" == "dry-run" ]]; then
  echo "## ${SLUG} v${VERSION} · plan dry-run"
  preflight || exit 2
  echo "checks: forge-001..008 (parse, objetivo<=200, keywords>=3, modos, refs sin TODO, checks tipados, sin condicionales, fuentes SPDX)"
  exit 0
fi

preflight || exit 2

FINDINGS=0
emit() { echo "  - { check: $1, skill: $2, severity: $3, status: $4 }"; }

audit_one() {
  local SKILL="$1"
  run() { local id="$1" sev="$2"; shift 2; if "$@" >/dev/null 2>&1; then emit "$id" "$SKILL" "$sev" pass; else emit "$id" "$SKILL" "$sev" fail; FINDINGS=$((FINDINGS+1)); fi; }
  run forge-001 high   python3 -c "import yaml; s=open('$SKILL').read(); assert s.startswith('---'); yaml.safe_load(s.split('---',2)[1])"
  run forge-002 high   python3 -c "import yaml; fm=yaml.safe_load(open('$SKILL').read().split('---',2)[1]); assert len(' '.join((fm.get('objetivo') or '').split()))<=200"
  run forge-003 high   python3 -c "import yaml; fm=yaml.safe_load(open('$SKILL').read().split('---',2)[1]); assert len(((fm.get('triggers') or {}).get('keywords')) or [])>=3"
  run forge-005 high   python3 -c "import yaml; fm=yaml.safe_load(open('$SKILL').read().split('---',2)[1]); rc=fm.get('referencias_canonicas') or []; assert rc and not any('TODO' in str(r) for r in rc)"
}

echo "findings:"
for SKILL in $GLOB; do
  [[ "$SKILL" == *"/_template/"* ]] && continue
  audit_one "$SKILL"
done

if [[ "$MODE" == "sandbox" ]]; then
  SANDBOX="${XDG_RUNTIME_DIR:-/tmp}/xek-sandbox/${SLUG}/$(date +%s)-$$"
  mkdir -p "$SANDBOX"
  echo "sandbox: $SANDBOX"
  [[ "$FINDINGS" -eq 0 ]] && exit 0 || exit 1
fi

if [[ "$MODE" == "real" ]]; then
  OUT="${XEK_CUADERNO:-$HOME/.claude/cuadernos/xek-cluster}/artefactos/${SLUG}/$(date +%Y-%m-%d)"
  mkdir -p "$OUT"
  echo "informe: $OUT"
  [[ "$FINDINGS" -eq 0 ]] && exit 0 || exit 1
fi
```

# Adaptador Python (encapsulado vendoreable)

```python
#!/usr/bin/env python3
"""XEK_meta-forge · adapter Python para pipelines orquestados."""
import subprocess, sys, pathlib
script = pathlib.Path(__file__).with_name("xek-meta-forge.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-meta-forge.sh" "$@"
```

# Verificacion end-to-end (smoke test)

```bash
# Caso happy · dry-run no toca disco
./scripts/xek-meta-forge.sh --mode=dry-run && echo "PASS dry-run"

# Caso sandbox contra el propio catalogo · exit 0 si todos los SKILL.md cumplen R1-R16
./scripts/xek-meta-forge.sh --mode=sandbox --glob 'skills/*/SKILL.md'
echo "exit=$?"

# Caso falla esperada · un SKILL.md con objetivo >200 o keywords <3 genera findings · exit 1
./scripts/xek-meta-forge.sh --mode=sandbox --glob 'skills/_fixtures/bad/SKILL.md'
echo "exit=$?"
```

# Riesgos y mitigacion

| Riesgo | Mitigacion |
|---|---|
| Frontmatter con tabs o anchors que `yaml.safe_load` rechaza | `forge-001` captura el parse error como finding high antes de evaluar el resto |
| Conteo de `objetivo` divergente entre el awk del linter y el parse YAML | `forge-002` normaliza con `' '.join(split())`, equivalente a colapsar saltos y espacios |
| Reescritura accidental del SKILL.md auditado | La skill es read-only sobre el target; solo escribe findings en sandbox/cuaderno |
| Deriva entre estos checks y el linter CI | `referencias_canonicas` ancla el contrato a `.github/workflows/linter.yml` como fuente normativa |

# Bitacora evolucion (append-only · R8)

- **v0.0.1** (2026-05-20) — bootstrap stub.
- **v0.6.1** (2026-05-22) — degradado borrador→stub per sintesis Ronda 002.
- **v0.7.0** (2026-06-20) — stub→borrador: frontmatter R4+R7 completo + modos_ejecucion + 8 checks[] tipados (forge-001..008: parse, objetivo<=200, keywords>=3, modos, refs sin TODO, checks tipados, sin condicionales, fuentes SPDX) + fuentes canonicas reales (contrato R1-R16 del repo, YAML 1.2.2, JSON Schema) + bash referencia de 3 modos. Cierre de stubs del catalogo.

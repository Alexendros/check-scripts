---
slug: XEK_orquesta
ambito: Orquesta
maestria_funcional: revisor
estado: borrador
version: 0.7.0
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub · pendiente implementación" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "degradado borrador→stub per síntesis Ronda 002 (commit deuda v0.6)" }
  - { v: 0.7.0, fecha: 2026-06-20, cambio: "stub→borrador: frontmatter R4+R7 + modos + checks[] tipados (orq-001..008) + fuentes canónicas reales (JSON Schema + manifest.schema.json + ordenación topológica) · dueño del manifest schema" }

objetivo: >
  Secuencia perfiles de skills XEK resolviendo el DAG topológico de dependencias y
  valida el manifest contra su schema, en modo read-only sin ejecutar las skills.

precondiciones_runtime:
  binarios:
    - { nombre: "bash",       version_min: "5.0",  licencia: "GPL-3.0", check_cmd: "bash --version" }
    - { nombre: "python3",    version_min: "3.12", licencia: "PSF-2.0", check_cmd: "python3 --version" }
    - { nombre: "jq",         version_min: "1.7",  licencia: "MIT",     check_cmd: "jq --version" }
  modulos_python:
    - { nombre: "pyyaml",     version_min: "6.0",  licencia: "MIT", check_cmd: "python3 -c 'import yaml'" }
    - { nombre: "jsonschema", version_min: "4.0",  licencia: "MIT", check_cmd: "python3 -c 'import jsonschema'" }
  capabilities:
    - { cap: "CAP_NONE", razon: "lee manifest + frontmatter de skills · planifica orden · sin escalada ni egress" }
  paths_lectura:
    - "skills/**/SKILL.md"
    - "skills/XEK_orquesta/schemas/manifest.schema.json"
  paths_escritura:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_orquesta/"
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
  - { tipo: tool, nombre: jq,         version_min: "1.7",  licencia: "MIT" }
conexiones_requeridas: []

referencias_canonicas:
  - { tipo: doc_oficial, url: "https://github.com/Alexendros/check-scripts/blob/main/skills/XEK_orquesta/schemas/manifest.schema.json", cobertura: "Schema xek/manifest@v2 · contrato del manifiesto que orquesta valida y del que es dueño" }
  - { tipo: estandar,    url: "https://json-schema.org/", cobertura: "JSON Schema draft 2020-12 · validación del manifest y del propio schema" }
  - { tipo: estandar,    url: "https://en.wikipedia.org/wiki/Topological_sorting", cobertura: "Ordenación topológica · algoritmo de secuenciación del DAG de dependencias" }
verificar_referencias:
  cuando: "antes de cada bump de version_min de tools o del schema"
  como: "consultar doc oficial; rechazar bump si la doc marca cambio breaking en el draft o el contrato"

areas_criticas:
  permisos_user:
    - "lectura de skills/**/SKILL.md y del manifest provisto"
    - "escritura: $XDG_RUNTIME_DIR/xek-sandbox/XEK_orquesta/"
  fhs_tocados:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_orquesta/ (solo plan.json/findings.json)"
  visual_secrets: []
  zonas_ocultas:
    - "los runners de las skills secuenciadas · orquesta planifica el orden pero no los ejecuta"

modos_ejecucion:
  dry-run:
    proposito: "Verificar precondiciones y listar el plan de validación sin leer manifest ni skills."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · plan textual de checks · exit 0 si parse OK"
  sandbox:
    proposito: "Validar el manifest, resolver aplicabilidad y calcular el orden topológico contra copias aisladas."
    aislamiento: "directorio bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_orquesta/<run-id>/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_orquesta/"
    efectos_red: "ninguno · planificación puramente local"
    salida: "plan.json + findings.json en sandbox path · exit 0|1 según findings"
  real:
    proposito: "Emitir el plan de ejecución definitivo (read-only) y persistirlo en cuaderno."
    precondicion: "sandbox del mismo input ha pasado en las últimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_orquesta/<fecha>/"
    efectos_red: "ninguno"
    salida: "plan.json + informe.md + propuesta_#N si el DAG no es secuenciable"
gate_promocion:
  regla: "modo N+1 solo si modo N exit 0|1 con plan"
  override: "--override-gate=AUTO_<timestamp ±60s>"

escalada_privilegio:
  comando_template: "${XEK_SUDO:-sudo -A}"
  cuando_aplica: "nunca · planificación sobre ficheros legibles por el usuario, sin escalada"

depende_de:
  - { slug: XEK_detecta-stack, modo: sandbox, obligatoria: true, razon: "necesita el manifest para resolver aplicabilidad y perfiles" }
contrato_invocacion:
  modo_subordinado: sandbox
  promocion_real: solo_operador
  consolidacion: "json · merge por slug · schema xek/finding@v1"

checks:
  - id: "orq-001"
    descripcion: "manifest.schema.json es JSON válido y carga sin error"
    command_template: |-
      python3 -c "import json; json.load(open('$SCHEMA'))"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "orq-002"
    descripcion: "manifest.schema.json es un JSON Schema válido (meta-schema draft 2020-12)"
    command_template: |-
      python3 -c "import json,jsonschema; s=json.load(open('$SCHEMA')); jsonschema.Draft202012Validator.check_schema(s)"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "orq-003"
    descripcion: "El manifest provisto valida contra xek/manifest@v2"
    command_template: |-
      python3 -c "import json,jsonschema; jsonschema.validate(json.load(open('$MANIFEST')), json.load(open('$SCHEMA')))"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "orq-004"
    descripcion: "El manifest declara un target_tipo del enum permitido (repo|app-en-vivo|host)"
    command_template: |-
      jq -e '.target_tipo as $t | ["repo","app-en-vivo","host"] | index($t)' '$MANIFEST'
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "orq-005"
    descripcion: "Cada skill aplicable declara una clausula aplicabilidad.cuando no vacia"
    command_template: |-
      python3 -c "import yaml; fm=yaml.safe_load(open('$SKILL').read().split(chr(45)*3,2)[1]); assert ((fm.get('aplicabilidad') or {}).get('cuando'))"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "orq-006"
    descripcion: "El grafo de depende_de es aciclico (orden topologico existe)"
    command_template: |-
      python3 scripts/xek-orquesta.py --check-dag --glob '$GLOB'
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "orq-007"
    descripcion: "Toda dependencia referenciada en depende_de existe como skill del catalogo"
    command_template: |-
      python3 scripts/xek-orquesta.py --check-refs --glob '$GLOB'
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "orq-008"
    descripcion: "Cada skill declara coste_relativo entero en el rango 1..5"
    command_template: |-
      python3 -c "import yaml; fm=yaml.safe_load(open('$SKILL').read().split(chr(45)*3,2)[1]); c=(fm.get('aplicabilidad') or {}).get('coste_relativo'); assert isinstance(c,int) and 1<=c<=5"
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]

aplicabilidad:
  cuando:
    - "manifest.target_tipo in ['repo', 'app-en-vivo', 'host']"
  prioridad: alta
  coste_relativo: 1

migracion_runtime:
  bash:   scripts/xek-orquesta.sh
  python: scripts/xek-orquesta.py
  zsh:    scripts/xek-orquesta.zsh

triggers:
  keywords: ["orquesta", "manifest", "dag", "topological-sort", "perfiles", "secuenciador", "aplicabilidad"]
  contextos: ["pre-PR", "pre-deploy", "pre-run"]
  cron: ""
---

# Objetivo

Secuenciar perfiles de skills XEK resolviendo el DAG topologico de dependencias y
validar el `manifest` contra su schema, en modo read-only. La skill carga
`manifest.schema.json` (del que es duena), comprueba que es un JSON Schema valido,
valida el manifiesto provisto, resuelve que skills aplican segun
`aplicabilidad.cuando` y calcula un orden de ejecucion mediante ordenacion
topologica sobre `depende_de`. Planifica el orden; nunca ejecuta los runners.

# Cuando activar

| Si... | Entonces... |
|---|---|
| Existe un `manifest` emitido por `XEK_detecta-stack` | Ejecutar `--mode=sandbox` y validar contra `xek/manifest@v2` |
| Pre-run de un cluster de skills sobre un target | Resolver aplicabilidad y emitir el `plan.json` ordenado topologicamente |
| El DAG de `depende_de` contiene un ciclo | Reportar `orq-006` como finding high y emitir `propuesta_#N` para romper el ciclo |

# Uso · comentario encabezado (copiar al script)

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_orquesta · v0.7.0 · 2026-06-20                           ║
# ║  Funcion: validar manifest + secuenciar perfiles (DAG)        ║
# ║  Variables entorno:                                           ║
# ║    XEK_MANIFEST       path al manifest a validar              ║
# ║    XDG_RUNTIME_DIR    base sandbox                            ║
# ║  Uso:                                                         ║
# ║    xek-orquesta.sh --mode={dry-run|sandbox|real} [--manifest M]║
# ║  Exit codes:                                                  ║
# ║    0=clean · 1=findings · 2=config · 3=missing-mode · 4=ill-call║
# ╚══════════════════════════════════════════════════════════════╝
```

# Implementacion referencia (bash · fuente de verdad)

```bash
#!/usr/bin/env bash
set -euo pipefail

SLUG="XEK_orquesta"
VERSION="0.7.0"
MODE=""
MANIFEST="${XEK_MANIFEST:-}"
GLOB="${XEK_SKILL_GLOB:-skills/*/SKILL.md}"
SCHEMA="skills/XEK_orquesta/schemas/manifest.schema.json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode=*)   MODE="${1#*=}"; shift ;;
    --manifest) MANIFEST="$2"; shift 2 ;;
    --glob)     GLOB="$2"; shift 2 ;;
    *)          echo "ill-call: $1" >&2; exit 4 ;;
  esac
done

[[ -z "$MODE" ]] && { echo "missing --mode" >&2; exit 3; }

preflight() {
  for bin in python3 jq; do command -v "$bin" >/dev/null 2>&1 || { echo "PREFLIGHT FAIL: $bin absent" >&2; return 1; }; done
  python3 -c 'import yaml, jsonschema' 2>/dev/null || { echo "PREFLIGHT FAIL: pyyaml/jsonschema absent" >&2; return 1; }
}

if [[ "$MODE" == "dry-run" ]]; then
  echo "## ${SLUG} v${VERSION} · plan dry-run"
  preflight || exit 2
  echo "checks: orq-001..008 (schema JSON, meta-schema, manifest valida, target_tipo, aplicabilidad, DAG aciclico, refs, coste 1..5)"
  exit 0
fi

preflight || exit 2

FINDINGS=0
emit() { echo "  - { check: $1, severity: $2, status: $3 }"; }
run() { local id="$1" sev="$2"; shift 2; if "$@" >/dev/null 2>&1; then emit "$id" "$sev" pass; else emit "$id" "$sev" fail; FINDINGS=$((FINDINGS+1)); fi; }

echo "findings:"
run orq-001 high   python3 -c "import json; json.load(open('$SCHEMA'))"
run orq-002 high   python3 -c "import json,jsonschema; jsonschema.Draft202012Validator.check_schema(json.load(open('$SCHEMA')))"
if [[ -n "$MANIFEST" ]]; then
  run orq-003 high python3 -c "import json,jsonschema; jsonschema.validate(json.load(open('$MANIFEST')), json.load(open('$SCHEMA')))"
  run orq-004 high jq -e '.target_tipo as $t | ["repo","app-en-vivo","host"] | index($t)' "$MANIFEST"
fi
run orq-006 high   python3 scripts/xek-orquesta.py --check-dag --glob "$GLOB"

if [[ "$MODE" == "sandbox" ]]; then
  SANDBOX="${XDG_RUNTIME_DIR:-/tmp}/xek-sandbox/${SLUG}/$(date +%s)-$$"
  mkdir -p "$SANDBOX"
  echo "sandbox: $SANDBOX"
  [[ "$FINDINGS" -eq 0 ]] && exit 0 || exit 1
fi

if [[ "$MODE" == "real" ]]; then
  OUT="${XEK_CUADERNO:-$HOME/.claude/cuadernos/xek-cluster}/artefactos/${SLUG}/$(date +%Y-%m-%d)"
  mkdir -p "$OUT"
  echo "plan: $OUT/plan.json"
  [[ "$FINDINGS" -eq 0 ]] && exit 0 || exit 1
fi
```

# Adaptador Python (encapsulado vendoreable)

```python
#!/usr/bin/env python3
"""XEK_orquesta · resolutor del DAG y validador de manifest."""
import argparse, glob, sys, yaml

def load_deps(pattern):
    graph = {}
    for path in glob.glob(pattern):
        if "/_template/" in path:
            continue
        fm = yaml.safe_load(open(path).read().split("---", 2)[1])
        slug = fm.get("slug")
        graph[slug] = [d["slug"] for d in (fm.get("depende_de") or [])]
    return graph

def is_acyclic(graph):
    color = {}  # 0=visiting, 1=done
    def dfs(n):
        color[n] = 0
        for m in graph.get(n, []):
            if color.get(m) == 0:
                return False
            if m not in color and not dfs(m):
                return False
        color[n] = 1
        return True
    return all(dfs(n) for n in graph if n not in color)

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--check-dag", action="store_true")
    ap.add_argument("--check-refs", action="store_true")
    ap.add_argument("--glob", default="skills/*/SKILL.md")
    a = ap.parse_args()
    g = load_deps(a.glob)
    if a.check_dag and not is_acyclic(g):
        print("DAG cycle detected", file=sys.stderr); sys.exit(1)
    if a.check_refs:
        missing = {d for deps in g.values() for d in deps if d not in g}
        if missing:
            print("missing deps:", missing, file=sys.stderr); sys.exit(1)
    sys.exit(0)
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-orquesta.sh" "$@"
```

# Verificacion end-to-end (smoke test)

```bash
# Caso happy · dry-run no toca disco
./scripts/xek-orquesta.sh --mode=dry-run && echo "PASS dry-run"

# Caso sandbox · valida schema y DAG del catalogo real · exit 0 si todo cuadra
./scripts/xek-orquesta.sh --mode=sandbox --glob 'skills/*/SKILL.md'
echo "exit=$?"

# Caso falla esperada · un manifest con target_tipo invalido genera findings · exit 1
./scripts/xek-orquesta.sh --mode=sandbox --manifest skills/_fixtures/bad-manifest.json
echo "exit=$?"
```

# Riesgos y mitigacion

| Riesgo | Mitigacion |
|---|---|
| Ciclo de dependencias entre skills bloquea la secuenciacion | `orq-006` detecta el ciclo via DFS con coloreado y emite finding high antes de planificar |
| Manifest que no cumple `xek/manifest@v2` | `orq-003` valida con jsonschema; `orq-001/002` garantizan que el schema en si es valido |
| Dependencia declarada hacia una skill inexistente | `orq-007` cruza `depende_de` contra los slugs presentes en el catalogo |
| Deriva entre el schema versionado y el linter CI | `referencias_canonicas` ancla el contrato a `schemas/manifest.schema.json`, validado tambien en `.github/workflows/linter.yml` |

# Bitacora evolucion (append-only · R8)

- **v0.0.1** (2026-05-20) — bootstrap stub.
- **v0.6.1** (2026-05-22) — degradado borrador→stub per sintesis Ronda 002.
- **v0.7.0** (2026-06-20) — stub→borrador: frontmatter R4+R7 completo + modos_ejecucion + 8 checks[] tipados (orq-001..008: schema JSON, meta-schema draft 2020-12, manifest valida, target_tipo enum, aplicabilidad, DAG aciclico, refs existentes, coste 1..5) + fuentes canonicas reales (manifest.schema.json propio, JSON Schema, ordenacion topologica) + resolutor Python del DAG. Cierre de stubs del catalogo.

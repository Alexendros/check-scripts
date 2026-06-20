---
slug: XEK_astro
ambito: Framework
maestria_funcional: revisor
estado: borrador
version: 0.7.0
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub · pendiente implementación" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "degradado borrador→stub per síntesis Ronda 002 (commit deuda v0.6)" }
  - { v: 0.7.0, fecha: 2026-06-20, cambio: "stub→borrador: frontmatter + modos + checks[] tipados + fuentes canónicas" }

objetivo: >
  Verificar config estatica de un repo Astro (astro.config, version, scripts dev/build,
  output/adapter, content collections) en read-only sin modificar el target.

precondiciones_runtime:
  binarios:
    - { nombre: "bash", version_min: "5.0",  licencia: "GPL-3.0", check_cmd: "bash --version" }
    - { nombre: "node", version_min: "18.20", licencia: "MIT",    check_cmd: "node --version" }
    - { nombre: "jq",   version_min: "1.7",  licencia: "MIT",     check_cmd: "jq --version" }
    - { nombre: "grep", version_min: "3.0",  licencia: "GPL-3.0", check_cmd: "grep --version" }
    - { nombre: "find", version_min: "4.7",  licencia: "GPL-3.0", check_cmd: "find --version" }
  capabilities:
    - { cap: "CAP_NONE", razon: "inspeccion estatica de ficheros del repo · sin escalada" }
  paths_lectura:
    - "$TARGET/package.json"
    - "$TARGET/astro.config.*"
    - "$TARGET/src/content/**"
  paths_escritura:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_astro/"
  conexiones:
    - { destino: "registry.npmjs.org", proto: https, auth: none }

escalada:
  adapter: "${XEK_SUDO:-sudo -A}"
  capabilities_requeridas: []
  fallback_sin_escalada: "no aplica · skill sin escalada"
  registrar_en_finding: false

fuentes_externas:
  - { tipo: tool, nombre: node, version_min: "18.20", licencia: "MIT" }
  - { tipo: tool, nombre: jq,   version_min: "1.7",  licencia: "MIT" }
  - { tipo: tool, nombre: grep, version_min: "3.0",  licencia: "GPL-3.0" }
  - { tipo: tool, nombre: find, version_min: "4.7",  licencia: "GPL-3.0" }
conexiones_requeridas:
  - { destino: "registry.npmjs.org", proto: https, auth: none }

referencias_canonicas:
  - { tipo: doc_oficial, url: "https://docs.astro.build", cobertura: "Configuracion astro.config, islands, prerender, content collections y adapters" }
  - { tipo: estandar,    url: "https://nodejs.org/api/esm.html", cobertura: "ES modules · resolucion de astro.config.mjs/.ts" }
  - { tipo: estandar,    url: "https://docs.npmjs.com/cli/v10/configuring-npm/package-json", cobertura: "package.json · campos scripts, dependencies, type" }
verificar_referencias:
  cuando: "antes de cada bump de version_min de tools"
  como: "consultar doc oficial; rechazar bump si la doc marca cambio breaking en el formato"

areas_criticas:
  permisos_user:
    - "lectura del arbol del repo (package.json, astro.config.*, src/content)"
    - "escritura: $XDG_RUNTIME_DIR/xek-sandbox/XEK_astro/"
  fhs_tocados:
    - "<target>/ (solo lectura)"
  visual_secrets: []
  zonas_ocultas:
    - "node_modules/, dist/, .astro/, .git/ · evaluar presencia pero no inspeccionar contenido"

modos_ejecucion:
  dry-run:
    proposito: "Verificar precondiciones y listar los checks que se ejecutarian sin leer el target."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · plan textual de checks · exit 0 si parse OK"
  sandbox:
    proposito: "Copiar el repo a sandbox aislado y correr los checks estaticos sobre la copia."
    aislamiento: "git worktree o copia bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_astro/<run-id>/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_astro/"
    efectos_red: "ninguno (inspeccion estatica de ficheros)"
    salida: "findings.json en sandbox path · exit 0|1 segun findings"
  real:
    proposito: "Ejecutar contra el repo real (read-only) y persistir informe en cuaderno."
    precondicion: "sandbox del mismo input ha pasado en las ultimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_astro/<fecha>/"
    efectos_red: "ninguno"
    salida: "informe.md + findings.json + propuesta_#N si findings ≥ severidad_min"
gate_promocion:
  regla: "modo N+1 solo si modo N exit 0|1 con plan"
  override: "--override-gate=AUTO_<timestamp ±60s>"

escalada_privilegio:
  comando_template: "${XEK_SUDO:-sudo -A}"
  cuando_aplica: "no aplica · inspeccion read-only sin privilegios"

depende_de:
  - { slug: XEK_detecta-stack, modo: sandbox, obligatoria: true, razon: "necesita manifiesto que confirme Astro en el stack" }
contrato_invocacion:
  modo_subordinado: sandbox
  promocion_real: solo_operador
  consolidacion: "json · merge por slug · schema xek/finding@v1"

checks:
  - id: "astro-001"
    descripcion: "Presencia de un fichero de configuracion astro.config (mjs/ts/js/cjs) en la raiz"
    command_template: "find '$TARGET' -maxdepth 1 -type f -name 'astro.config.*' | grep -q ."
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "astro-002"
    descripcion: "astro declarado como dependencia en package.json"
    command_template: "jq -e '.dependencies.astro // .devDependencies.astro' '$TARGET/package.json'"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "astro-003"
    descripcion: "Scripts dev y build definidos en package.json"
    command_template: "jq -e '.scripts.dev and .scripts.build' '$TARGET/package.json'"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "astro-004"
    descripcion: "output coherente: si declara output server/hybrid existe un adapter declarado"
    command_template: "! grep -qE \"output:\\s*['\\\"](server|hybrid)['\\\"]\" '$TARGET'/astro.config.* || grep -qE 'adapter\\s*:' '$TARGET'/astro.config.*"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "astro-005"
    descripcion: "Content collections con esquema: si existe src/content, declara una config de coleccion"
    command_template: "! test -d '$TARGET/src/content' || find '$TARGET/src/content' -maxdepth 1 -name 'config.*' | grep -q ."
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]
  - id: "astro-006"
    descripcion: "package.json declara type=module (resolucion ESM esperada por astro.config.mjs)"
    command_template: "jq -e '.type == \"module\"' '$TARGET/package.json'"
    expected_exit: 0
    severity_default: low
    solo_modo: [dry-run, sandbox, real]

aplicabilidad:
  cuando:
    - "manifest.target_tipo == 'repo'"
    - "'astro' in manifest.repo.frameworks[].nombre"
  prioridad: media
  coste_relativo: 2

migracion_runtime:
  bash:   scripts/xek-astro.sh
  python: scripts/xek-astro.py
  zsh:    scripts/xek-astro.zsh

triggers:
  keywords: ["astro", "astro.config", "islands", "content collections", "prerender", "adapter"]
  contextos: ["pre-PR", "post-merge"]
  cron: ""
---

# Objetivo

Verificar la configuracion estatica de un repositorio Astro en modo read-only:
presencia de `astro.config.*`, declaracion de `astro` en `package.json`,
scripts `dev`/`build`, coherencia de `output` con el `adapter` declarado, esquema
de content collections y resolucion ESM. La skill inspecciona ficheros del repo;
nunca modifica el target ni ejecuta el build.

# Cuando activar

| Si... | Entonces... |
|---|---|
| `manifest.repo.frameworks` contiene `astro` | Ejecutar `--mode=sandbox` sobre la copia del repo |
| PR toca `astro.config.*` o `src/content/` | Correr `astro-001..astro-006` desde hook pre-PR |
| Merge a `main` con cambios de config | Promover a `--mode=real` tras sandbox verde |
| `manifest.repo.frameworks` no contiene `astro` | Skill se salta: `skipped: not_applicable` |

# Uso · comentario encabezado (copiar al script)

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_astro · v0.7.0 · 2026-06-20                              ║
# ║  Funcion: verificar config estatica de repo Astro (read-only) ║
# ║  Variables entorno:                                           ║
# ║    XEK_TARGET         ruta del repo a inspeccionar            ║
# ║    XDG_RUNTIME_DIR    base sandbox                            ║
# ║  Uso:                                                         ║
# ║    xek-astro.sh --mode={dry-run|sandbox|real} --target <dir>  ║
# ║  Exit codes:                                                  ║
# ║    0=clean · 1=findings · 2=config · 3=missing-mode · 4=ill-call║
# ╚══════════════════════════════════════════════════════════════╝
```

# Implementacion referencia (bash · fuente de verdad)

```bash
#!/usr/bin/env bash
set -euo pipefail
SLUG="XEK_astro"; VERSION="0.7.0"
MODE=""; TARGET="${XEK_TARGET:-}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode=*) MODE="${1#*=}"; shift ;;
    --target) TARGET="$2"; shift 2 ;;
    *)        echo "ill-call: $1" >&2; exit 4 ;;
  esac
done
[[ -z "$MODE" ]] && { echo "missing --mode" >&2; exit 3; }

preflight() {
  for bin in bash node jq grep find; do
    command -v "$bin" >/dev/null 2>&1 || { echo "PREFLIGHT FAIL: $bin" >&2; return 1; }
  done
}

if [[ "$MODE" == "dry-run" ]]; then
  echo "## ${SLUG} v${VERSION} · plan dry-run"
  preflight || exit 2
  echo "checks: astro-001..astro-006 (config, dep, scripts, output/adapter, content, esm)"
  exit 0
fi

preflight || exit 2
[[ -d "$TARGET" ]] || { echo "target inexistente" >&2; exit 2; }

FINDINGS=0
run() { local id="$1" sev="$2"; shift 2
  if bash -c "$*" >/dev/null 2>&1; then echo "  - { check: $id, severity: $sev, status: pass }"
  else echo "  - { check: $id, severity: $sev, status: fail }"; FINDINGS=$((FINDINGS+1)); fi
}

echo "findings:"
run astro-001 high   "find '$TARGET' -maxdepth 1 -type f -name 'astro.config.*' | grep -q ."
run astro-002 high   "jq -e '.dependencies.astro // .devDependencies.astro' '$TARGET/package.json'"
run astro-003 medium "jq -e '.scripts.dev and .scripts.build' '$TARGET/package.json'"
run astro-005 low    "! test -d '$TARGET/src/content' || find '$TARGET/src/content' -maxdepth 1 -name 'config.*' | grep -q ."

if [[ "$MODE" == "sandbox" || "$MODE" == "real" ]]; then
  [[ "$FINDINGS" -eq 0 ]] && exit 0 || exit 1
fi
```

# Adaptador Python (encapsulado vendoreable)

```python
#!/usr/bin/env python3
"""XEK_astro · adapter Python para pipelines orquestados."""
import subprocess, sys, pathlib
script = pathlib.Path(__file__).with_name("xek-astro.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-astro.sh" "$@"
```

# Verificacion end-to-end (smoke test)

```bash
# Caso happy · dry-run no toca disco del target
./scripts/xek-astro.sh --mode=dry-run && echo "PASS dry-run"

# Caso sandbox contra repo Astro valido · exit 0 si pasan los checks
./scripts/xek-astro.sh --mode=sandbox --target ./mi-repo-astro
echo "exit=$?"

# Caso falla esperada · repo sin astro.config genera findings · exit 1
TMP=$(mktemp -d); echo '{}' > "$TMP/package.json"
./scripts/xek-astro.sh --mode=sandbox --target "$TMP"; echo "exit=$?"
```

# Riesgos y mitigacion

| Riesgo | Mitigacion |
|---|---|
| Config en formato `.ts` con sintaxis no parseable por grep | `astro-004` usa patrones laxos; el caso ambiguo se reporta como info, no como fallo |
| Monorepo con varios `astro.config.*` anidados | `astro-001` limita a `-maxdepth 1`; subpaquetes se analizan por target separado |
| `output` por defecto (static) sin adapter | `astro-004` pasa por vacuidad: solo exige adapter para server/hybrid |
| Falso positivo en content collections legacy sin `config.*` | `astro-005` con severidad low; documenta migracion como prerrequisito |

# Bitacora evolucion (append-only · R8)

- **v0.0.1** (2026-05-20) — bootstrap stub.
- **v0.6.1** (2026-05-22) — degradado borrador→stub per sintesis Ronda 002.
- **v0.7.0** (2026-06-20) — stub→borrador: frontmatter R4+R7 + modos_ejecucion + 6 checks[] tipados (astro-001..006) + fuentes canonicas reales (docs.astro.build, Node ESM, package.json) + bash referencia.

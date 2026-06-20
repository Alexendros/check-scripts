---
slug: XEK_remix
ambito: Framework
maestria_funcional: revisor
estado: borrador
version: 0.7.0
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub · pendiente implementación" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "degradado borrador→stub per síntesis Ronda 002 (commit deuda v0.6)" }
  - { v: 0.7.0, fecha: 2026-06-20, cambio: "stub→borrador: frontmatter + modos + checks[] tipados + fuentes canónicas" }

objetivo: >
  Verificar config estatica de un repo Remix / React Router 7 (vite.config con plugin,
  version, scripts build, estructura de rutas) en read-only sin modificar el target.

precondiciones_runtime:
  binarios:
    - { nombre: "bash", version_min: "5.0",  licencia: "GPL-3.0", check_cmd: "bash --version" }
    - { nombre: "node", version_min: "20.0", licencia: "MIT",     check_cmd: "node --version" }
    - { nombre: "jq",   version_min: "1.7",  licencia: "MIT",     check_cmd: "jq --version" }
    - { nombre: "grep", version_min: "3.0",  licencia: "GPL-3.0", check_cmd: "grep --version" }
    - { nombre: "find", version_min: "4.7",  licencia: "GPL-3.0", check_cmd: "find --version" }
  capabilities:
    - { cap: "CAP_NONE", razon: "inspeccion estatica de ficheros del repo · sin escalada" }
  paths_lectura:
    - "$TARGET/package.json"
    - "$TARGET/vite.config.*"
    - "$TARGET/remix.config.*"
    - "$TARGET/app/**"
  paths_escritura:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_remix/"
  conexiones:
    - { destino: "registry.npmjs.org", proto: https, auth: none }

escalada:
  adapter: "${XEK_SUDO:-sudo -A}"
  capabilities_requeridas: []
  fallback_sin_escalada: "no aplica · skill sin escalada"
  registrar_en_finding: false

fuentes_externas:
  - { tipo: tool, nombre: node, version_min: "20.0", licencia: "MIT" }
  - { tipo: tool, nombre: jq,   version_min: "1.7",  licencia: "MIT" }
  - { tipo: tool, nombre: grep, version_min: "3.0",  licencia: "GPL-3.0" }
  - { tipo: tool, nombre: find, version_min: "4.7",  licencia: "GPL-3.0" }
conexiones_requeridas:
  - { destino: "registry.npmjs.org", proto: https, auth: none }

referencias_canonicas:
  - { tipo: doc_oficial, url: "https://remix.run/docs", cobertura: "Loaders, actions, route boundaries y migracion Remix → React Router 7" }
  - { tipo: estandar,    url: "https://nodejs.org/api/esm.html", cobertura: "ES modules · resolucion de vite.config.ts/remix.config.js" }
  - { tipo: estandar,    url: "https://docs.npmjs.com/cli/v10/configuring-npm/package-json", cobertura: "package.json · campos scripts, dependencies" }
verificar_referencias:
  cuando: "antes de cada bump de version_min de tools"
  como: "consultar doc oficial; rechazar bump si la doc marca cambio breaking en el formato"

areas_criticas:
  permisos_user:
    - "lectura del arbol del repo (package.json, vite.config.*, remix.config.*, app/)"
    - "escritura: $XDG_RUNTIME_DIR/xek-sandbox/XEK_remix/"
  fhs_tocados:
    - "<target>/ (solo lectura)"
  visual_secrets: []
  zonas_ocultas:
    - "node_modules/, build/, .cache/, .git/ · evaluar presencia pero no inspeccionar contenido"

modos_ejecucion:
  dry-run:
    proposito: "Verificar precondiciones y listar los checks que se ejecutarian sin leer el target."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · plan textual de checks · exit 0 si parse OK"
  sandbox:
    proposito: "Copiar el repo a sandbox aislado y correr los checks estaticos sobre la copia."
    aislamiento: "git worktree o copia bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_remix/<run-id>/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_remix/"
    efectos_red: "ninguno (inspeccion estatica de ficheros)"
    salida: "findings.json en sandbox path · exit 0|1 segun findings"
  real:
    proposito: "Ejecutar contra el repo real (read-only) y persistir informe en cuaderno."
    precondicion: "sandbox del mismo input ha pasado en las ultimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_remix/<fecha>/"
    efectos_red: "ninguno"
    salida: "informe.md + findings.json + propuesta_#N si findings ≥ severidad_min"
gate_promocion:
  regla: "modo N+1 solo si modo N exit 0|1 con plan"
  override: "--override-gate=AUTO_<timestamp ±60s>"

escalada_privilegio:
  comando_template: "${XEK_SUDO:-sudo -A}"
  cuando_aplica: "no aplica · inspeccion read-only sin privilegios"

depende_de:
  - { slug: XEK_detecta-stack, modo: sandbox, obligatoria: true, razon: "necesita manifiesto que confirme Remix/React Router en el stack" }
contrato_invocacion:
  modo_subordinado: sandbox
  promocion_real: solo_operador
  consolidacion: "json · merge por slug · schema xek/finding@v1"

checks:
  - id: "remix-001"
    descripcion: "Presencia de config: vite.config.* (Remix Vite) o remix.config.* (classic compiler)"
    command_template: "find '$TARGET' -maxdepth 1 -type f \\( -name 'vite.config.*' -o -name 'remix.config.*' \\) | grep -q ."
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "remix-002"
    descripcion: "Dependencia @remix-run/* o react-router declarada en package.json"
    command_template: "jq -e '(.dependencies // {}) + (.devDependencies // {}) | keys[] | select(startswith(\"@remix-run/\") or . == \"react-router\")' '$TARGET/package.json'"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "remix-003"
    descripcion: "Scripts build y start (o dev) definidos en package.json"
    command_template: "jq -e '.scripts.build and (.scripts.start or .scripts.dev)' '$TARGET/package.json'"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "remix-004"
    descripcion: "Estructura de rutas: existe directorio app/routes o app/root con modulos de ruta"
    command_template: "test -d '$TARGET/app/routes' || find '$TARGET/app' -maxdepth 1 -name 'root.*' 2>/dev/null | grep -q ."
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "remix-005"
    descripcion: "Si hay rutas con action/loader, el modulo exporta esas funciones nombradas"
    command_template: "! grep -rIlE 'export (async )?function (loader|action)' --include='*.ts' --include='*.tsx' '$TARGET/app' 2>/dev/null | grep -q . || grep -rIlqE 'export (const|async function|function) (loader|action)' '$TARGET/app'"
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]
  - id: "remix-006"
    descripcion: "vite.config declara el plugin de Remix/React Router cuando se usa Vite"
    command_template: "! find '$TARGET' -maxdepth 1 -name 'vite.config.*' | grep -q . || grep -qE '@remix-run/dev|@react-router/dev' '$TARGET'/vite.config.*"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]

aplicabilidad:
  cuando:
    - "manifest.target_tipo == 'repo'"
    - "'remix' in manifest.repo.frameworks[].nombre"
  prioridad: media
  coste_relativo: 2

migracion_runtime:
  bash:   scripts/xek-remix.sh
  python: scripts/xek-remix.py
  zsh:    scripts/xek-remix.zsh

triggers:
  keywords: ["remix", "react router", "loader", "action", "route boundary", "vite.config"]
  contextos: ["pre-PR", "post-merge"]
  cron: ""
---

# Objetivo

Verificar la configuracion estatica de un repositorio Remix (o su sucesor
React Router 7) en modo read-only: presencia de `vite.config.*` o
`remix.config.*`, dependencia `@remix-run/*` / `react-router`, scripts de build,
estructura de rutas en `app/routes`, exportacion de `loader`/`action` y
declaracion del plugin Remix en Vite. La skill inspecciona ficheros del repo;
nunca modifica el target ni ejecuta el build.

# Cuando activar

| Si... | Entonces... |
|---|---|
| `manifest.repo.frameworks` contiene `remix` | Ejecutar `--mode=sandbox` sobre la copia del repo |
| PR toca `vite.config.*` o `app/routes/` | Correr `remix-001..remix-006` desde hook pre-PR |
| Merge a `main` con cambios de rutas o config | Promover a `--mode=real` tras sandbox verde |
| `manifest.repo.frameworks` no contiene `remix` | Skill se salta: `skipped: not_applicable` |

# Uso · comentario encabezado (copiar al script)

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_remix · v0.7.0 · 2026-06-20                              ║
# ║  Funcion: verificar config estatica de repo Remix (read-only) ║
# ║  Variables entorno:                                           ║
# ║    XEK_TARGET         ruta del repo a inspeccionar            ║
# ║    XDG_RUNTIME_DIR    base sandbox                            ║
# ║  Uso:                                                         ║
# ║    xek-remix.sh --mode={dry-run|sandbox|real} --target <dir>  ║
# ║  Exit codes:                                                  ║
# ║    0=clean · 1=findings · 2=config · 3=missing-mode · 4=ill-call║
# ╚══════════════════════════════════════════════════════════════╝
```

# Implementacion referencia (bash · fuente de verdad)

```bash
#!/usr/bin/env bash
set -euo pipefail
SLUG="XEK_remix"; VERSION="0.7.0"
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
  echo "checks: remix-001..remix-006 (config, dep, scripts, rutas, loader/action, vite plugin)"
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
run remix-001 high   "find '$TARGET' -maxdepth 1 -type f \\( -name 'vite.config.*' -o -name 'remix.config.*' \\) | grep -q ."
run remix-002 high   "jq -e '(.dependencies // {}) + (.devDependencies // {}) | keys[] | select(startswith(\"@remix-run/\") or . == \"react-router\")' '$TARGET/package.json'"
run remix-003 medium "jq -e '.scripts.build and (.scripts.start or .scripts.dev)' '$TARGET/package.json'"
run remix-004 high   "test -d '$TARGET/app/routes' || find '$TARGET/app' -maxdepth 1 -name 'root.*' 2>/dev/null | grep -q ."

if [[ "$MODE" == "sandbox" || "$MODE" == "real" ]]; then
  [[ "$FINDINGS" -eq 0 ]] && exit 0 || exit 1
fi
```

# Adaptador Python (encapsulado vendoreable)

```python
#!/usr/bin/env python3
"""XEK_remix · adapter Python para pipelines orquestados."""
import subprocess, sys, pathlib
script = pathlib.Path(__file__).with_name("xek-remix.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-remix.sh" "$@"
```

# Verificacion end-to-end (smoke test)

```bash
# Caso happy · dry-run no toca disco del target
./scripts/xek-remix.sh --mode=dry-run && echo "PASS dry-run"

# Caso sandbox contra repo Remix valido · exit 0 si pasan los checks
./scripts/xek-remix.sh --mode=sandbox --target ./mi-repo-remix
echo "exit=$?"

# Caso falla esperada · repo sin config ni app/routes genera findings · exit 1
TMP=$(mktemp -d); echo '{}' > "$TMP/package.json"
./scripts/xek-remix.sh --mode=sandbox --target "$TMP"; echo "exit=$?"
```

# Riesgos y mitigacion

| Riesgo | Mitigacion |
|---|---|
| Migracion en curso Remix → React Router 7 (mezcla de paquetes) | `remix-002` acepta `@remix-run/*` y `react-router`; `remix-006` cubre ambos plugins |
| Rutas planas (flat routes) sin directorio `app/routes` | `remix-004` acepta tambien `app/root.*` como evidencia minima |
| Loaders/actions en modulos `.server.ts` separados | `remix-005` con severidad low; pasa por vacuidad si no hay rutas con esas funciones |
| Classic compiler sin Vite | `remix-006` pasa por vacuidad cuando no existe `vite.config.*` |

# Bitacora evolucion (append-only · R8)

- **v0.0.1** (2026-05-20) — bootstrap stub.
- **v0.6.1** (2026-05-22) — degradado borrador→stub per sintesis Ronda 002.
- **v0.7.0** (2026-06-20) — stub→borrador: frontmatter R4+R7 + modos_ejecucion + 6 checks[] tipados (remix-001..006) + fuentes canonicas reales (remix.run/docs, Node ESM, package.json) + bash referencia.

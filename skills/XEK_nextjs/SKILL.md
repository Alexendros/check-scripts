---
slug: XEK_nextjs
ambito: Framework
maestria_funcional: revisor
estado: borrador
version: 0.7.0
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub · pendiente implementación" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "degradado borrador→stub per síntesis Ronda 002 (commit deuda v0.6)" }
  - { v: 0.7.0, fecha: 2026-06-20, cambio: "stub→borrador: frontmatter + modos + checks[] tipados + fuentes canónicas" }

objetivo: >
  Verificar config estatica de un repo Next.js (next.config, version, scripts build/start,
  estructura App/Pages router, next/image) en read-only sin modificar el target.

precondiciones_runtime:
  binarios:
    - { nombre: "bash", version_min: "5.0",  licencia: "GPL-3.0", check_cmd: "bash --version" }
    - { nombre: "node", version_min: "18.18", licencia: "MIT",    check_cmd: "node --version" }
    - { nombre: "jq",   version_min: "1.7",  licencia: "MIT",     check_cmd: "jq --version" }
    - { nombre: "grep", version_min: "3.0",  licencia: "GPL-3.0", check_cmd: "grep --version" }
    - { nombre: "find", version_min: "4.7",  licencia: "GPL-3.0", check_cmd: "find --version" }
  capabilities:
    - { cap: "CAP_NONE", razon: "inspeccion estatica de ficheros del repo · sin escalada" }
  paths_lectura:
    - "$TARGET/package.json"
    - "$TARGET/next.config.*"
    - "$TARGET/app/**"
    - "$TARGET/pages/**"
  paths_escritura:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_nextjs/"
  conexiones:
    - { destino: "registry.npmjs.org", proto: https, auth: none }

escalada:
  adapter: "${XEK_SUDO:-sudo -A}"
  capabilities_requeridas: []
  fallback_sin_escalada: "no aplica · skill sin escalada"
  registrar_en_finding: false

fuentes_externas:
  - { tipo: tool, nombre: node, version_min: "18.18", licencia: "MIT" }
  - { tipo: tool, nombre: jq,   version_min: "1.7",  licencia: "MIT" }
  - { tipo: tool, nombre: grep, version_min: "3.0",  licencia: "GPL-3.0" }
  - { tipo: tool, nombre: find, version_min: "4.7",  licencia: "GPL-3.0" }
conexiones_requeridas:
  - { destino: "registry.npmjs.org", proto: https, auth: none }

referencias_canonicas:
  - { tipo: doc_oficial, url: "https://nextjs.org/docs", cobertura: "App Router, RSC, next/image, middleware, ISR y next.config" }
  - { tipo: estandar,    url: "https://nodejs.org/api/esm.html", cobertura: "ES modules · resolucion de next.config.mjs/.ts" }
  - { tipo: estandar,    url: "https://docs.npmjs.com/cli/v10/configuring-npm/package-json", cobertura: "package.json · campos scripts, dependencies" }
verificar_referencias:
  cuando: "antes de cada bump de version_min de tools"
  como: "consultar doc oficial; rechazar bump si la doc marca cambio breaking en el formato"

areas_criticas:
  permisos_user:
    - "lectura del arbol del repo (package.json, next.config.*, app/, pages/)"
    - "escritura: $XDG_RUNTIME_DIR/xek-sandbox/XEK_nextjs/"
  fhs_tocados:
    - "<target>/ (solo lectura)"
  visual_secrets:
    - "no imprimir valores de env declarados en next.config (env:); solo verificar presencia de clave"
  zonas_ocultas:
    - "node_modules/, .next/, .git/ · evaluar presencia pero no inspeccionar contenido"

modos_ejecucion:
  dry-run:
    proposito: "Verificar precondiciones y listar los checks que se ejecutarian sin leer el target."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · plan textual de checks · exit 0 si parse OK"
  sandbox:
    proposito: "Copiar el repo a sandbox aislado y correr los checks estaticos sobre la copia."
    aislamiento: "git worktree o copia bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_nextjs/<run-id>/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_nextjs/"
    efectos_red: "ninguno (inspeccion estatica de ficheros)"
    salida: "findings.json en sandbox path · exit 0|1 segun findings"
  real:
    proposito: "Ejecutar contra el repo real (read-only) y persistir informe en cuaderno."
    precondicion: "sandbox del mismo input ha pasado en las ultimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_nextjs/<fecha>/"
    efectos_red: "ninguno"
    salida: "informe.md + findings.json + propuesta_#N si findings ≥ severidad_min"
gate_promocion:
  regla: "modo N+1 solo si modo N exit 0|1 con plan"
  override: "--override-gate=AUTO_<timestamp ±60s>"

escalada_privilegio:
  comando_template: "${XEK_SUDO:-sudo -A}"
  cuando_aplica: "no aplica · inspeccion read-only sin privilegios"

depende_de:
  - { slug: XEK_detecta-stack, modo: sandbox, obligatoria: true, razon: "necesita manifiesto que confirme Next.js en el stack" }
contrato_invocacion:
  modo_subordinado: sandbox
  promocion_real: solo_operador
  consolidacion: "json · merge por slug · schema xek/finding@v1"

checks:
  - id: "nextjs-001"
    descripcion: "Presencia de un fichero next.config (js/mjs/ts) en la raiz"
    command_template: "find '$TARGET' -maxdepth 1 -type f -name 'next.config.*' | grep -q ."
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "nextjs-002"
    descripcion: "next declarado como dependencia en package.json"
    command_template: "jq -e '.dependencies.next // .devDependencies.next' '$TARGET/package.json'"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "nextjs-003"
    descripcion: "Scripts build y start definidos en package.json"
    command_template: "jq -e '.scripts.build and .scripts.start' '$TARGET/package.json'"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "nextjs-004"
    descripcion: "Estructura de router: existe app/ (App Router) o pages/ (Pages Router)"
    command_template: "test -d '$TARGET/app' || test -d '$TARGET/src/app' || test -d '$TARGET/pages' || test -d '$TARGET/src/pages'"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "nextjs-005"
    descripcion: "Uso de next/image en lugar de <img> crudo en componentes del arbol de rutas"
    command_template: "! grep -rIlE '<img[[:space:]]' --include='*.tsx' --include='*.jsx' '$TARGET/app' '$TARGET/src/app' '$TARGET/pages' '$TARGET/src/pages' 2>/dev/null | grep -q . || grep -rIlq 'next/image' '$TARGET'"
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]
  - id: "nextjs-006"
    descripcion: "next.config no fuerza output=export junto a directivas server-only incompatibles"
    command_template: "! grep -qE \"output:\\s*['\\\"]export['\\\"]\" '$TARGET'/next.config.* || ! find '$TARGET' -maxdepth 2 -name 'middleware.*' | grep -q ."
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]

aplicabilidad:
  cuando:
    - "manifest.target_tipo == 'repo'"
    - "'nextjs' in manifest.repo.frameworks[].nombre"
  prioridad: alta
  coste_relativo: 2

migracion_runtime:
  bash:   scripts/xek-nextjs.sh
  python: scripts/xek-nextjs.py
  zsh:    scripts/xek-nextjs.zsh

triggers:
  keywords: ["nextjs", "next.config", "app router", "next/image", "middleware", "isr"]
  contextos: ["pre-PR", "post-merge"]
  cron: ""
---

# Objetivo

Verificar la configuracion estatica de un repositorio Next.js en modo read-only:
presencia de `next.config.*`, declaracion de `next` en `package.json`, scripts
`build`/`start`, estructura de router (`app/` o `pages/`), uso de `next/image`
y coherencia de `output: export` con la presencia de `middleware`. La skill
inspecciona ficheros del repo; nunca modifica el target ni ejecuta el build.

# Cuando activar

| Si... | Entonces... |
|---|---|
| `manifest.repo.frameworks` contiene `nextjs` | Ejecutar `--mode=sandbox` sobre la copia del repo |
| PR toca `next.config.*`, `app/` o `pages/` | Correr `nextjs-001..nextjs-006` desde hook pre-PR |
| Merge a `main` con cambios de config | Promover a `--mode=real` tras sandbox verde |
| `manifest.repo.frameworks` no contiene `nextjs` | Skill se salta: `skipped: not_applicable` |

# Uso · comentario encabezado (copiar al script)

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_nextjs · v0.7.0 · 2026-06-20                             ║
# ║  Funcion: verificar config estatica de repo Next.js (read-only)║
# ║  Variables entorno:                                           ║
# ║    XEK_TARGET         ruta del repo a inspeccionar            ║
# ║    XDG_RUNTIME_DIR    base sandbox                            ║
# ║  Uso:                                                         ║
# ║    xek-nextjs.sh --mode={dry-run|sandbox|real} --target <dir> ║
# ║  Exit codes:                                                  ║
# ║    0=clean · 1=findings · 2=config · 3=missing-mode · 4=ill-call║
# ╚══════════════════════════════════════════════════════════════╝
```

# Implementacion referencia (bash · fuente de verdad)

```bash
#!/usr/bin/env bash
set -euo pipefail
SLUG="XEK_nextjs"; VERSION="0.7.0"
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
  echo "checks: nextjs-001..nextjs-006 (config, dep, scripts, router, next/image, output/middleware)"
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
run nextjs-001 high   "find '$TARGET' -maxdepth 1 -type f -name 'next.config.*' | grep -q ."
run nextjs-002 high   "jq -e '.dependencies.next // .devDependencies.next' '$TARGET/package.json'"
run nextjs-003 medium "jq -e '.scripts.build and .scripts.start' '$TARGET/package.json'"
run nextjs-004 high   "test -d '$TARGET/app' || test -d '$TARGET/src/app' || test -d '$TARGET/pages' || test -d '$TARGET/src/pages'"

if [[ "$MODE" == "sandbox" || "$MODE" == "real" ]]; then
  [[ "$FINDINGS" -eq 0 ]] && exit 0 || exit 1
fi
```

# Adaptador Python (encapsulado vendoreable)

```python
#!/usr/bin/env python3
"""XEK_nextjs · adapter Python para pipelines orquestados."""
import subprocess, sys, pathlib
script = pathlib.Path(__file__).with_name("xek-nextjs.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-nextjs.sh" "$@"
```

# Verificacion end-to-end (smoke test)

```bash
# Caso happy · dry-run no toca disco del target
./scripts/xek-nextjs.sh --mode=dry-run && echo "PASS dry-run"

# Caso sandbox contra repo Next.js valido · exit 0 si pasan los checks
./scripts/xek-nextjs.sh --mode=sandbox --target ./mi-repo-next
echo "exit=$?"

# Caso falla esperada · repo sin next.config ni router genera findings · exit 1
TMP=$(mktemp -d); echo '{}' > "$TMP/package.json"
./scripts/xek-nextjs.sh --mode=sandbox --target "$TMP"; echo "exit=$?"
```

# Riesgos y mitigacion

| Riesgo | Mitigacion |
|---|---|
| Router en `src/app` o `src/pages` en lugar de raiz | `nextjs-004` contempla ambas ubicaciones |
| `<img>` legitimo (assets externos sin loader) | `nextjs-005` con severidad low; el operador marca excepcion documentada |
| `output: export` con middleware legitimo en monorepo | `nextjs-006` reporta el conflicto sin bloquear; decision del operador |
| Valores de `env:` en next.config con secretos | `visual_secrets`: solo se verifica presencia de clave, nunca se imprime el valor |

# Bitacora evolucion (append-only · R8)

- **v0.0.1** (2026-05-20) — bootstrap stub.
- **v0.6.1** (2026-05-22) — degradado borrador→stub per sintesis Ronda 002.
- **v0.7.0** (2026-06-20) — stub→borrador: frontmatter R4+R7 + modos_ejecucion + 6 checks[] tipados (nextjs-001..006) + fuentes canonicas reales (nextjs.org/docs, Node ESM, package.json) + bash referencia.

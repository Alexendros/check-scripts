---
slug: XEK_vite
ambito: Framework
maestria_funcional: revisor
estado: borrador
version: 0.7.0
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub · pendiente implementación" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "degradado borrador→stub per síntesis Ronda 002 (commit deuda v0.6)" }
  - { v: 0.7.0, fecha: 2026-06-20, cambio: "stub→borrador: frontmatter + modos + checks[] tipados + fuentes canónicas" }

objetivo: >
  Verificar config estatica de un repo Vite (vite.config, version, scripts build,
  prefijo de env publicas, sanidad de output) en read-only sin modificar el target.

precondiciones_runtime:
  binarios:
    - { nombre: "bash", version_min: "5.0",  licencia: "GPL-3.0", check_cmd: "bash --version" }
    - { nombre: "node", version_min: "18.0", licencia: "MIT",     check_cmd: "node --version" }
    - { nombre: "jq",   version_min: "1.7",  licencia: "MIT",     check_cmd: "jq --version" }
    - { nombre: "grep", version_min: "3.0",  licencia: "GPL-3.0", check_cmd: "grep --version" }
    - { nombre: "find", version_min: "4.7",  licencia: "GPL-3.0", check_cmd: "find --version" }
  capabilities:
    - { cap: "CAP_NONE", razon: "inspeccion estatica de ficheros del repo · sin escalada" }
  paths_lectura:
    - "$TARGET/package.json"
    - "$TARGET/vite.config.*"
    - "$TARGET/src/**"
  paths_escritura:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_vite/"
  conexiones:
    - { destino: "registry.npmjs.org", proto: https, auth: none }

escalada:
  adapter: "${XEK_SUDO:-sudo -A}"
  capabilities_requeridas: []
  fallback_sin_escalada: "no aplica · skill sin escalada"
  registrar_en_finding: false

fuentes_externas:
  - { tipo: tool, nombre: node, version_min: "18.0", licencia: "MIT" }
  - { tipo: tool, nombre: jq,   version_min: "1.7",  licencia: "MIT" }
  - { tipo: tool, nombre: grep, version_min: "3.0",  licencia: "GPL-3.0" }
  - { tipo: tool, nombre: find, version_min: "4.7",  licencia: "GPL-3.0" }
conexiones_requeridas:
  - { destino: "registry.npmjs.org", proto: https, auth: none }

referencias_canonicas:
  - { tipo: doc_oficial, url: "https://vite.dev/guide/", cobertura: "Uso de Vite: scripts dev/build/preview, env y prefijo VITE_" }
  - { tipo: doc_oficial, url: "https://vite.dev/config/", cobertura: "Opciones de vite.config: build, rollupOptions, envPrefix, base" }
  - { tipo: estandar,    url: "https://nodejs.org/api/esm.html", cobertura: "ES modules · resolucion de vite.config.ts/.mjs" }
  - { tipo: estandar,    url: "https://docs.npmjs.com/cli/v10/configuring-npm/package-json", cobertura: "package.json · campos scripts, dependencies, type" }
verificar_referencias:
  cuando: "antes de cada bump de version_min de tools"
  como: "consultar doc oficial; rechazar bump si la doc marca cambio breaking en el formato"

areas_criticas:
  permisos_user:
    - "lectura del arbol del repo (package.json, vite.config.*, src/)"
    - "escritura: $XDG_RUNTIME_DIR/xek-sandbox/XEK_vite/"
  fhs_tocados:
    - "<target>/ (solo lectura)"
  visual_secrets:
    - "no imprimir valores de variables import.meta.env; solo verificar uso del prefijo publico VITE_"
  zonas_ocultas:
    - "node_modules/, dist/, .vite/, .git/ · evaluar presencia pero no inspeccionar contenido"

modos_ejecucion:
  dry-run:
    proposito: "Verificar precondiciones y listar los checks que se ejecutarian sin leer el target."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · plan textual de checks · exit 0 si parse OK"
  sandbox:
    proposito: "Copiar el repo a sandbox aislado y correr los checks estaticos sobre la copia."
    aislamiento: "git worktree o copia bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_vite/<run-id>/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_vite/"
    efectos_red: "ninguno (inspeccion estatica de ficheros)"
    salida: "findings.json en sandbox path · exit 0|1 segun findings"
  real:
    proposito: "Ejecutar contra el repo real (read-only) y persistir informe en cuaderno."
    precondicion: "sandbox del mismo input ha pasado en las ultimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_vite/<fecha>/"
    efectos_red: "ninguno"
    salida: "informe.md + findings.json + propuesta_#N si findings ≥ severidad_min"
gate_promocion:
  regla: "modo N+1 solo si modo N exit 0|1 con plan"
  override: "--override-gate=AUTO_<timestamp ±60s>"

escalada_privilegio:
  comando_template: "${XEK_SUDO:-sudo -A}"
  cuando_aplica: "no aplica · inspeccion read-only sin privilegios"

depende_de:
  - { slug: XEK_detecta-stack, modo: sandbox, obligatoria: true, razon: "necesita manifiesto que confirme Vite como bundler" }
contrato_invocacion:
  modo_subordinado: sandbox
  promocion_real: solo_operador
  consolidacion: "json · merge por slug · schema xek/finding@v1"

checks:
  - id: "vite-001"
    descripcion: "Presencia de un fichero vite.config (js/ts/mjs/cjs/mts) en la raiz"
    command_template: "find '$TARGET' -maxdepth 1 -type f -name 'vite.config.*' | grep -q ."
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "vite-002"
    descripcion: "vite declarado como dependencia en package.json"
    command_template: "jq -e '.devDependencies.vite // .dependencies.vite' '$TARGET/package.json'"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "vite-003"
    descripcion: "Scripts build y preview definidos en package.json"
    command_template: "jq -e '.scripts.build and .scripts.preview' '$TARGET/package.json'"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "vite-004"
    descripcion: "Las env expuestas al cliente usan el prefijo publico VITE_ (no exponen claves privadas)"
    command_template: "! grep -rIoE 'import\\.meta\\.env\\.[A-Z_]+' --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' '$TARGET/src' 2>/dev/null | grep -vE 'import\\.meta\\.env\\.(VITE_|MODE|BASE_URL|PROD|DEV|SSR)' | grep -q ."
    expected_exit: 1
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "vite-005"
    descripcion: "package.json declara type=module (resolucion ESM esperada por vite.config)"
    command_template: "jq -e '.type == \"module\"' '$TARGET/package.json'"
    expected_exit: 0
    severity_default: low
    solo_modo: [dry-run, sandbox, real]
  - id: "vite-006"
    descripcion: "Existe un punto de entrada index.html en la raiz o estructura SPA esperada"
    command_template: "test -f '$TARGET/index.html' || grep -qE 'rollupOptions|build\\s*:' '$TARGET'/vite.config.*"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]

aplicabilidad:
  cuando:
    - "manifest.target_tipo == 'repo'"
    - "manifest.tooling.bundler == 'vite'"
  prioridad: media
  coste_relativo: 2

migracion_runtime:
  bash:   scripts/xek-vite.sh
  python: scripts/xek-vite.py
  zsh:    scripts/xek-vite.zsh

triggers:
  keywords: ["vite", "vite.config", "rollup", "envprefix", "build", "import.meta.env"]
  contextos: ["pre-PR", "post-merge"]
  cron: ""
---

# Objetivo

Verificar la configuracion estatica de un repositorio Vite en modo read-only:
presencia de `vite.config.*`, declaracion de `vite` en `package.json`, scripts
`build`/`preview`, uso correcto del prefijo publico `VITE_` para variables de
entorno expuestas al cliente, resolucion ESM y existencia de un punto de entrada.
La skill inspecciona ficheros del repo; nunca modifica el target ni ejecuta el
build.

# Cuando activar

| Si... | Entonces... |
|---|---|
| `manifest.tooling.bundler == 'vite'` | Ejecutar `--mode=sandbox` sobre la copia del repo |
| PR toca `vite.config.*` o uso de `import.meta.env` | Correr `vite-001..vite-006` desde hook pre-PR |
| Merge a `main` con cambios de config | Promover a `--mode=real` tras sandbox verde |
| El bundler del manifiesto no es `vite` | Skill se salta: `skipped: not_applicable` |

# Uso · comentario encabezado (copiar al script)

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_vite · v0.7.0 · 2026-06-20                               ║
# ║  Funcion: verificar config estatica de repo Vite (read-only)  ║
# ║  Variables entorno:                                           ║
# ║    XEK_TARGET         ruta del repo a inspeccionar            ║
# ║    XDG_RUNTIME_DIR    base sandbox                            ║
# ║  Uso:                                                         ║
# ║    xek-vite.sh --mode={dry-run|sandbox|real} --target <dir>   ║
# ║  Exit codes:                                                  ║
# ║    0=clean · 1=findings · 2=config · 3=missing-mode · 4=ill-call║
# ╚══════════════════════════════════════════════════════════════╝
```

# Implementacion referencia (bash · fuente de verdad)

```bash
#!/usr/bin/env bash
set -euo pipefail
SLUG="XEK_vite"; VERSION="0.7.0"
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
  echo "checks: vite-001..vite-006 (config, dep, scripts, env VITE_, esm, entry)"
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
run vite-001 high   "find '$TARGET' -maxdepth 1 -type f -name 'vite.config.*' | grep -q ."
run vite-002 high   "jq -e '.devDependencies.vite // .dependencies.vite' '$TARGET/package.json'"
run vite-003 medium "jq -e '.scripts.build and .scripts.preview' '$TARGET/package.json'"
# vite-004: PASA si NO hay env sin prefijo publico (grep no encuentra nada -> exit 1 -> ok invertido)
run vite-004 high   "! grep -rIoE 'import\\.meta\\.env\\.[A-Z_]+' --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' '$TARGET/src' 2>/dev/null | grep -vE 'import\\.meta\\.env\\.(VITE_|MODE|BASE_URL|PROD|DEV|SSR)' | grep -q ."

if [[ "$MODE" == "sandbox" || "$MODE" == "real" ]]; then
  [[ "$FINDINGS" -eq 0 ]] && exit 0 || exit 1
fi
```

# Adaptador Python (encapsulado vendoreable)

```python
#!/usr/bin/env python3
"""XEK_vite · adapter Python para pipelines orquestados."""
import subprocess, sys, pathlib
script = pathlib.Path(__file__).with_name("xek-vite.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-vite.sh" "$@"
```

# Verificacion end-to-end (smoke test)

```bash
# Caso happy · dry-run no toca disco del target
./scripts/xek-vite.sh --mode=dry-run && echo "PASS dry-run"

# Caso sandbox contra repo Vite valido · exit 0 si pasan los checks
./scripts/xek-vite.sh --mode=sandbox --target ./mi-repo-vite
echo "exit=$?"

# Caso falla esperada · repo sin vite.config genera findings · exit 1
TMP=$(mktemp -d); echo '{}' > "$TMP/package.json"
./scripts/xek-vite.sh --mode=sandbox --target "$TMP"; echo "exit=$?"
```

# Riesgos y mitigacion

| Riesgo | Mitigacion |
|---|---|
| `envPrefix` personalizado distinto de `VITE_` | `vite-004` documenta el caso; el operador ajusta el patron en config local |
| Variables built-in (`MODE`, `PROD`, `DEV`) tratadas como fugas | `vite-004` excluye el set built-in declarado por la doc oficial |
| Build con `lib` mode sin `index.html` | `vite-006` acepta `rollupOptions`/`build` como entry alternativo |
| Valores de env con secretos visibles en grep | `visual_secrets`: solo se verifica el prefijo de la clave, nunca se imprime el valor |

# Bitacora evolucion (append-only · R8)

- **v0.0.1** (2026-05-20) — bootstrap stub.
- **v0.6.1** (2026-05-22) — degradado borrador→stub per sintesis Ronda 002.
- **v0.7.0** (2026-06-20) — stub→borrador: frontmatter R4+R7 + modos_ejecucion + 6 checks[] tipados (vite-001..006) + fuentes canonicas reales (vite.dev/guide, vite.dev/config, Node ESM, package.json) + bash referencia.

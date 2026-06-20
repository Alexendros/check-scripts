---
slug: XEK_turbopack
ambito: Framework
maestria_funcional: revisor
estado: borrador
version: 0.7.0
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub · pendiente implementación" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "degradado borrador→stub per síntesis Ronda 002 (commit deuda v0.6)" }
  - { v: 0.6.2, fecha: 2026-06-06, cambio: "acotada aplicabilidad: de target_tipo==repo genérico a bundler==turbopack OR Next.js>=15. Opciones evaluadas: A=independiente acotado (elegida) · B=fusión en XEK_nextjs · C=fusión en bundler genérico" }
  - { v: 0.7.0, fecha: 2026-06-20, cambio: "stub→borrador: frontmatter + modos + checks[] tipados + fuentes canónicas" }

objetivo: >
  Verificar config estatica de Turbopack en un repo Next.js (flag dev/build, bloque
  config, version Next>=15, modulos no soportados) en read-only sin modificar el target.

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
  paths_escritura:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_turbopack/"
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
  - { tipo: doc_oficial, url: "https://nextjs.org/docs/app/api-reference/turbopack", cobertura: "Config de Turbopack en next.config, flags --turbopack y opciones soportadas" }
  - { tipo: doc_oficial, url: "https://turbo.build/pack", cobertura: "Arquitectura de Turbopack, cache incremental y modulos/loaders soportados" }
  - { tipo: estandar,    url: "https://docs.npmjs.com/cli/v10/configuring-npm/package-json", cobertura: "package.json · campos scripts y dependencies (next)" }
verificar_referencias:
  cuando: "antes de cada bump de version_min de tools"
  como: "consultar doc oficial; rechazar bump si la doc marca cambio breaking en el formato"

areas_criticas:
  permisos_user:
    - "lectura del arbol del repo (package.json, next.config.*)"
    - "escritura: $XDG_RUNTIME_DIR/xek-sandbox/XEK_turbopack/"
  fhs_tocados:
    - "<target>/ (solo lectura)"
  visual_secrets: []
  zonas_ocultas:
    - "node_modules/, .next/, .turbo/, .git/ · evaluar presencia pero no inspeccionar contenido"

modos_ejecucion:
  dry-run:
    proposito: "Verificar precondiciones y listar los checks que se ejecutarian sin leer el target."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · plan textual de checks · exit 0 si parse OK"
  sandbox:
    proposito: "Copiar el repo a sandbox aislado y correr los checks estaticos sobre la copia."
    aislamiento: "git worktree o copia bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_turbopack/<run-id>/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_turbopack/"
    efectos_red: "ninguno (inspeccion estatica de ficheros)"
    salida: "findings.json en sandbox path · exit 0|1 segun findings"
  real:
    proposito: "Ejecutar contra el repo real (read-only) y persistir informe en cuaderno."
    precondicion: "sandbox del mismo input ha pasado en las ultimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_turbopack/<fecha>/"
    efectos_red: "ninguno"
    salida: "informe.md + findings.json + propuesta_#N si findings ≥ severidad_min"
gate_promocion:
  regla: "modo N+1 solo si modo N exit 0|1 con plan"
  override: "--override-gate=AUTO_<timestamp ±60s>"

escalada_privilegio:
  comando_template: "${XEK_SUDO:-sudo -A}"
  cuando_aplica: "no aplica · inspeccion read-only sin privilegios"

depende_de:
  - { slug: XEK_detecta-stack, modo: sandbox, obligatoria: true, razon: "necesita manifiesto que confirme Turbopack o Next.js>=15" }
contrato_invocacion:
  modo_subordinado: sandbox
  promocion_real: solo_operador
  consolidacion: "json · merge por slug · schema xek/finding@v1"

checks:
  - id: "turbopack-001"
    descripcion: "next declarado como dependencia (Turbopack vive dentro de Next.js)"
    command_template: "jq -e '.dependencies.next // .devDependencies.next' '$TARGET/package.json'"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "turbopack-002"
    descripcion: "Algun script usa el flag --turbopack (dev o build) o el bloque turbopack en next.config"
    command_template: "jq -e '[.scripts // {} | to_entries[].value] | any(test(\"--turbopack\"))' '$TARGET/package.json' || grep -qE 'turbopack\\s*:' '$TARGET'/next.config.*"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "turbopack-003"
    descripcion: "next.config presente cuando se declara configuracion de turbopack"
    command_template: "! grep -qE 'turbopack\\s*:' '$TARGET'/next.config.* 2>/dev/null || find '$TARGET' -maxdepth 1 -name 'next.config.*' | grep -q ."
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "turbopack-004"
    descripcion: "No coexiste config de webpack custom con turbopack en next.config (incompatibilidad)"
    command_template: "! grep -qE 'turbopack\\s*:' '$TARGET'/next.config.* 2>/dev/null || ! grep -qE 'webpack\\s*\\(' '$TARGET'/next.config.* 2>/dev/null"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "turbopack-005"
    descripcion: "Si usa loaders en turbopack.rules, declara extensiones (sanidad de modulos)"
    command_template: "! grep -qE 'rules\\s*:' '$TARGET'/next.config.* 2>/dev/null || grep -qE \"['\\\"]\\*\\.[a-z]+['\\\"]\" '$TARGET'/next.config.*"
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]

aplicabilidad:
  cuando:
    - "manifest.target_tipo == 'repo'"
    - "manifest.tooling.bundler == 'turbopack' || manifest.frameworks.nombre includes 'nextjs' (version_min >= 15)"
  prioridad: media
  coste_relativo: 2

migracion_runtime:
  bash:   scripts/xek-turbopack.sh
  python: scripts/xek-turbopack.py
  zsh:    scripts/xek-turbopack.zsh

triggers:
  keywords: ["turbopack", "next.config", "bundler", "--turbopack", "turbopack rules", "incremental cache"]
  contextos: ["pre-PR", "post-merge"]
  cron: ""
---

# Objetivo

Verificar la configuracion estatica de Turbopack dentro de un repositorio
Next.js en modo read-only: presencia de `next` como dependencia, uso del flag
`--turbopack` o del bloque `turbopack` en `next.config.*`, ausencia de config
`webpack` custom incompatible y sanidad de los loaders declarados en
`turbopack.rules`. La skill inspecciona ficheros del repo; nunca modifica el
target ni ejecuta el build.

# Scope · aplicabilidad acotada

Turbopack es el bundler por defecto de Next.js >= 15; ya no se configura como bundler
independiente en la mayoria de proyectos. Para evitar solape con `XEK_nextjs` y `XEK_vite`,
esta skill **solo aplica** cuando el manifiesto declara `tooling.bundler == 'turbopack'` o un
framework Next.js >= 15. No es un check generico de repo.

Opciones evaluadas (sintesis del mantenedor, 2026-06-06):
- **A · independiente acotado (elegida)** — mantener la skill, restringir `aplicabilidad.cuando`.
  No destructiva; preserva el caso Turbopack standalone real.
- **B · fusion en `XEK_nextjs`** — descartada: pierde granularidad y reutilizacion fuera de Next.
- **C · fusion en bundler generico con `XEK_vite`** — descartada: Turbopack no es Vite; el solape
  es de proposito, no de implementacion.

# Cuando activar

| Si... | Entonces... |
|---|---|
| `manifest.tooling.bundler == 'turbopack'` | Ejecutar `--mode=sandbox` sobre la copia del repo |
| Next.js >= 15 con flag `--turbopack` en scripts | Correr `turbopack-001..turbopack-005` desde hook pre-PR |
| Merge a `main` con cambios en `next.config` turbopack | Promover a `--mode=real` tras sandbox verde |
| Ni `turbopack` ni Next.js >= 15 en el manifiesto | Skill se salta: `skipped: not_applicable` |

# Uso · comentario encabezado (copiar al script)

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_turbopack · v0.7.0 · 2026-06-20                          ║
# ║  Funcion: verificar config estatica de Turbopack (read-only)  ║
# ║  Variables entorno:                                           ║
# ║    XEK_TARGET         ruta del repo a inspeccionar            ║
# ║    XDG_RUNTIME_DIR    base sandbox                            ║
# ║  Uso:                                                         ║
# ║    xek-turbopack.sh --mode={dry-run|sandbox|real} --target <d>║
# ║  Exit codes:                                                  ║
# ║    0=clean · 1=findings · 2=config · 3=missing-mode · 4=ill-call║
# ╚══════════════════════════════════════════════════════════════╝
```

# Implementacion referencia (bash · fuente de verdad)

```bash
#!/usr/bin/env bash
set -euo pipefail
SLUG="XEK_turbopack"; VERSION="0.7.0"
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
  echo "checks: turbopack-001..turbopack-005 (next dep, flag/config, next.config, webpack conflict, rules)"
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
run turbopack-001 high   "jq -e '.dependencies.next // .devDependencies.next' '$TARGET/package.json'"
run turbopack-002 high   "jq -e '[.scripts // {} | to_entries[].value] | any(test(\"--turbopack\"))' '$TARGET/package.json' || grep -qE 'turbopack\\s*:' '$TARGET'/next.config.*"
run turbopack-004 medium "! grep -qE 'turbopack\\s*:' '$TARGET'/next.config.* 2>/dev/null || ! grep -qE 'webpack\\s*\\(' '$TARGET'/next.config.* 2>/dev/null"

if [[ "$MODE" == "sandbox" || "$MODE" == "real" ]]; then
  [[ "$FINDINGS" -eq 0 ]] && exit 0 || exit 1
fi
```

# Adaptador Python (encapsulado vendoreable)

```python
#!/usr/bin/env python3
"""XEK_turbopack · adapter Python para pipelines orquestados."""
import subprocess, sys, pathlib
script = pathlib.Path(__file__).with_name("xek-turbopack.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-turbopack.sh" "$@"
```

# Verificacion end-to-end (smoke test)

```bash
# Caso happy · dry-run no toca disco del target
./scripts/xek-turbopack.sh --mode=dry-run && echo "PASS dry-run"

# Caso sandbox contra repo Next.js con turbopack · exit 0 si pasan los checks
./scripts/xek-turbopack.sh --mode=sandbox --target ./mi-repo-next
echo "exit=$?"

# Caso falla esperada · repo sin next ni flag turbopack genera findings · exit 1
TMP=$(mktemp -d); echo '{}' > "$TMP/package.json"
./scripts/xek-turbopack.sh --mode=sandbox --target "$TMP"; echo "exit=$?"
```

# Riesgos y mitigacion

| Riesgo | Mitigacion |
|---|---|
| Turbopack por defecto en Next.js >= 15 sin flag explicito | `turbopack-002` acepta tambien el bloque `turbopack:` en next.config como evidencia |
| Config webpack legitima en proyecto en migracion | `turbopack-004` reporta el conflicto sin bloquear; decision del operador |
| `turbopack.rules` con loaders sin glob de extension | `turbopack-005` con severidad low; documenta el formato esperado por la doc oficial |
| Solape de scope con `XEK_nextjs` | `aplicabilidad.cuando` restringe a bundler turbopack o Next.js >= 15 |

# Bitacora evolucion (append-only · R8)

- **v0.0.1** (2026-05-20) — bootstrap stub.
- **v0.6.1** (2026-05-22) — degradado borrador→stub per sintesis Ronda 002.
- **v0.6.2** (2026-06-06) — acotada aplicabilidad a bundler turbopack o Next.js >= 15 (opcion A).
- **v0.7.0** (2026-06-20) — stub→borrador: frontmatter R4+R7 + modos_ejecucion + 5 checks[] tipados (turbopack-001..005) + fuentes canonicas reales (nextjs.org/turbopack, turbo.build/pack, package.json) + bash referencia.

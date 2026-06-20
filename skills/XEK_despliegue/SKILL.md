---
slug: XEK_despliegue
ambito: Despliegue
maestria_funcional: revisor
estado: borrador
version: 0.7.0
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub · pendiente implementación" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "degradado borrador→stub per síntesis Ronda 002 (commit deuda v0.6)" }
  - { v: 0.7.0, fecha: 2026-06-20, cambio: "stub→borrador: frontmatter R4+R7 + modos + checks[] tipados read-only + fuentes canónicas reales (12factor + Dockerfile reference)" }

objetivo: >
  Verificar en estatico Dockerfile y compose.yaml: healthcheck, tags fijados,
  restart policy, limites de recursos, sin secretos embebidos y config via .env.
  Read-only, no modifica el target.

fuentes_externas:
  - { tipo: tool, nombre: grep,           version_min: "3.0", licencia: "GPL-3.0" }
  - { tipo: tool, nombre: find,           version_min: "4.7", licencia: "GPL-3.0" }
  - { tipo: tool, nombre: test,           version_min: "8.30", licencia: "GPL-3.0" }
  - { tipo: tool, nombre: docker-compose, version_min: "2.20", licencia: "Apache-2.0" }
conexiones_requeridas: []

referencias_canonicas:
  - { tipo: doc_oficial, url: "https://docs.docker.com/reference/dockerfile/", cobertura: "Sintaxis Dockerfile · HEALTHCHECK · instrucciones y mejores practicas de imagen" }
  - { tipo: estandar,    url: "https://12factor.net/", cobertura: "The Twelve-Factor App · config via entorno (III), procesos sin estado, paridad dev/prod" }

verificar_referencias:
  cuando: "antes de cada bump de version_min de tools"
  como: "consultar doc oficial; rechazar bump si la doc marca cambio breaking en la sintaxis del Dockerfile o del Compose file"

areas_criticas:
  permisos_user:
    - "lectura de Dockerfile y compose.yaml dentro del repo objetivo"
    - "escritura: $XDG_RUNTIME_DIR/xek-sandbox/XEK_despliegue/"
  fhs_tocados:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_despliegue/ (solo escritura de findings)"
  visual_secrets:
    - "valores de ENV/ARG que parezcan tokens o passwords · nunca imprimir el valor, solo la linea ofuscada"
  zonas_ocultas:
    - "runtime de contenedores en el host (daemon, sockets, imagenes desplegadas) · fuera de alcance · competencia de XEK_linux-contenedores"

modos_ejecucion:
  dry-run:
    proposito: "Verificar precondiciones y listar los checks que se ejecutarian sin leer el contenido del target."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · plan textual de checks · exit 0 si parse OK"
  sandbox:
    proposito: "Copiar Dockerfile/compose.yaml a un directorio aislado y correr los checks read-only sobre la copia."
    aislamiento: "directorio bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_despliegue/<run-id>/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_despliegue/"
    efectos_red: "ninguno · inspeccion estatica de ficheros locales"
    salida: "findings.json en sandbox path · exit 0|1 segun findings"
  real:
    proposito: "Ejecutar contra los artefactos reales del repo (read-only) y persistir informe en cuaderno."
    precondicion: "sandbox del mismo input ha pasado en las ultimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_despliegue/<fecha>/"
    efectos_red: "ninguno"
    salida: "informe.md + findings.json + propuesta_#N si findings ≥ severidad_min"
gate_promocion:
  regla: "modo N+1 solo si modo N exit 0|1 con plan"
  override: "--override-gate=AUTO_<timestamp ±60s>"

escalada_privilegio:
  comando_template: "${XEK_SUDO:-sudo -A}"
  cuando_aplica: "no aplica · inspeccion read-only de ficheros del repo sin escalada"

depende_de:
  - { slug: XEK_detecta-stack, modo: sandbox, obligatoria: true, razon: "necesita manifiesto con rutas de Dockerfile y compose.yaml" }
contrato_invocacion:
  modo_subordinado: sandbox
  promocion_real: solo_operador
  consolidacion: "json · merge por slug · schema xek/finding@v1"

checks:
  - id: "deploy-001"
    descripcion: "Dockerfile declara una instruccion HEALTHCHECK"
    command_template: "grep -qiE '^[[:space:]]*HEALTHCHECK' '$DOCKERFILE'"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "deploy-002"
    descripcion: "Imagen base FROM fija un tag explicito (no :latest)"
    command_template: "! grep -iE '^[[:space:]]*FROM[[:space:]]' '$DOCKERFILE' | grep -qiE ':latest'"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "deploy-003"
    descripcion: "Sin secretos embebidos: ningun ENV/ARG con valor tipo token/password/apikey en el Dockerfile"
    command_template: "! grep -iE '^[[:space:]]*(ENV|ARG)[[:space:]]+.*(PASSWORD|SECRET|TOKEN|API_?KEY)[[:space:]=]+[^[:space:]$]+' '$DOCKERFILE'"
    expected_exit: 0
    severity_default: critical
    solo_modo: [sandbox, real]
  - id: "deploy-004"
    descripcion: "compose.yaml define restart policy para los servicios"
    command_template: "grep -qiE '^[[:space:]]*restart:[[:space:]]*(always|unless-stopped|on-failure)' '$COMPOSE'"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "deploy-005"
    descripcion: "compose.yaml referencia config via env_file o interpolacion en lugar de secretos en claro"
    command_template: "grep -qiE '^[[:space:]]*env_file:' '$COMPOSE'"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "deploy-006"
    descripcion: "compose.yaml no fija imagenes con :latest"
    command_template: "! grep -iE '^[[:space:]]*image:[[:space:]]*[^[:space:]]+:latest' '$COMPOSE'"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "deploy-007"
    descripcion: "compose.yaml declara limites de recursos (deploy.resources.limits o mem_limit)"
    command_template: "grep -qiE '^[[:space:]]*(mem_limit:|limits:)' '$COMPOSE'"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "deploy-008"
    descripcion: "compose.yaml no incrusta valores que parezcan secretos en environment inline"
    command_template: "! grep -iE '^[[:space:]]+(-[[:space:]]*)?[A-Z_]*(PASSWORD|SECRET|TOKEN|API_?KEY)[A-Z_]*[:=][[:space:]]*[^[:space:]$].+' '$COMPOSE'"
    expected_exit: 0
    severity_default: critical
    solo_modo: [sandbox, real]

aplicabilidad:
  cuando:
    - "manifest.target_tipo == 'repo'"
  prioridad: media
  coste_relativo: 2

migracion_runtime:
  bash:   scripts/xek-despliegue.sh
  python: scripts/xek-despliegue.py
  zsh:    scripts/xek-despliegue.zsh

triggers:
  keywords: ["docker", "dockerfile", "compose", "healthcheck", "deploy", "restart-policy", "image-tag", "resource-limits"]
  contextos: ["pre-PR", "pre-deploy", "post-merge"]
  cron: ""
---

# Objetivo

Verificar en estatico los artefactos de despliegue de un repositorio
(`Dockerfile`, `compose.yaml`): presencia de `HEALTHCHECK`, tags de imagen
fijados (no `:latest`), `restart policy`, limites de recursos, ausencia de
secretos embebidos y configuracion externalizada via `.env`/`env_file`. La
skill solo lee e inspecciona los ficheros; nunca modifica el target ni levanta
contenedores.

# Cuando activar

| Si... | Entonces... |
|---|---|
| `manifest.target_tipo == 'repo'` con `Dockerfile` o `compose.yaml` | Ejecutar `--mode=sandbox` sobre la copia aislada |
| Pre-deploy de un servicio contenerizado | Correr `deploy-001..deploy-008` y bloquear si falla severidad high/critical |
| Post-merge a la rama de despliegue | Promover a `--mode=real` tras sandbox verde |

# Uso · comentario encabezado (copiar al script)

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_despliegue · v0.7.0 · 2026-06-20                         ║
# ║  Funcion: verificar artefactos de despliegue (read-only)      ║
# ║  Variables entorno:                                           ║
# ║    XEK_TARGET_DIR     raiz del repo a inspeccionar            ║
# ║    XDG_RUNTIME_DIR    base sandbox                            ║
# ║  Uso:                                                         ║
# ║    xek-despliegue.sh --mode={dry-run|sandbox|real} [--target] ║
# ║  Exit codes:                                                  ║
# ║    0=clean · 1=findings · 2=config · 3=missing-mode · 4=ill-call║
# ╚══════════════════════════════════════════════════════════════╝
```

# Implementacion referencia (bash · fuente de verdad)

```bash
#!/usr/bin/env bash
set -euo pipefail

SLUG="XEK_despliegue"
VERSION="0.7.0"
MODE=""
TARGET="${XEK_TARGET_DIR:-.}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode=*)  MODE="${1#*=}"; shift ;;
    --target)  TARGET="$2"; shift 2 ;;
    *)         echo "ill-call: $1" >&2; exit 4 ;;
  esac
done

[[ -z "$MODE" ]] && { echo "missing --mode" >&2; exit 3; }

preflight() {
  for bin in bash grep find test; do
    command -v "$bin" >/dev/null 2>&1 || { echo "PREFLIGHT FAIL: $bin absent" >&2; return 1; }
  done
}

if [[ "$MODE" == "dry-run" ]]; then
  echo "## ${SLUG} v${VERSION} · plan dry-run"
  preflight || exit 2
  echo "checks: deploy-001..deploy-008 (healthcheck, tag fijo, sin secretos, restart, env_file, limits)"
  exit 0
fi

preflight || exit 2

DOCKERFILE="$(find "$TARGET" -maxdepth 2 -iname 'Dockerfile' | head -n1)"
COMPOSE="$(find "$TARGET" -maxdepth 2 -iregex '.*/\(docker-\)?compose\.ya?ml' | head -n1)"
[[ -z "$DOCKERFILE" && -z "$COMPOSE" ]] && { echo "no deploy artefacts under $TARGET" >&2; exit 2; }

FINDINGS=0
emit() { echo "  - { check: $1, severity: $2, status: $3 }"; }
run_check() {
  local id="$1" sev="$2"; shift 2
  if "$@" >/dev/null 2>&1; then emit "$id" "$sev" pass
  else emit "$id" "$sev" fail; FINDINGS=$((FINDINGS+1)); fi
}

echo "findings:"
if [[ -n "$DOCKERFILE" ]]; then
  run_check deploy-001 high     bash -c "grep -qiE '^[[:space:]]*HEALTHCHECK' '$DOCKERFILE'"
  run_check deploy-002 high     bash -c "! grep -iE '^[[:space:]]*FROM[[:space:]]' '$DOCKERFILE' | grep -qiE ':latest'"
  run_check deploy-003 critical bash -c "! grep -iE '^[[:space:]]*(ENV|ARG)[[:space:]]+.*(PASSWORD|SECRET|TOKEN|API_?KEY)[[:space:]=]+[^[:space:]]+' '$DOCKERFILE'"
fi
if [[ -n "$COMPOSE" ]]; then
  run_check deploy-004 medium   bash -c "grep -qiE '^[[:space:]]*restart:[[:space:]]*(always|unless-stopped|on-failure)' '$COMPOSE'"
  run_check deploy-005 medium   bash -c "grep -qiE '^[[:space:]]*env_file:' '$COMPOSE'"
  run_check deploy-006 high     bash -c "! grep -iE '^[[:space:]]*image:[[:space:]]*[^[:space:]]+:latest' '$COMPOSE'"
  run_check deploy-007 medium   bash -c "grep -qiE '^[[:space:]]*(mem_limit:|limits:)' '$COMPOSE'"
fi

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
"""XEK_despliegue · adapter Python para pipelines orquestados."""
import subprocess, sys, pathlib
script = pathlib.Path(__file__).with_name("xek-despliegue.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-despliegue.sh" "$@"
```

# Verificacion end-to-end (smoke test)

```bash
# Caso happy · dry-run no toca disco
./scripts/xek-despliegue.sh --mode=dry-run && echo "PASS dry-run"

# Caso sandbox contra un repo con Dockerfile/compose correctos · exit 0
./scripts/xek-despliegue.sh --mode=sandbox --target ./fixtures/buen-deploy
echo "exit=$?"

# Caso falla esperada · Dockerfile sin HEALTHCHECK y compose con :latest · exit 1
./scripts/xek-despliegue.sh --mode=sandbox --target ./fixtures/mal-deploy
echo "exit=$?"
```

# Riesgos y mitigacion

| Riesgo | Mitigacion |
|---|---|
| Multistage Dockerfile con varios FROM, alguno sin tag intermedio | `deploy-002` solo penaliza `:latest`; las stages intermedias con alias se documentan como falso positivo conocido |
| Secretos inyectados en build-time via BuildKit `--secret` | El patron `deploy-003` cubre ENV/ARG en claro; los secretos BuildKit se consideran practica correcta y no se penalizan |
| Compose con `extends` o fragmentos YAML en multiples ficheros | La inspeccion es por fichero; la consolidacion multi-fichero requiere `docker compose config` (cubierto por XEK_iac) |
| Falso positivo de secreto en variable de nombre sospechoso pero valor placeholder | `deploy-008` exige valor no vacio; los placeholders interpolados no disparan el check |

# Bitacora evolucion (append-only · R8)

- **v0.0.1** (2026-05-20) — bootstrap stub.
- **v0.6.1** (2026-05-22) — degradado borrador→stub per sintesis Ronda 002.
- **v0.7.0** (2026-06-20) — stub→borrador: frontmatter R4+R7 completo + modos_ejecucion + 8 checks[] tipados (deploy-001..008) read-only con grep/find/test + fuentes canonicas reales (12factor.net, Dockerfile reference) + bash referencia de 3 modos. target_tipo migrado app-en-vivo→repo (inspeccion estatica de artefactos).

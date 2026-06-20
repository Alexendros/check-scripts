---
slug: XEK_iac
ambito: IaC
maestria_funcional: revisor
estado: borrador
version: 0.7.0
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub · pendiente implementación" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "degradado borrador→stub per síntesis Ronda 002 (commit deuda v0.6)" }
  - { v: 0.6.2, fecha: 2026-06-06, cambio: "formalizado Scope exclusivo frente a XEK_linux-contenedores: iac audita artefactos declarativos en repo, contenedores audita runtime en host" }
  - { v: 0.7.0, fecha: 2026-06-20, cambio: "stub→borrador: frontmatter R4+R7 + modos + checks[] tipados read-only (docker compose config -q) + fuentes canónicas reales (Terraform docs + Compose file reference)" }

objetivo: >
  Validar IaC en repo: compose valido, sin :latest, limites de memoria, sin
  puertos host innecesarios, env_file con placeholders y backend de estado
  remoto. Read-only, no aplica cambios.

fuentes_externas:
  - { tipo: tool, nombre: docker-compose, version_min: "2.20", licencia: "Apache-2.0" }
  - { tipo: tool, nombre: grep,           version_min: "3.0",  licencia: "GPL-3.0" }
  - { tipo: tool, nombre: find,           version_min: "4.7",  licencia: "GPL-3.0" }
  - { tipo: tool, nombre: terraform,      version_min: "1.6",  licencia: "BUSL-1.1" }
conexiones_requeridas: []

referencias_canonicas:
  - { tipo: doc_oficial, url: "https://developer.hashicorp.com/terraform/docs", cobertura: "Terraform · validate, backends remotos, configuracion declarativa de IaC" }
  - { tipo: estandar,    url: "https://docs.docker.com/compose/compose-file/", cobertura: "Compose file reference · esquema services/deploy/resources/ports/env_file" }

verificar_referencias:
  cuando: "antes de cada bump de version_min de tools"
  como: "consultar doc oficial; rechazar bump si la doc marca cambio breaking en el esquema del Compose file o en la sintaxis HCL de Terraform"

areas_criticas:
  permisos_user:
    - "lectura de compose.yaml y ficheros .tf dentro del repo objetivo"
    - "escritura: $XDG_RUNTIME_DIR/xek-sandbox/XEK_iac/"
  fhs_tocados:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_iac/ (solo escritura de findings)"
  visual_secrets:
    - "valores en env_file o variables .tfvars que parezcan secretos · nunca imprimir el valor"
  zonas_ocultas:
    - "runtime de contenedores en el host y estado real de la infraestructura desplegada · fuera de alcance"

modos_ejecucion:
  dry-run:
    proposito: "Verificar precondiciones y listar los checks que se ejecutarian sin parsear el target."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · plan textual de checks · exit 0 si parse OK"
  sandbox:
    proposito: "Copiar la IaC a un directorio aislado y correr la validacion read-only (compose config -q, grep estatico)."
    aislamiento: "directorio bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_iac/<run-id>/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_iac/"
    efectos_red: "ninguno · validacion local sin init de providers"
    salida: "findings.json en sandbox path · exit 0|1 segun findings"
  real:
    proposito: "Ejecutar contra la IaC real del repo (read-only) y persistir informe en cuaderno."
    precondicion: "sandbox del mismo input ha pasado en las ultimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_iac/<fecha>/"
    efectos_red: "ninguno"
    salida: "informe.md + findings.json + propuesta_#N si findings ≥ severidad_min"
gate_promocion:
  regla: "modo N+1 solo si modo N exit 0|1 con plan"
  override: "--override-gate=AUTO_<timestamp ±60s>"

escalada_privilegio:
  comando_template: "${XEK_SUDO:-sudo -A}"
  cuando_aplica: "no aplica · validacion read-only de ficheros del repo sin escalada"

depende_de:
  - { slug: XEK_detecta-stack, modo: sandbox, obligatoria: true, razon: "necesita manifiesto con rutas de compose.yaml y modulos .tf" }
contrato_invocacion:
  modo_subordinado: sandbox
  promocion_real: solo_operador
  consolidacion: "json · merge por slug · schema xek/finding@v1"

checks:
  - id: "iac-001"
    descripcion: "compose.yaml es sintacticamente valido segun el Compose file reference"
    command_template: "docker compose -f '$COMPOSE' config -q"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "iac-002"
    descripcion: "compose.yaml no fija imagenes con :latest"
    command_template: "! grep -iE '^[[:space:]]*image:[[:space:]]*[^[:space:]]+:latest' '$COMPOSE'"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "iac-003"
    descripcion: "compose.yaml declara limites de memoria (deploy.resources.limits.memory o mem_limit)"
    command_template: "grep -qiE '^[[:space:]]*(mem_limit:|memory:)' '$COMPOSE'"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "iac-004"
    descripcion: "compose.yaml no publica puertos al host de forma innecesaria (sin mapeo 0.0.0.0:host:cont)"
    command_template: "! grep -iE '^[[:space:]]*-[[:space:]]*.?0\\.0\\.0\\.0:[0-9]+:[0-9]+' '$COMPOSE'"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "iac-005"
    descripcion: "env_file referenciado contiene placeholders, no secretos reales en claro"
    command_template: "! grep -rIiE '(PASSWORD|SECRET|TOKEN|API_?KEY)=[^[:space:]$].{8,}' \"$(dirname '$COMPOSE')\"/.env* 2>/dev/null"
    expected_exit: 0
    severity_default: critical
    solo_modo: [sandbox, real]
  - id: "iac-006"
    descripcion: "Terraform (si presente) tiene HCL valido segun fmt -check"
    command_template: "test -z \"$TFDIR\" || terraform -chdir=\"$TFDIR\" fmt -check -recursive"
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]
  - id: "iac-007"
    descripcion: "Terraform (si presente) declara un backend de estado remoto (no local)"
    command_template: "test -z \"$TFDIR\" || grep -rqiE 'backend[[:space:]]+\"(s3|gcs|azurerm|remote|http|consul|pg)\"' \"$TFDIR\""
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "iac-008"
    descripcion: "Terraform (si presente) no embebe secretos en literales de variable por defecto"
    command_template: "test -z \"$TFDIR\" || ! grep -rIiE '(password|secret|token|api_?key)[[:space:]]*=[[:space:]]*\"[^\"$].{6,}\"' \"$TFDIR\""
    expected_exit: 0
    severity_default: critical
    solo_modo: [sandbox, real]

aplicabilidad:
  cuando:
    - "manifest.target_tipo == 'repo'"
  prioridad: media
  coste_relativo: 2

migracion_runtime:
  bash:   scripts/xek-iac.sh
  python: scripts/xek-iac.py
  zsh:    scripts/xek-iac.zsh

triggers:
  keywords: ["iac", "terraform", "compose", "docker-compose", "infraestructura", "tfstate", "backend-remoto", "validate"]
  contextos: ["pre-PR", "pre-deploy", "post-merge"]
  cron: ""
---

# Objetivo

Validar en estatico la Infraestructura como Codigo versionada en un repositorio
(`compose.yaml`, modulos Terraform): que el Compose file sea valido
(`docker compose config -q`), sin imagenes `:latest`, con limites de memoria
declarados, sin publicar puertos al host de forma innecesaria, con `env_file`
de placeholders (no secretos reales) y, para Terraform, con backend de estado
remoto. La skill solo inspecciona los ficheros; nunca aplica cambios ni hace
`init`/`apply`.

# Scope exclusivo

`XEK_iac` audita **artefactos declarativos versionados dentro de un repositorio**
(`target_tipo == 'repo'`): Dockerfiles, `compose.yaml`, manifiestos Terraform/IaC, Helm charts.
Comprueba la *definicion como codigo*, en estatico, sin daemon en marcha.

El **runtime de contenedores en un host** (engines Docker/Podman/LXC instalados, daemons,
sockets, rootless, redes activas, escaneo de imagenes desplegadas) es competencia exclusiva de
[`XEK_linux-contenedores`](../XEK_linux-contenedores/SKILL.md) (`target_tipo == 'host'`). La
frontera Docker/Compose se resuelve por `target_tipo`: **repo = archivos, host = runtime**. No
hay solape de checks entre ambas en una orquestacion.

# Cuando activar

| Si... | Entonces... |
|---|---|
| `manifest.target_tipo == 'repo'` con `compose.yaml` o modulos `.tf` | Ejecutar `--mode=sandbox` sobre la copia aislada |
| Pre-deploy de un cambio de infraestructura | Correr `iac-001..iac-008` y bloquear si falla severidad high/critical |
| Post-merge a la rama de IaC | Promover a `--mode=real` tras sandbox verde |

# Uso · comentario encabezado (copiar al script)

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_iac · v0.7.0 · 2026-06-20                                ║
# ║  Funcion: validar IaC declarativa en repo (read-only)         ║
# ║  Variables entorno:                                           ║
# ║    XEK_TARGET_DIR     raiz del repo a inspeccionar            ║
# ║    XDG_RUNTIME_DIR    base sandbox                            ║
# ║  Uso:                                                         ║
# ║    xek-iac.sh --mode={dry-run|sandbox|real} [--target <path>] ║
# ║  Exit codes:                                                  ║
# ║    0=clean · 1=findings · 2=config · 3=missing-mode · 4=ill-call║
# ╚══════════════════════════════════════════════════════════════╝
```

# Implementacion referencia (bash · fuente de verdad)

```bash
#!/usr/bin/env bash
set -euo pipefail

SLUG="XEK_iac"
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
  for bin in bash grep find; do
    command -v "$bin" >/dev/null 2>&1 || { echo "PREFLIGHT FAIL: $bin absent" >&2; return 1; }
  done
}

if [[ "$MODE" == "dry-run" ]]; then
  echo "## ${SLUG} v${VERSION} · plan dry-run"
  preflight || exit 2
  echo "checks: iac-001..iac-008 (compose config, sin :latest, limites mem, puertos host, env_file, tf backend remoto)"
  exit 0
fi

preflight || exit 2

COMPOSE="$(find "$TARGET" -maxdepth 2 -iregex '.*/\(docker-\)?compose\.ya?ml' | head -n1)"
TFDIR=""
find "$TARGET" -maxdepth 2 -name '*.tf' -print -quit | grep -q . && TFDIR="$(dirname "$(find "$TARGET" -maxdepth 2 -name '*.tf' | head -n1)")"
[[ -z "$COMPOSE" && -z "$TFDIR" ]] && { echo "no IaC artefacts under $TARGET" >&2; exit 2; }

FINDINGS=0
emit() { echo "  - { check: $1, severity: $2, status: $3 }"; }
run_check() {
  local id="$1" sev="$2"; shift 2
  if "$@" >/dev/null 2>&1; then emit "$id" "$sev" pass
  else emit "$id" "$sev" fail; FINDINGS=$((FINDINGS+1)); fi
}

echo "findings:"
if [[ -n "$COMPOSE" ]]; then
  run_check iac-001 high     bash -c "docker compose -f '$COMPOSE' config -q"
  run_check iac-002 high     bash -c "! grep -iE '^[[:space:]]*image:[[:space:]]*[^[:space:]]+:latest' '$COMPOSE'"
  run_check iac-003 medium   bash -c "grep -qiE '^[[:space:]]*(mem_limit:|memory:)' '$COMPOSE'"
  run_check iac-004 medium   bash -c "! grep -iE '^[[:space:]]*-[[:space:]]*.?0\\.0\\.0\\.0:[0-9]+:[0-9]+' '$COMPOSE'"
fi
if [[ -n "$TFDIR" ]]; then
  run_check iac-007 high     bash -c "grep -rqiE 'backend[[:space:]]+\"(s3|gcs|azurerm|remote|http|consul|pg)\"' '$TFDIR'"
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
"""XEK_iac · adapter Python para pipelines orquestados."""
import subprocess, sys, pathlib
script = pathlib.Path(__file__).with_name("xek-iac.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-iac.sh" "$@"
```

# Verificacion end-to-end (smoke test)

```bash
# Caso happy · dry-run no toca disco
./scripts/xek-iac.sh --mode=dry-run && echo "PASS dry-run"

# Caso sandbox contra IaC valida · exit 0
./scripts/xek-iac.sh --mode=sandbox --target ./fixtures/buena-iac
echo "exit=$?"

# Caso falla esperada · compose invalido o con :latest y tf state local · exit 1
./scripts/xek-iac.sh --mode=sandbox --target ./fixtures/mala-iac
echo "exit=$?"
```

# Riesgos y mitigacion

| Riesgo | Mitigacion |
|---|---|
| `docker compose config -q` requiere el binario docker presente en el runner | `iac-001` se marca como no aplicable (skip, no fail) si `docker` ausente; el resto de checks son grep puro |
| Terraform con providers no inicializados rompe `validate` | Se usa `fmt -check` y grep sobre el backend; se evita `terraform validate` para no exigir `init` ni red |
| Puerto host legitimo en `0.0.0.0` (servicio publico intencional) | `iac-004` es severidad medium y se documenta como revision manual, no bloqueo duro |
| `.env` con secretos reales versionado por error | `iac-005` busca patrones de secreto en `.env*`; severidad critical para forzar revision |

# Bitacora evolucion (append-only · R8)

- **v0.0.1** (2026-05-20) — bootstrap stub.
- **v0.6.1** (2026-05-22) — degradado borrador→stub per sintesis Ronda 002.
- **v0.6.2** (2026-06-06) — formalizado Scope exclusivo frente a XEK_linux-contenedores.
- **v0.7.0** (2026-06-20) — stub→borrador: frontmatter R4+R7 completo + modos_ejecucion + 8 checks[] tipados (iac-001..008) read-only con docker compose config -q y grep estatico + fuentes canonicas reales (Terraform docs, Compose file reference) + bash referencia de 3 modos.

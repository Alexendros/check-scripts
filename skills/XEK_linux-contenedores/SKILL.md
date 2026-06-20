---
slug: XEK_linux-contenedores
ambito: Linux
maestria_funcional: revisor
estado: borrador
version: 0.7.0
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub · pendiente implementación" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "degradado borrador→stub per síntesis Ronda 002 (commit deuda v0.6)" }
  - { v: 0.7.0, fecha: 2026-06-20, cambio: "stub→borrador · fuentes reales, escalada R16, checks[] read-only" }

objetivo: >
  Verificar postura de seguridad de contenedores del host: rootless/userns, ausencia
  de --privileged, límites de recursos, socket Docker no expuesto y pinning de imágenes.

fuentes_externas:
  - { tipo: tool, nombre: "docker",  version_min: "24.0", licencia: "Apache-2.0" }
  - { tipo: tool, nombre: "podman",  version_min: "4.6",  licencia: "Apache-2.0" }
  - { tipo: tool, nombre: "jq",      version_min: "1.7",  licencia: "MIT" }
conexiones_requeridas: []

referencias_canonicas:
  - { tipo: doc_oficial, url: "https://docs.docker.com/engine/security/", cobertura: "rootless, userns-remap, capabilities, socket" }
  - { tipo: estandar,    url: "https://www.cisecurity.org/benchmark/docker", cobertura: "CIS Docker Benchmark · daemon y runtime" }
  - { tipo: estandar,    url: "https://www.cisecurity.org/benchmark/distribution_independent_linux", cobertura: "CIS · aislamiento de cargas en host" }
verificar_referencias:
  cuando: "antes de cada bump version_min de docker/podman"
  como: "consultar release notes; rechazar bump si cambia el formato de `docker inspect`/`info --format`"

areas_criticas:
  permisos_user:
    - "ejecución de docker/podman info e inspect (acceso vía grupo docker o modo rootless)"
    - "lectura de /etc/docker/daemon.json y unit de docker.service"
  fhs_tocados:
    - "/etc/docker/daemon.json (solo lectura)"
    - "/var/run/docker.sock (evaluar permisos · NO escribir)"
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-contenedores/"
  visual_secrets:
    - "variables de entorno de contenedores · evaluar presencia de secretos, NUNCA imprimir valores"
  zonas_ocultas:
    - "config de registries privados en ~/.docker/config.json (no imprimir auth)"

modos_ejecucion:
  dry-run:
    proposito: "Detectar runtime de contenedores y daemon activo sin inspeccionar contenedores."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · runtime + modo (rootful/rootless) · exit 0"
  sandbox:
    proposito: "Capturar snapshot de postura de contenedores en sandbox (inspect read-only)."
    aislamiento: "directorio bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-contenedores/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-contenedores/"
    efectos_red: "ninguno"
    salida: "findings.json · exit 0/1 según postura"
  real:
    proposito: "Ejecutar contra host real · genera informe + propuesta_#N. Nunca crea ni modifica contenedores."
    precondicion: "sandbox del mismo host ha pasado en las últimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_linux-contenedores/<fecha>/"
    efectos_red: "ninguno"
    salida: "informe.md + findings.json + propuesta_#N"
gate_promocion:
  regla: "modo N+1 solo si modo N exit 0|1 con plan"
  override: "--override-gate=AUTO_<timestamp ±60s>"

escalada_privilegio:
  comando_template: "${XEK_SUDO:-sudo -A}"
  cuando_aplica: "inspección de un daemon Docker rootful y lectura de /etc/docker/daemon.json cuando el usuario no está en el grupo docker; sin escalada se omite el check y se reporta skipped"

depende_de:
  - { slug: XEK_detecta-stack, modo: sandbox, obligatoria: true, razon: "necesita host_huellas.distro_familia" }
contrato_invocacion:
  modo_subordinado: sandbox
  promocion_real: solo_operador
  consolidacion: "json · schema xek/finding@v1"

aplicabilidad:
  cuando:
    - "manifest.target_tipo == 'host'"
  prioridad: alta
  coste_relativo: 3

migracion_runtime:
  bash:   scripts/xek-linux-contenedores.sh
  python: scripts/xek-linux-contenedores.py
  zsh:    scripts/xek-linux-contenedores.zsh

checks:
  - id: "ctr-001"
    descripcion: "Detectar runtime de contenedores presente (docker o podman)"
    command_template: "command -v docker >/dev/null || command -v podman >/dev/null"
    expected_exit: 0
    severity_default: info
    solo_modo: [dry-run, sandbox, real]
  - id: "ctr-002"
    descripcion: "Verificar modo rootless / userns-remap del daemon"
    command_template: "docker info --format '{{.SecurityOptions}}' 2>/dev/null | grep -qE 'rootless|name=userns' || podman info --format '{{.Host.Security.Rootless}}' 2>/dev/null | grep -qi true"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "ctr-003"
    descripcion: "Detectar contenedores en ejecución con --privileged (postura insegura)"
    command_template: "test \"$(docker ps -q 2>/dev/null | xargs -r docker inspect --format '{{.HostConfig.Privileged}}' 2>/dev/null | grep -c true)\" -eq 0"
    expected_exit: 0
    severity_default: critical
    solo_modo: [sandbox, real]
  - id: "ctr-004"
    descripcion: "Verificar que los contenedores en ejecución tienen límites de memoria"
    command_template: "test -z \"$(docker ps -q 2>/dev/null | xargs -r docker inspect --format '{{.Name}} {{.HostConfig.Memory}}' 2>/dev/null | awk '$2==0')\""
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "ctr-005"
    descripcion: "Comprobar que el socket docker no está montado dentro de ningún contenedor"
    command_template: "test -z \"$(docker ps -q 2>/dev/null | xargs -r docker inspect --format '{{range .Mounts}}{{.Source}}{{end}}' 2>/dev/null | grep docker.sock)\""
    expected_exit: 0
    severity_default: critical
    solo_modo: [sandbox, real]
  - id: "ctr-006"
    descripcion: "Detectar imágenes sin pinning por digest (uso de :latest o tag mutable)"
    command_template: "test -z \"$(docker ps --format '{{.Image}}' 2>/dev/null | grep -vE '@sha256:' | grep -E ':latest$|^[^:@]+$')\""
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "ctr-007"
    descripcion: "Inspeccionar daemon.json del daemon de sistema (privilegiado · skip sin escalada)"
    command_template: "${XEK_SUDO:-sudo -A} test -f /etc/docker/daemon.json 2>/dev/null && echo present || echo absent-or-no-priv"
    expected_exit: 0
    severity_default: info
    solo_modo: [real]

triggers:
  keywords: ["docker", "podman", "contenedores", "rootless", "privileged", "cis-docker", "containers"]
  contextos: ["pre-deploy", "post-update", "cron"]
  cron: "0 7 * * 1"
---

# Objetivo

Verificar la postura de seguridad de contenedores del host: ejecución rootless o
userns-remap, ausencia de contenedores `--privileged`, límites de recursos
configurados, socket de Docker no expuesto dentro de contenedores y pinning de
imágenes por digest. Read-only: nunca crea, modifica ni detiene contenedores.

# Cuándo activar

| Si... | Entonces... |
|---|---|
| Pre-deploy de carga containerizada | Invocar `--mode=sandbox` · validar privileged + límites |
| Auditoría CIS Docker | Invocar `--mode=sandbox` · revisar rootless y socket |
| Tras actualización del runtime | Re-evaluar SecurityOptions del daemon |
| `target_tipo != 'host'` | Skill se salta con `skipped: not_applicable` |

# Uso · comentario encabezado (copiar al script)

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_linux-contenedores · v0.7.0 · 2026-06-20               ║
# ║  Función: verificar postura de seguridad de contenedores     ║
# ║  Variables entorno:                                          ║
# ║    XEK_SUDO            comando de escalada (default: sudo -A) ║
# ║    XDG_RUNTIME_DIR     base sandbox                          ║
# ║  Uso:                                                        ║
# ║    xek-linux-contenedores.sh --mode={dry-run|sandbox|real}  ║
# ║  Exit codes:                                                ║
# ║    0=clean · 1=findings · 2=config · 3=missing-mode · 4=ill ║
# ╚══════════════════════════════════════════════════════════════╝
```

# Implementación referencia (bash · fuente de verdad)

```bash
#!/usr/bin/env bash
set -euo pipefail
# Escalada agnóstica del operador (R16)
SUDO="${XEK_SUDO:-sudo -A}"
# TODO: ejecutar los checks[] declarados en los 3 modos · inspect read-only.
```

# Adaptador Python

```python
#!/usr/bin/env python3
"""XEK_linux-contenedores · adapter Python."""
import subprocess, sys, pathlib
script = pathlib.Path(__file__).with_name("xek-linux-contenedores.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-linux-contenedores.sh" "$@"
```

# Verificación end-to-end (smoke test)

```bash
./scripts/xek-linux-contenedores.sh --mode=dry-run && echo "PASS dry-run"
./scripts/xek-linux-contenedores.sh --mode=sandbox
echo "exit=$?"
```

# Riesgos y mitigación

| Riesgo | Mitigación |
|---|---|
| `docker inspect` requiere grupo docker | Check privilegiado marcado · skip+report sin acceso |
| Variables de contenedor filtran secretos | Reportar solo presencia; nunca imprimir valores |
| `:latest` no implica vulnerable por sí solo | Severidad media · finding informativo con propuesta de pinning |
| Daemon remoto vía TCP sin TLS | `ctr-005`/daemon.json detectan exposición · severidad crítica |

# Bitácora evolución

- **v0.0.1** (2026-05-20) — bootstrap stub.
- **v0.6.1** (2026-05-22) — degradado a stub (deuda v0.6).
- **v0.7.0** (2026-06-20) — stub→borrador: fuentes reales, escalada `${XEK_SUDO}`, checks[] read-only.

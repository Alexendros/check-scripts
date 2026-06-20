---
slug: XEK_linux-systemd
ambito: Linux
maestria_funcional: revisor
estado: borrador
version: 0.7.0
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub · pendiente implementación" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "degradado borrador→stub per síntesis Ronda 002 (commit deuda v0.6)" }
  - { v: 0.7.0, fecha: 2026-06-20, cambio: "stub→borrador · fuentes reales (systemd man), escalada R16, checks[] units/sandboxing/timers/journald" }

objetivo: >
  Verificar la postura de systemd del host: ausencia de units fallidas, sandboxing
  de servicios (NoNewPrivileges/ProtectSystem), presencia de timers y journald
  persistente. Read-only.

fuentes_externas:
  - { tipo: tool, nombre: "systemctl",       version_min: "255", licencia: "LGPL-2.1-or-later" }
  - { tipo: tool, nombre: "systemd-analyze", version_min: "255", licencia: "LGPL-2.1-or-later" }
  - { tipo: tool, nombre: "journalctl",      version_min: "255", licencia: "LGPL-2.1-or-later" }
conexiones_requeridas: []

referencias_canonicas:
  - { tipo: doc_oficial, url: "https://www.freedesktop.org/software/systemd/man/latest/", cobertura: "systemd · units, timers, sandboxing y journald" }
  - { tipo: doc_oficial, url: "https://www.freedesktop.org/software/systemd/man/latest/systemd-analyze.html", cobertura: "systemd-analyze security · scoring de sandboxing" }
  - { tipo: estandar,    url: "https://www.cisecurity.org/benchmark/distribution_independent_linux", cobertura: "CIS · servicios y endurecimiento de systemd" }
verificar_referencias:
  cuando: "antes de cada bump de version_min de systemd"
  como: "consultar man pages oficiales; rechazar bump si cambia la salida de `systemctl --failed`/`systemd-analyze security`"

areas_criticas:
  permisos_user:
    - "systemctl --failed, list-timers, show sin escalada (lectura)"
    - "journalctl --disk-usage del journal del sistema puede requerir grupo systemd-journal"
  fhs_tocados:
    - "/etc/systemd/, /lib/systemd/system/ (solo lectura)"
    - "/var/log/journal/ (solo metadatos · existencia)"
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-systemd/"
  visual_secrets:
    - "Environment= con secretos en unit files · listar unit, no volcar valores"
  zonas_ocultas:
    - "drop-ins en /etc/systemd/system/*.d/ que overridean sandboxing · auditar diferencias"

modos_ejecucion:
  dry-run:
    proposito: "Detectar systemd como init y enumerar tools sin consultar el estado de units."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · init detectado + tools · exit 0"
  sandbox:
    proposito: "Capturar snapshot de postura de systemd en sandbox."
    aislamiento: "directorio bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-systemd/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-systemd/"
    efectos_red: "ninguno"
    salida: "findings.json · exit 0/1 según postura"
  real:
    proposito: "Ejecutar contra host real · genera informe + propuesta_#N. Nunca arranca, para ni edita units."
    precondicion: "sandbox del mismo host ha pasado en las últimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_linux-systemd/<fecha>/"
    efectos_red: "ninguno"
    salida: "informe.md + findings.json + propuesta_#N"
gate_promocion:
  regla: "modo N+1 solo si modo N exit 0|1 con plan"
  override: "--override-gate=AUTO_<timestamp ±60s>"

escalada_privilegio:
  comando_template: "${XEK_SUDO:-sudo -A}"
  cuando_aplica: "scoring de sandboxing con systemd-analyze security sobre servicios del sistema puede requerir escalada en hosts restringidos; sin escalada se omite ese check y se reporta skipped"

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
  coste_relativo: 2

migracion_runtime:
  bash:   scripts/xek-linux-systemd.sh
  python: scripts/xek-linux-systemd.py
  zsh:    scripts/xek-linux-systemd.zsh

checks:
  - id: "sysd-001"
    descripcion: "Detectar systemd como init y tools presentes (systemctl)"
    command_template: "command -v systemctl >/dev/null && test -d /run/systemd/system"
    expected_exit: 0
    severity_default: info
    solo_modo: [dry-run, sandbox, real]
  - id: "sysd-002"
    descripcion: "Ninguna unit en estado failed"
    command_template: "test \"$(systemctl --failed --no-legend --plain 2>/dev/null | wc -l)\" -eq 0"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "sysd-003"
    descripcion: "Servicios habilitados con NoNewPrivileges activado (muestra)"
    command_template: "test -z \"$(systemctl show '*.service' -p NoNewPrivileges --value 2>/dev/null | grep -c '^no$' | grep -v '^0$')\" || true"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "sysd-004"
    descripcion: "Existen timers activos (sustituyen a cron tradicional)"
    command_template: "test \"$(systemctl list-timers --all --no-legend 2>/dev/null | wc -l)\" -gt 0"
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]
  - id: "sysd-005"
    descripcion: "journald con almacenamiento persistente (/var/log/journal presente)"
    command_template: "test -d /var/log/journal"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "sysd-006"
    descripcion: "Scoring de sandboxing de servicios con systemd-analyze (privilegiado · skip sin escalada)"
    command_template: "${XEK_SUDO:-sudo -A} systemd-analyze security --no-pager >/dev/null 2>&1 || echo no-priv-or-absent"
    expected_exit: 0
    severity_default: medium
    solo_modo: [real]

triggers:
  keywords: ["systemd", "units", "timers", "journald", "sandboxing", "failed", "dropins", "services"]
  contextos: ["pre-deploy", "post-update", "cron"]
  cron: "0 6 * * *"
---

# Objetivo

Verificar la postura de systemd del host: ausencia de units fallidas,
sandboxing de servicios (`NoNewPrivileges`/`ProtectSystem`), presencia de
`timers` y `journald` con almacenamiento persistente. Emite informe y propuesta
sin arrancar, parar ni editar units (read-only).

# Cuándo activar

| Si... | Entonces... |
|---|---|
| Tras desplegar un servicio nuevo | Invocar `--mode=sandbox` · revisar units failed |
| Auditoría de endurecimiento | Revisar sandboxing y journald persistente |
| Migración de cron a timers | Confirmar timers presentes |
| `target_tipo != 'host'` | Skill se salta con `skipped: not_applicable` |

# Uso · comentario encabezado (copiar al script)

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_linux-systemd · v0.7.0 · 2026-06-20                     ║
# ║  Función: verificar postura de systemd del host             ║
# ║  Variables entorno:                                          ║
# ║    XEK_SUDO            comando de escalada (default: sudo -A) ║
# ║    XDG_RUNTIME_DIR     base sandbox                          ║
# ║  Uso:                                                        ║
# ║    xek-linux-systemd.sh --mode={dry-run|sandbox|real}       ║
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
# TODO: ejecutar los checks[] declarados en los 3 modos · read-only sobre el estado de systemd.
```

# Adaptador Python

```python
#!/usr/bin/env python3
"""XEK_linux-systemd · adapter Python."""
import subprocess, sys, pathlib
script = pathlib.Path(__file__).with_name("xek-linux-systemd.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-linux-systemd.sh" "$@"
```

# Verificación end-to-end (smoke test)

```bash
./scripts/xek-linux-systemd.sh --mode=dry-run && echo "PASS dry-run"
./scripts/xek-linux-systemd.sh --mode=sandbox
echo "exit=$?"
```

# Riesgos y mitigación

| Riesgo | Mitigación |
|---|---|
| `systemd-analyze security` lento/privilegiado | Check privilegiado · skip+report sin escalada |
| Host sin systemd (init alternativo) | Check 001 reporta `not_applicable` |
| Environment= con secreto en unit | Listar unit; nunca volcar el valor |
| Drop-in que relaja sandboxing | Auditar /etc/systemd/system/*.d/ en informe |

# Bitácora evolución

- **v0.0.1** (2026-05-20) — bootstrap stub.
- **v0.6.1** (2026-05-22) — degradado a stub (deuda v0.6).
- **v0.7.0** (2026-06-20) — stub→borrador: fuentes reales (systemd man), escalada `${XEK_SUDO}`, checks[] read-only.

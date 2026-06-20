---
slug: XEK_linux-energia
ambito: Linux
maestria_funcional: revisor
estado: borrador
version: 0.7.0
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub · pendiente implementación" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "degradado borrador→stub per síntesis Ronda 002 (commit deuda v0.6)" }
  - { v: 0.7.0, fecha: 2026-06-20, cambio: "stub→borrador · fuentes reales, escalada R16, checks[] read-only" }

objetivo: >
  Verificar postura de gestión de energía del host: governor cpufreq, gestor activo
  (TLP o power-profiles-daemon) y configuración de suspensión/hibernación. Read-only.

fuentes_externas:
  - { tipo: tool, nombre: "tlp",                 version_min: "1.6", licencia: "GPL-3.0-or-later" }
  - { tipo: tool, nombre: "powerprofilesctl",    version_min: "0.20", licencia: "GPL-3.0-or-later" }
  - { tipo: tool, nombre: "systemctl",           version_min: "252",  licencia: "LGPL-2.1-or-later" }
conexiones_requeridas: []

referencias_canonicas:
  - { tipo: doc_oficial, url: "https://www.freedesktop.org/software/systemd/man/latest/systemd-sleep.html", cobertura: "suspend/hibernate/suspend-then-hibernate" }
  - { tipo: doc_oficial, url: "https://linrunner.de/tlp/", cobertura: "TLP · gestión de energía portátiles" }
  - { tipo: doc_oficial, url: "https://www.freedesktop.org/software/power-profiles-daemon/docs/", cobertura: "power-profiles-daemon · perfiles de energía" }
verificar_referencias:
  cuando: "antes de cada bump version_min de tlp/powerprofilesctl"
  como: "consultar documentación oficial; rechazar bump si cambia la salida de `tlp-stat`/`powerprofilesctl get`"

areas_criticas:
  permisos_user:
    - "lectura de /sys/devices/system/cpu/*/cpufreq/scaling_governor sin escalada"
    - "powerprofilesctl get y systemctl status sin escalada"
  fhs_tocados:
    - "/sys/devices/system/cpu/ (solo lectura)"
    - "/etc/tlp.conf, /etc/systemd/sleep.conf (solo lectura)"
    - "/sys/power/ (solo lectura · estados de suspensión soportados)"
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-energia/"
  visual_secrets: []
  zonas_ocultas:
    - "/sys/power/* (lectura · no escribir estados de energía)"

modos_ejecucion:
  dry-run:
    proposito: "Detectar gestor de energía y governor activo sin alterar estado."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · power_mgr + governor · exit 0"
  sandbox:
    proposito: "Capturar snapshot de postura de energía en sandbox."
    aislamiento: "directorio bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-energia/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-energia/"
    efectos_red: "ninguno"
    salida: "findings.json · exit 0/1 según postura"
  real:
    proposito: "Ejecutar contra host real · genera informe + propuesta_#N. Nunca cambia governor ni perfil."
    precondicion: "sandbox del mismo host ha pasado en las últimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_linux-energia/<fecha>/"
    efectos_red: "ninguno"
    salida: "informe.md + findings.json + propuesta_#N"
gate_promocion:
  regla: "modo N+1 solo si modo N exit 0|1 con plan"
  override: "--override-gate=AUTO_<timestamp ±60s>"

escalada_privilegio:
  comando_template: "${XEK_SUDO:-sudo -A}"
  cuando_aplica: "ejecución de tlp-stat completo (lee sensores que requieren root); sin escalada se usa tlp-stat -s y se reporta cobertura parcial"

depende_de:
  - { slug: XEK_detecta-stack, modo: sandbox, obligatoria: true, razon: "necesita host_huellas.distro_familia" }
contrato_invocacion:
  modo_subordinado: sandbox
  promocion_real: solo_operador
  consolidacion: "json · schema xek/finding@v1"

aplicabilidad:
  cuando:
    - "manifest.target_tipo == 'host'"
  prioridad: media
  coste_relativo: 1

migracion_runtime:
  bash:   scripts/xek-linux-energia.sh
  python: scripts/xek-linux-energia.py
  zsh:    scripts/xek-linux-energia.zsh

checks:
  - id: "ene-001"
    descripcion: "Detectar gestor de energía presente (TLP o power-profiles-daemon)"
    command_template: "command -v tlp >/dev/null || command -v powerprofilesctl >/dev/null"
    expected_exit: 0
    severity_default: info
    solo_modo: [dry-run, sandbox, real]
  - id: "ene-002"
    descripcion: "Leer governor cpufreq activo del primer núcleo"
    command_template: "cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null | grep -qE '^(performance|powersave|schedutil|ondemand|conservative)$'"
    expected_exit: 0
    severity_default: info
    solo_modo: [sandbox, real]
  - id: "ene-003"
    descripcion: "Verificar que el gestor de energía está activo (servicio en running)"
    command_template: "systemctl is-active tlp.service 2>/dev/null | grep -qx active || systemctl is-active power-profiles-daemon.service 2>/dev/null | grep -qx active"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "ene-004"
    descripcion: "Comprobar estados de suspensión soportados por el kernel"
    command_template: "grep -qE 'mem|standby|freeze' /sys/power/state 2>/dev/null"
    expected_exit: 0
    severity_default: info
    solo_modo: [sandbox, real]
  - id: "ene-005"
    descripcion: "Inspeccionar configuración de sleep de systemd (HibernateMode/SuspendState)"
    command_template: "test -f /etc/systemd/sleep.conf || ls /etc/systemd/sleep.conf.d/*.conf 2>/dev/null | grep -q . || systemd-analyze cat-config systemd/sleep.conf >/dev/null 2>&1"
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]
  - id: "ene-006"
    descripcion: "Recoger estado detallado de TLP que requiere root (privilegiado · skip sin escalada)"
    command_template: "${XEK_SUDO:-sudo -A} tlp-stat -s 2>/dev/null | grep -qi 'TLP_ENABLE' || echo no-priv-or-absent"
    expected_exit: 0
    severity_default: info
    solo_modo: [real]

triggers:
  keywords: ["energia", "power", "tlp", "cpufreq", "governor", "suspend", "hibernate"]
  contextos: ["post-update", "cron", "pre-deploy"]
  cron: "0 8 * * 1"
---

# Objetivo

Verificar la postura de gestión de energía del host: governor de cpufreq activo,
gestor de energía presente y en ejecución (TLP o power-profiles-daemon), estados
de suspensión soportados por el kernel y configuración de `systemd-sleep`. Emite
informe y propuesta sin alterar governor, perfil ni estado de energía (read-only).

# Cuándo activar

| Si... | Entonces... |
|---|---|
| Auditoría de eficiencia en portátil | Invocar `--mode=sandbox` · governor + gestor activo |
| Tras actualización de kernel | Re-verificar estados de suspensión soportados |
| Revisión de perfil AC/batería | Confirmar gestor activo y config de sleep |
| `target_tipo != 'host'` | Skill se salta con `skipped: not_applicable` |

# Uso · comentario encabezado (copiar al script)

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_linux-energia · v0.7.0 · 2026-06-20                     ║
# ║  Función: verificar postura de energía del host             ║
# ║  Variables entorno:                                          ║
# ║    XEK_SUDO            comando de escalada (default: sudo -A) ║
# ║    XDG_RUNTIME_DIR     base sandbox                          ║
# ║  Uso:                                                        ║
# ║    xek-linux-energia.sh --mode={dry-run|sandbox|real}       ║
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
# TODO: ejecutar los checks[] declarados en los 3 modos · read-only sobre /sys y servicios.
```

# Adaptador Python

```python
#!/usr/bin/env python3
"""XEK_linux-energia · adapter Python."""
import subprocess, sys, pathlib
script = pathlib.Path(__file__).with_name("xek-linux-energia.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-linux-energia.sh" "$@"
```

# Verificación end-to-end (smoke test)

```bash
./scripts/xek-linux-energia.sh --mode=dry-run && echo "PASS dry-run"
./scripts/xek-linux-energia.sh --mode=sandbox
echo "exit=$?"
```

# Riesgos y mitigación

| Riesgo | Mitigación |
|---|---|
| TLP y power-profiles-daemon en conflicto | `ene-003` reporta ambos activos como finding |
| `tlp-stat` completo requiere root | Usar `tlp-stat -s` sin escalada; detalle vía `${XEK_SUDO}` |
| Host sin cpufreq (VM) | `ene-002` reporta ausencia · severidad info, no aborta |
| Lectura accidental de escritura en /sys/power | Solo `cat`; nunca redirigir a /sys/power/state |

# Bitácora evolución

- **v0.0.1** (2026-05-20) — bootstrap stub.
- **v0.6.1** (2026-05-22) — degradado a stub (deuda v0.6).
- **v0.7.0** (2026-06-20) — stub→borrador: fuentes reales, escalada `${XEK_SUDO}`, checks[] read-only.

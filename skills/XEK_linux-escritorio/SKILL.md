---
slug: XEK_linux-escritorio
ambito: Linux
maestria_funcional: revisor
estado: borrador
version: 0.7.0
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub · pendiente implementación" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "degradado borrador→stub per síntesis Ronda 002 (commit deuda v0.6)" }
  - { v: 0.7.0, fecha: 2026-06-20, cambio: "stub→borrador · fuentes reales, escalada R16, checks[] read-only" }

objetivo: >
  Verificar postura del entorno de escritorio del host: directorios XDG base, entorno
  de escritorio detectado, xdg-desktop-portal activo y sesión Wayland/X11. Read-only.

fuentes_externas:
  - { tipo: tool, nombre: "xdg-user-dir",     version_min: "0.18", licencia: "GPL-2.0-or-later" }
  - { tipo: tool, nombre: "loginctl",         version_min: "252",  licencia: "LGPL-2.1-or-later" }
  - { tipo: tool, nombre: "busctl",           version_min: "252",  licencia: "LGPL-2.1-or-later" }
conexiones_requeridas: []

referencias_canonicas:
  - { tipo: estandar,    url: "https://specifications.freedesktop.org/basedir-spec/latest/", cobertura: "XDG Base Directory Specification" }
  - { tipo: estandar,    url: "https://specifications.freedesktop.org/desktop-entry-spec/latest/", cobertura: "Desktop Entry Specification" }
  - { tipo: doc_oficial, url: "https://flatpak.github.io/xdg-desktop-portal/docs/", cobertura: "xdg-desktop-portal · sandboxing de apps" }
verificar_referencias:
  cuando: "antes de cada bump version_min de xdg-utils/portal"
  como: "consultar specs freedesktop; rechazar bump si cambia la semántica de las variables XDG_*"

areas_criticas:
  permisos_user:
    - "lectura de variables de entorno XDG_* del usuario sin escalada"
    - "loginctl show-session y busctl --user sin escalada"
  fhs_tocados:
    - "$XDG_CONFIG_HOME, $XDG_DATA_HOME, $XDG_RUNTIME_DIR (solo lectura)"
    - "~/.config/user-dirs.dirs (solo lectura)"
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-escritorio/"
  visual_secrets: []
  zonas_ocultas:
    - "~/.config/** (evaluar presencia de portales; no enumerar contenidos de apps)"

modos_ejecucion:
  dry-run:
    proposito: "Detectar entorno de escritorio y servidor gráfico sin consultar D-Bus."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · desktop_env + session_type · exit 0"
  sandbox:
    proposito: "Capturar snapshot de postura de escritorio en sandbox."
    aislamiento: "directorio bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-escritorio/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-escritorio/"
    efectos_red: "ninguno"
    salida: "findings.json · exit 0/1 según postura"
  real:
    proposito: "Ejecutar contra host real · genera informe + propuesta_#N. Nunca toca config de escritorio."
    precondicion: "sandbox del mismo host ha pasado en las últimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_linux-escritorio/<fecha>/"
    efectos_red: "ninguno"
    salida: "informe.md + findings.json + propuesta_#N"
gate_promocion:
  regla: "modo N+1 solo si modo N exit 0|1 con plan"
  override: "--override-gate=AUTO_<timestamp ±60s>"

escalada_privilegio:
  comando_template: "${XEK_SUDO:-sudo -A}"
  cuando_aplica: "inspección de sesiones gráficas de otros usuarios vía loginctl; la verificación de la propia sesión no requiere escalada · sin ella se omite y se reporta skipped"

depende_de:
  - { slug: XEK_detecta-stack, modo: sandbox, obligatoria: true, razon: "necesita host_huellas.desktop_env" }
contrato_invocacion:
  modo_subordinado: sandbox
  promocion_real: solo_operador
  consolidacion: "json · schema xek/finding@v1"

aplicabilidad:
  cuando:
    - "manifest.target_tipo == 'host'"
  prioridad: baja
  coste_relativo: 1

migracion_runtime:
  bash:   scripts/xek-linux-escritorio.sh
  python: scripts/xek-linux-escritorio.py
  zsh:    scripts/xek-linux-escritorio.zsh

checks:
  - id: "esc-001"
    descripcion: "Detectar entorno de escritorio activo vía XDG_CURRENT_DESKTOP"
    command_template: "test -n \"${XDG_CURRENT_DESKTOP:-}\""
    expected_exit: 0
    severity_default: info
    solo_modo: [dry-run, sandbox, real]
  - id: "esc-002"
    descripcion: "Verificar que las variables XDG base apuntan a rutas existentes"
    command_template: "test -d \"${XDG_CONFIG_HOME:-$HOME/.config}\" && test -d \"${XDG_DATA_HOME:-$HOME/.local/share}\" && test -d \"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}\""
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "esc-003"
    descripcion: "Detectar tipo de sesión gráfica (Wayland vs X11)"
    command_template: "loginctl show-session \"$(loginctl | awk -v u=\"$USER\" '$3==u{print $1; exit}')\" -p Type 2>/dev/null | grep -qE 'Type=(wayland|x11)' || test -n \"${WAYLAND_DISPLAY:-}${DISPLAY:-}\""
    expected_exit: 0
    severity_default: info
    solo_modo: [sandbox, real]
  - id: "esc-004"
    descripcion: "Verificar que xdg-desktop-portal está activo en el bus de usuario"
    command_template: "busctl --user list 2>/dev/null | grep -q 'org.freedesktop.portal.Desktop' || systemctl --user is-active xdg-desktop-portal.service 2>/dev/null | grep -qx active"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "esc-005"
    descripcion: "Comprobar definición de directorios de usuario (user-dirs.dirs)"
    command_template: "test -f \"${XDG_CONFIG_HOME:-$HOME/.config}/user-dirs.dirs\""
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]
  - id: "esc-006"
    descripcion: "Validar permisos restrictivos de XDG_RUNTIME_DIR (debe ser 0700 del usuario)"
    command_template: "test \"$(stat -c '%a %u' \"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}\" 2>/dev/null)\" = \"700 $(id -u)\""
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]

triggers:
  keywords: ["escritorio", "desktop", "xdg", "wayland", "x11", "portal", "freedesktop"]
  contextos: ["post-update", "cron", "pre-deploy"]
  cron: "0 9 * * 1"
---

# Objetivo

Verificar la postura del entorno de escritorio del host: presencia y consistencia
de los directorios XDG base, entorno de escritorio detectado, tipo de sesión
gráfica (Wayland/X11), `xdg-desktop-portal` activo y permisos de
`XDG_RUNTIME_DIR`. Emite informe y propuesta sin modificar configuración de
escritorio (read-only).

# Cuándo activar

| Si... | Entonces... |
|---|---|
| Auditoría de sesión de usuario | Invocar `--mode=sandbox` · XDG dirs + portal |
| Migración Wayland/X11 | Confirmar session_type y portal activo |
| Hardening de sesión gráfica | Verificar permisos 0700 de XDG_RUNTIME_DIR |
| `target_tipo != 'host'` | Skill se salta con `skipped: not_applicable` |

# Uso · comentario encabezado (copiar al script)

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_linux-escritorio · v0.7.0 · 2026-06-20                 ║
# ║  Función: verificar postura del entorno de escritorio        ║
# ║  Variables entorno:                                          ║
# ║    XEK_SUDO            comando de escalada (default: sudo -A) ║
# ║    XDG_RUNTIME_DIR     base sandbox                          ║
# ║  Uso:                                                        ║
# ║    xek-linux-escritorio.sh --mode={dry-run|sandbox|real}    ║
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
# TODO: ejecutar los checks[] declarados en los 3 modos · read-only sobre entorno y D-Bus de usuario.
```

# Adaptador Python

```python
#!/usr/bin/env python3
"""XEK_linux-escritorio · adapter Python."""
import subprocess, sys, pathlib
script = pathlib.Path(__file__).with_name("xek-linux-escritorio.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-linux-escritorio.sh" "$@"
```

# Verificación end-to-end (smoke test)

```bash
./scripts/xek-linux-escritorio.sh --mode=dry-run && echo "PASS dry-run"
./scripts/xek-linux-escritorio.sh --mode=sandbox
echo "exit=$?"
```

# Riesgos y mitigación

| Riesgo | Mitigación |
|---|---|
| Host headless / sin sesión gráfica | `esc-001` reporta ausencia · severidad info, no aborta |
| D-Bus de usuario no accesible en cron | Detectar `DBUS_SESSION_BUS_ADDRESS`; degradar a skip |
| Falso negativo de portal sin systemd --user | Doble vía: `busctl` y `systemctl --user` |
| Permisos laxos en XDG_RUNTIME_DIR | `esc-006` exige 0700 del propio uid · severidad alta |

# Bitácora evolución

- **v0.0.1** (2026-05-20) — bootstrap stub.
- **v0.6.1** (2026-05-22) — degradado a stub (deuda v0.6).
- **v0.7.0** (2026-06-20) — stub→borrador: fuentes reales, escalada `${XEK_SUDO}`, checks[] read-only.

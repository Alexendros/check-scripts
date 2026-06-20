---
slug: XEK_linux-peripherals
ambito: Linux
maestria_funcional: revisor
estado: borrador
version: 0.7.1
mejoras_ultima_edicion:
  - { v: 0.6.0, fecha: 2026-05-21, cambio: "fusión XEK_linux-audio + XEK_linux-bluetooth en una skill que recorre bus D-Bus único" }
  - { v: 0.7.0, fecha: 2026-06-20, cambio: "stub→borrador · fuentes reales (udev/input kernel docs), escalada R16 explícita, checks[] read-only firmware/input/USB" }
  - { v: 0.7.1, fecha: 2026-06-20, cambio: "runner real scripts/xek-linux-peripherals.sh: emite xek/finding@v1 (8 checks peripherals-001..008 (audio, grupos, pairings, bluetoothctl, pipewire, input, usb, firmware privilegiado en real); checks 001-005 refinados a predicados), gate real, shellcheck-clean, testado (tests/test_linux_peripherals.py) · SKILL.md deja de duplicar el bash (single source of truth)" }

objetivo: >
  Verificar postura de periféricos del host (audio PipeWire/PulseAudio/ALSA + Bluetooth BlueZ) mediante recorrido D-Bus unificado.

fuentes_externas:
  - { tipo: tool, nombre: "busctl",       version_min: "250",  licencia: "LGPL-2.1-or-later" }
  - { tipo: tool, nombre: "bluetoothctl", version_min: "5.70", licencia: "GPL-2.0-only" }
  - { tipo: tool, nombre: "pw-cli",       version_min: "1.0",  licencia: "MIT" }
  - { tipo: tool, nombre: "jq",           version_min: "1.7",  licencia: "MIT" }
conexiones_requeridas: []

precondiciones_runtime:
  binarios:
    - { nombre: "busctl",        version_min: "250", licencia: "LGPL-2.1-or-later", check_cmd: "busctl --version" }
    - { nombre: "bluetoothctl",  version_min: "5.70", licencia: "GPL-2.0-only",     check_cmd: "bluetoothctl --version" }
    - { nombre: "pw-cli",        version_min: "1.0", licencia: "MIT",               check_cmd: "pw-cli --version" }
    - { nombre: "jq",            version_min: "1.7", licencia: "MIT",               check_cmd: "jq --version" }
  capabilities:
    - { cap: "CAP_NONE", razon: "skill ejecuta como usuario · bus D-Bus de sesión" }
  paths_lectura:
    - "/run/user/$UID/pulse/"
    - "/var/lib/bluetooth/"
    - "/sys/class/bluetooth/"
  paths_escritura:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-peripherals/"
  conexiones: []

escalada_privilegio:
  comando_template: "${XEK_SUDO:-sudo -A}"
  cuando_aplica: "lectura de logs de firmware del kernel (dmesg) en hosts con dmesg restringido; sin escalada se omite el check de firmware y se reporta skipped"

referencias_canonicas:
  - { tipo: doc_oficial, url: "https://www.freedesktop.org/software/systemd/man/latest/udev.html", cobertura: "udev · enumeración y gestión de dispositivos" }
  - { tipo: doc_oficial, url: "https://www.kernel.org/doc/html/latest/input/input.html", cobertura: "Linux kernel input subsystem" }
  - { tipo: doc_oficial, url: "https://docs.pipewire.org/", cobertura: "PipeWire API y modelo de objetos" }
  - { tipo: doc_oficial, url: "https://www.bluez.org/", cobertura: "BlueZ stack" }
  - { tipo: estandar, url: "https://www.cisecurity.org/benchmark/distribution_independent_linux", cobertura: "CIS Distribution Independent Linux · 3.x services hardening" }
verificar_referencias:
  cuando: "antes de bump de version_min de busctl o bluetoothctl"
  como: "consultar release notes; rechazar si cambia interfaz D-Bus"

checks:
  - id: "peripherals-001"
    descripcion: "Listar servidor audio activo (PipeWire | PulseAudio | ALSA-only)"
    command_template: "pw-cli info 0 >/dev/null 2>&1 || pactl info >/dev/null 2>&1 || aplay -l >/dev/null 2>&1"
    expected_exit: 0
    severity_default: info
    solo_modo: [dry-run, sandbox, real]
  - id: "peripherals-002"
    descripcion: "Verificar usuario en grupos audio + bluetooth"
    command_template: "groups 2>/dev/null | grep -qE '\\b(audio|bluetooth)\\b'"
    expected_exit: 0
    severity_default: info
    solo_modo: [dry-run, sandbox, real]
  - id: "peripherals-003"
    descripcion: "Bluetooth pairings persistentes que aún no se han usado en 90 días"
    command_template: "test \"$(find /var/lib/bluetooth -name info -mtime +90 2>/dev/null | wc -l)\" -eq 0"
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]
  - id: "peripherals-004"
    descripcion: "Adaptadores Bluetooth con firmware desactualizado conocido"
    command_template: "command -v bluetoothctl >/dev/null 2>&1"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "peripherals-005"
    descripcion: "PipeWire sample rate fijo vs adaptativo"
    command_template: "pw-cli enum-params 0 Props 2>/dev/null | grep -qE 'rate|quantum'"
    expected_exit: 0
    severity_default: info
    solo_modo: [sandbox, real]
  - id: "peripherals-006"
    descripcion: "Dispositivos de entrada (input) enumerados por el kernel"
    command_template: "test -s /proc/bus/input/devices"
    expected_exit: 0
    severity_default: info
    solo_modo: [dry-run, sandbox, real]
  - id: "peripherals-007"
    descripcion: "Dispositivos USB enumerados vía sysfs (read-only)"
    command_template: "test \"$(ls -d /sys/bus/usb/devices/*/ 2>/dev/null | wc -l)\" -gt 0"
    expected_exit: 0
    severity_default: info
    solo_modo: [sandbox, real]
  - id: "peripherals-008"
    descripcion: "Sin firmware solicitado por el kernel y no cargado (privilegiado · skip sin escalada)"
    command_template: "${XEK_SUDO:-sudo -A} dmesg 2>/dev/null | grep -i 'firmware' | grep -iqv 'failed\\|missing' || echo no-priv-or-clean"
    expected_exit: 0
    severity_default: medium
    solo_modo: [real]

areas_criticas:
  permisos_user:
    - "lectura /run/user/$UID/pulse/, /var/lib/bluetooth/, /sys/class/bluetooth/"
  fhs_tocados:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-peripherals/"
  visual_secrets:
    - "MAC addresses Bluetooth · hash en logs públicos"
  zonas_ocultas:
    - "/var/lib/bluetooth/<adapter-MAC>/<device-MAC>/info (claves de pairing)"

modos_ejecucion:
  dry-run:
    proposito: "Validar precondiciones + listar checks que aplican."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · preflight + lista checks · exit 0|2"
  sandbox:
    proposito: "Capturar snapshot D-Bus + sysfs en sandbox."
    aislamiento: "directorio bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-peripherals/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-peripherals/"
    efectos_red: "ninguno"
    salida: "findings.json · exit 0|1"
  real:
    proposito: "Ejecutar contra host real · genera informe + propuesta."
    precondicion: "sandbox del mismo host ha pasado en últimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_linux-peripherals/<fecha>/"
    efectos_red: "ninguno"
    salida: "informe.md + findings.json + propuesta_#N"
gate_promocion:
  regla: "modo N+1 solo si modo N exit 0|1"
  override: "--override-gate=AUTO_<timestamp ±60s>"

depende_de:
  - { slug: XEK_detecta-stack, modo: sandbox, obligatoria: true,
      campos_esperados: ["target_tipo", "host_huellas.audio_server", "host_huellas.bluetooth"],
      razon: "necesita huellas del servidor audio y stack bluetooth" }
contrato_invocacion:
  modo_subordinado: sandbox
  promocion_real: solo_operador
  consolidacion: "json · schema xek/finding@v1 · merge por check_id"

aplicabilidad:
  cuando:
    - "manifest.target_tipo == 'host'"
    - "manifest.host_huellas.audio_server != 'none' or manifest.host_huellas.bluetooth == 'bluez'"
  prioridad: media
  coste_relativo: 2

migracion_runtime:
  bash:   scripts/xek-linux-peripherals.sh
  python: scripts/xek-linux-peripherals.py
  zsh:    scripts/xek-linux-peripherals.zsh

triggers:
  keywords: ["audio", "bluetooth", "pipewire", "pulseaudio", "bluez", "perifericos", "peripherals"]
  contextos: ["post-update", "cron"]
  cron: "0 8 * * 0"
---

# Objetivo

Verificar postura unificada de periféricos del host (audio + Bluetooth)
recorriendo el bus D-Bus de sesión y `/sys`. Sustituye a las skills
separadas `XEK_linux-audio` y `XEK_linux-bluetooth` (fusión v0.6 por
argumento de antítesis · ronda 001).

# Uso · comentario encabezado (copiar al script)

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_linux-peripherals · v0.7.0 · 2026-06-20                 ║
# ║  Función: verificar postura de periféricos (audio/BT/input/USB)║
# ║  Variables entorno:                                          ║
# ║    XEK_SUDO            comando de escalada (default: sudo -A) ║
# ║    XDG_RUNTIME_DIR     base sandbox                          ║
# ║  Uso:                                                        ║
# ║    xek-linux-peripherals.sh --mode={dry-run|sandbox|real}   ║
# ║  Exit codes:                                                ║
# ║    0=clean · 1=findings · 2=config · 3=missing-mode · 4=ill ║
# ╚══════════════════════════════════════════════════════════════╝
```

# Implementación referencia (bash · fuente de verdad)

La implementación ejecutable y **única fuente de verdad** es
[`scripts/xek-linux-peripherals.sh`](scripts/xek-linux-peripherals.sh) (v0.7.1, shellcheck-clean, cubierto por
`tests/test_linux_peripherals.py`). Emite `xek/finding@v1`: un finding por cada check que
falla, con `severity` y `remediation`. Los checks privilegiados
(`solo_modo:[real]`) degradan a informativo sin escalada. El frontmatter
`checks[]` es la especificación declarativa; el script no se duplica aquí.

Firma y contrato:

```bash
xek-linux-peripherals.sh --mode {dry-run|sandbox|real} [--override-gate=AUTO_<ts>]
# exit: 0 sin findings · 1 findings · 2 config · 3 falta --mode · 4 ill-call
```

# Adaptador Python

```python
#!/usr/bin/env python3
"""XEK_linux-peripherals · adapter Python."""
import subprocess, sys, pathlib
script = pathlib.Path(__file__).with_name("xek-linux-peripherals.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-linux-peripherals.sh" "$@"
```

# Verificación end-to-end (smoke test)

```bash
./scripts/xek-linux-peripherals.sh --mode=dry-run && echo "PASS dry-run"
./scripts/xek-linux-peripherals.sh --mode=sandbox
echo "exit=$?"
```

# Riesgos y mitigación

| Riesgo | Mitigación |
|---|---|
| `dmesg` restringido (kernel.dmesg_restrict) | Check firmware privilegiado · skip+report sin escalada |
| MAC Bluetooth en logs públicos | Hash de MAC en informe; nunca volcar crudo |
| Host headless sin audio/BT | `aplicabilidad` filtra antes de invocar |
| Claves de pairing en /var/lib/bluetooth | Reportar presencia; nunca imprimir contenido |

# Bitácora evolución

- **v0.6.0** (2026-05-21) — fusión declarada · estructura v0.6 con checks[].
- **v0.7.0** (2026-06-20) — stub→borrador: fuentes reales, refs udev/input kernel, escalada `${XEK_SUDO}` explícita, checks input/USB/firmware read-only.

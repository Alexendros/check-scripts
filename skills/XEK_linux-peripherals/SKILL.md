---
slug: XEK_linux-peripherals
ambito: Linux
maestria_funcional: revisor
estado: stub
version: 0.6.0
mejoras_ultima_edicion:
  - { v: 0.6.0, fecha: 2026-05-21, cambio: "fusión XEK_linux-audio + XEK_linux-bluetooth en una skill que recorre bus D-Bus único" }

objetivo: >
  Verificar postura de periféricos del host (audio PipeWire/PulseAudio/ALSA + Bluetooth BlueZ) mediante recorrido D-Bus unificado.

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

escalada:
  adapter: "${XEK_SUDO:-sudo -A}"
  capabilities_requeridas: []
  fallback_sin_escalada: "no aplica · skill sin privilegios"
  registrar_en_finding: true

referencias_canonicas:
  - { tipo: doc_oficial, url: "https://docs.pipewire.org/", cobertura: "PipeWire API y modelo de objetos" }
  - { tipo: doc_oficial, url: "https://www.bluez.org/", cobertura: "BlueZ stack" }
  - { tipo: doc_oficial, url: "https://www.freedesktop.org/wiki/Software/dbus/", cobertura: "D-Bus IPC bus" }
  - { tipo: estandar, url: "https://www.cisecurity.org/benchmark/distribution_independent_linux", cobertura: "CIS Distribution Independent Linux · 3.x services hardening" }
verificar_referencias:
  cuando: "antes de bump de version_min de busctl o bluetoothctl"
  como: "consultar release notes; rechazar si cambia interfaz D-Bus"

checks:
  - id: "peripherals-001"
    descripcion: "Listar servidor audio activo (PipeWire | PulseAudio | ALSA-only)"
    command_template: "pw-cli info 0 2>/dev/null | head -5 || pactl info 2>/dev/null | head -5 || aplay -L 2>/dev/null | head -3 || echo none"
    expected_exit: 0
    severity_default: info
    solo_modo: [dry-run, sandbox, real]
  - id: "peripherals-002"
    descripcion: "Verificar usuario en grupos audio + bluetooth"
    command_template: "groups | grep -Eo 'audio|bluetooth' | sort -u"
    expected_exit: 0
    severity_default: info
    solo_modo: [dry-run, sandbox, real]
  - id: "peripherals-003"
    descripcion: "Bluetooth pairings persistentes que aún no se han usado en 90 días"
    command_template: "find /var/lib/bluetooth -name info -mtime +90 2>/dev/null | wc -l"
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]
  - id: "peripherals-004"
    descripcion: "Adaptadores Bluetooth con firmware desactualizado conocido"
    command_template: "bluetoothctl --version && bluetoothctl list 2>/dev/null"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "peripherals-005"
    descripcion: "PipeWire sample rate fijo vs adaptativo"
    command_template: "pw-cli enum-params 0 Props 2>/dev/null | grep -E 'rate|quantum' | head -5"
    expected_exit: 0
    severity_default: info
    solo_modo: [sandbox, real]

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

# Estado

**Stub bootstrap v0.6.0** — frontmatter declarativo presente con `checks[]`
tipados y `precondiciones_runtime` unificado. Implementación bash
pendiente de Ronda 3b.

# Bitácora evolución

- **v0.6.0** (2026-05-21) — fusión declarada · estructura v0.6 con checks[].

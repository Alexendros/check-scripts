---
slug: XEK_linux-paquetes
ambito: Linux
maestria_funcional: revisor
estado: borrador
version: 0.7.0
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub · pendiente implementación" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "degradado borrador→stub per síntesis Ronda 002 (commit deuda v0.6)" }
  - { v: 0.7.0, fecha: 2026-06-20, cambio: "stub→borrador · fuentes reales, escalada R16, checks[] read-only sobre gestor de paquetes" }

objetivo: >
  Verificar la postura del gestor de paquetes del host: repositorios firmados y de
  confianza, paquetes huérfanos o rotos, paquetes retenidos (held) y ausencia de
  PPAs/repos no confiables. Read-only.

fuentes_externas:
  - { tipo: tool, nombre: "apt",        version_min: "2.6",  licencia: "GPL-2.0-or-later" }
  - { tipo: tool, nombre: "dpkg",       version_min: "1.21", licencia: "GPL-2.0-or-later" }
  - { tipo: tool, nombre: "apt-key",    version_min: "2.6",  licencia: "GPL-2.0-or-later" }
  - { tipo: tool, nombre: "pacman",     version_min: "6.0",  licencia: "GPL-2.0-or-later" }
conexiones_requeridas: []

referencias_canonicas:
  - { tipo: doc_oficial, url: "https://wiki.debian.org/Apt", cobertura: "APT · repos, firmas GPG y mantenimiento de paquetes" }
  - { tipo: doc_oficial, url: "https://wiki.archlinux.org/title/Pacman", cobertura: "Pacman · repos firmados y base de datos local" }
  - { tipo: estandar,    url: "https://www.cisecurity.org/benchmark/distribution_independent_linux", cobertura: "CIS · gestión y verificación de paquetes" }
verificar_referencias:
  cuando: "antes de cada bump de version_min de apt/dpkg/pacman"
  como: "consultar man pages oficiales; rechazar bump si cambia la salida de `apt-mark showhold`/`pacman -Qm`"

areas_criticas:
  permisos_user:
    - "dpkg -l, apt-mark showhold, pacman -Q sin escalada"
    - "apt-get check requiere escalada · privilegiado"
  fhs_tocados:
    - "/etc/apt/sources.list, /etc/apt/sources.list.d/ (solo lectura)"
    - "/etc/pacman.conf, /etc/pacman.d/ (solo lectura)"
    - "/var/lib/dpkg/, /var/lib/pacman/ (solo lectura)"
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-paquetes/"
  visual_secrets:
    - "tokens de repos privados en sources.list.d · no imprimir URLs con credenciales"
  zonas_ocultas:
    - "/etc/apt/trusted.gpg.d/, /etc/pacman.d/gnupg/ (claves de firma · listar ids, nunca volcar)"

modos_ejecucion:
  dry-run:
    proposito: "Detectar gestor de paquetes presente y tools disponibles sin consultar la base de datos."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · gestor detectado + tools · exit 0"
  sandbox:
    proposito: "Capturar snapshot de postura del gestor de paquetes en sandbox."
    aislamiento: "directorio bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-paquetes/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-paquetes/"
    efectos_red: "ninguno"
    salida: "findings.json · exit 0/1 según postura"
  real:
    proposito: "Ejecutar contra host real · genera informe + propuesta_#N. Nunca instala, elimina ni actualiza paquetes."
    precondicion: "sandbox del mismo host ha pasado en las últimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_linux-paquetes/<fecha>/"
    efectos_red: "ninguno"
    salida: "informe.md + findings.json + propuesta_#N"
gate_promocion:
  regla: "modo N+1 solo si modo N exit 0|1 con plan"
  override: "--override-gate=AUTO_<timestamp ±60s>"

escalada_privilegio:
  comando_template: "${XEK_SUDO:-sudo -A}"
  cuando_aplica: "verificación de coherencia de base de datos APT (apt-get check) necesita escalada; sin escalada se omite ese check y se reporta skipped"

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
  coste_relativo: 2

migracion_runtime:
  bash:   scripts/xek-linux-paquetes.sh
  python: scripts/xek-linux-paquetes.py
  zsh:    scripts/xek-linux-paquetes.zsh

checks:
  - id: "pkg-001"
    descripcion: "Detectar gestor de paquetes presente (apt/dpkg o pacman)"
    command_template: "command -v apt-get >/dev/null || command -v pacman >/dev/null"
    expected_exit: 0
    severity_default: info
    solo_modo: [dry-run, sandbox, real]
  - id: "pkg-002"
    descripcion: "Verificar ausencia de paquetes rotos o medio-instalados (dpkg)"
    command_template: "test -z \"$(dpkg -l 2>/dev/null | awk '/^.[^ic] /{print}')\""
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "pkg-003"
    descripcion: "Detectar paquetes retenidos (held) que bloquean actualizaciones de seguridad"
    command_template: "test -z \"$(apt-mark showhold 2>/dev/null)\""
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "pkg-004"
    descripcion: "Detectar repos/PPAs de terceros no oficiales en sources.list.d"
    command_template: "test -z \"$(grep -rhE '^deb ' /etc/apt/sources.list.d/ 2>/dev/null | grep -iE 'ppa\\.launchpad|ppa\\.launchpadcontent')\""
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "pkg-005"
    descripcion: "Detectar paquetes foráneos (no provenientes de repos oficiales · pacman)"
    command_template: "test \"$(pacman -Qm 2>/dev/null | wc -l)\" -eq 0"
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]
  - id: "pkg-006"
    descripcion: "Verificar coherencia de la base de datos APT (privilegiado · skip sin escalada)"
    command_template: "${XEK_SUDO:-sudo -A} apt-get check >/dev/null 2>&1 || echo no-priv-or-absent"
    expected_exit: 0
    severity_default: high
    solo_modo: [real]

triggers:
  keywords: ["paquetes", "apt", "dpkg", "pacman", "repos", "gpg", "held", "orphans"]
  contextos: ["post-update", "pre-deploy", "cron"]
  cron: "0 5 * * *"
---

# Objetivo

Verificar la postura del gestor de paquetes del host: repositorios firmados y de
confianza, ausencia de paquetes rotos o huérfanos, paquetes retenidos (`held`),
y ausencia de PPAs/repos de terceros no confiables. Emite informe y propuesta
sin instalar, eliminar ni actualizar paquetes (read-only).

# Cuándo activar

| Si... | Entonces... |
|---|---|
| Tras una actualización del sistema | Invocar `--mode=sandbox` · detectar paquetes rotos/held |
| Auditoría de cadena de suministro | Revisar repos firmados y PPAs de terceros |
| Antes de un despliegue | Confirmar base de datos de paquetes coherente |
| `target_tipo != 'host'` | Skill se salta con `skipped: not_applicable` |

# Uso · comentario encabezado (copiar al script)

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_linux-paquetes · v0.7.0 · 2026-06-20                    ║
# ║  Función: verificar postura del gestor de paquetes del host  ║
# ║  Variables entorno:                                          ║
# ║    XEK_SUDO            comando de escalada (default: sudo -A) ║
# ║    XDG_RUNTIME_DIR     base sandbox                          ║
# ║  Uso:                                                        ║
# ║    xek-linux-paquetes.sh --mode={dry-run|sandbox|real}      ║
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
# TODO: ejecutar los checks[] declarados en los 3 modos · read-only sobre la base de paquetes.
```

# Adaptador Python

```python
#!/usr/bin/env python3
"""XEK_linux-paquetes · adapter Python."""
import subprocess, sys, pathlib
script = pathlib.Path(__file__).with_name("xek-linux-paquetes.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-linux-paquetes.sh" "$@"
```

# Verificación end-to-end (smoke test)

```bash
./scripts/xek-linux-paquetes.sh --mode=dry-run && echo "PASS dry-run"
./scripts/xek-linux-paquetes.sh --mode=sandbox
echo "exit=$?"
```

# Riesgos y mitigación

| Riesgo | Mitigación |
|---|---|
| `apt-get check` requiere escalada | Check privilegiado marcado · skip+report sin escalada |
| sources.list.d con token en URL | Reportar presencia; nunca imprimir URL con credencial |
| Host con gestor distinto (dnf/zypper) | Reportar `not_applicable` por gestor no soportado en v0.7 |
| Paquetes foráneos legítimos (AUR) | Severidad baja · propuesta enumera, no marca como fallo duro |

# Bitácora evolución

- **v0.0.1** (2026-05-20) — bootstrap stub.
- **v0.6.1** (2026-05-22) — degradado a stub (deuda v0.6).
- **v0.7.0** (2026-06-20) — stub→borrador: fuentes reales (apt/dpkg/pacman), escalada `${XEK_SUDO}`, checks[] read-only.

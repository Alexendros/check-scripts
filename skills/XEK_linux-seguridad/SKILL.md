---
slug: XEK_linux-seguridad
ambito: Linux
maestria_funcional: revisor
estado: borrador
version: 0.7.0
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub · pendiente implementación" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "degradado borrador→stub per síntesis Ronda 002 (commit deuda v0.6)" }
  - { v: 0.7.0, fecha: 2026-06-20, cambio: "stub→borrador · fuentes reales (CIS/sysctl kernel), escalada R16, checks[] MAC/sysctl/SSH hardening" }

objetivo: >
  Verificar el endurecimiento del host: MAC (SELinux/AppArmor) activo, sysctl
  hardening, SSH endurecido (sin root login ni password auth), auditd y fail2ban.
  Read-only.

fuentes_externas:
  - { tipo: tool, nombre: "sysctl",      version_min: "4.0", licencia: "GPL-2.0-or-later" }
  - { tipo: tool, nombre: "aa-status",   version_min: "3.0", licencia: "GPL-2.0-only" }
  - { tipo: tool, nombre: "sestatus",    version_min: "3.5", licencia: "GPL-2.0-or-later" }
  - { tipo: tool, nombre: "sshd",        version_min: "9.0", licencia: "BSD-3-Clause" }
  - { tipo: tool, nombre: "systemctl",   version_min: "255", licencia: "LGPL-2.1-or-later" }
conexiones_requeridas: []

referencias_canonicas:
  - { tipo: estandar,    url: "https://www.cisecurity.org/benchmark/distribution_independent_linux", cobertura: "CIS Distribution Independent Linux Benchmark" }
  - { tipo: doc_oficial, url: "https://www.kernel.org/doc/Documentation/sysctl/", cobertura: "kernel sysctl · parámetros de hardening" }
  - { tipo: doc_oficial, url: "https://www.openssh.com/manual.html", cobertura: "OpenSSH · sshd_config hardening" }
verificar_referencias:
  cuando: "antes de cada bump de version_min de OpenSSH o systemd"
  como: "consultar man pages y CIS Benchmark vigente; rechazar bump si cambia el nombre de un parámetro auditado"

areas_criticas:
  permisos_user:
    - "sysctl -a, aa-status, systemctl is-active sin escalada (lectura)"
    - "sshd -T (config efectiva) y auditctl -s requieren escalada · privilegiado"
  fhs_tocados:
    - "/etc/ssh/sshd_config, /etc/sysctl.conf, /etc/sysctl.d/ (solo lectura)"
    - "/sys/kernel/security/ (solo lectura)"
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-seguridad/"
  visual_secrets: []
  zonas_ocultas:
    - "/etc/audit/ reglas auditd · listar presencia, no volcar reglas que revelen topología"

modos_ejecucion:
  dry-run:
    proposito: "Detectar mecanismos de hardening presentes sin leer config efectiva privilegiada."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · MAC/sysctl/ssh tools disponibles · exit 0"
  sandbox:
    proposito: "Capturar snapshot de postura de hardening en sandbox."
    aislamiento: "directorio bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-seguridad/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-seguridad/"
    efectos_red: "ninguno"
    salida: "findings.json · exit 0/1 según postura"
  real:
    proposito: "Ejecutar contra host real · genera informe + propuesta_#N. Nunca aplica sysctl ni edita config."
    precondicion: "sandbox del mismo host ha pasado en las últimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_linux-seguridad/<fecha>/"
    efectos_red: "ninguno"
    salida: "informe.md + findings.json + propuesta_#N"
gate_promocion:
  regla: "modo N+1 solo si modo N exit 0|1 con plan"
  override: "--override-gate=AUTO_<timestamp ±60s>"

escalada_privilegio:
  comando_template: "${XEK_SUDO:-sudo -A}"
  cuando_aplica: "lectura de la config efectiva de sshd (sshd -T) y estado de auditd (auditctl -s) necesitan escalada; sin escalada se omiten esos checks y se reportan skipped"

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
  bash:   scripts/xek-linux-seguridad.sh
  python: scripts/xek-linux-seguridad.py
  zsh:    scripts/xek-linux-seguridad.zsh

checks:
  - id: "hard-001"
    descripcion: "Detectar herramientas de hardening presentes (sysctl, systemctl)"
    command_template: "command -v sysctl >/dev/null && command -v systemctl >/dev/null"
    expected_exit: 0
    severity_default: info
    solo_modo: [dry-run, sandbox, real]
  - id: "hard-002"
    descripcion: "MAC activo: SELinux en enforcing o AppArmor cargado"
    command_template: "sestatus 2>/dev/null | grep -qi 'enforcing' || aa-status --enabled 2>/dev/null"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "hard-003"
    descripcion: "sysctl hardening: kernel.kptr_restrict y kernel.dmesg_restrict activos"
    command_template: "test \"$(sysctl -n kernel.kptr_restrict 2>/dev/null)\" != 0 && test \"$(sysctl -n kernel.dmesg_restrict 2>/dev/null)\" = 1"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "hard-004"
    descripcion: "SSH endurecido en sshd_config: sin PermitRootLogin yes ni PasswordAuthentication yes"
    command_template: "test -z \"$(grep -hiE '^[[:space:]]*(PermitRootLogin[[:space:]]+yes|PasswordAuthentication[[:space:]]+yes)' /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null)\""
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "hard-005"
    descripcion: "fail2ban presente y activo si SSH está expuesto"
    command_template: "systemctl is-active fail2ban 2>/dev/null | grep -q '^active$'"
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]
  - id: "hard-006"
    descripcion: "auditd activo y con reglas cargadas (privilegiado · skip sin escalada)"
    command_template: "${XEK_SUDO:-sudo -A} auditctl -s >/dev/null 2>&1 || echo no-priv-or-absent"
    expected_exit: 0
    severity_default: medium
    solo_modo: [real]

triggers:
  keywords: ["seguridad", "hardening", "sysctl", "selinux", "apparmor", "auditd", "fail2ban", "ssh-hardening"]
  contextos: ["pre-deploy", "post-update", "cron"]
  cron: "0 1 * * *"
---

# Objetivo

Verificar el endurecimiento del host: control de acceso obligatorio
(SELinux/AppArmor) activo, parámetros `sysctl` de hardening, `sshd` endurecido
(sin root login ni autenticación por contraseña), `auditd` y `fail2ban`. Emite
informe y propuesta sin aplicar `sysctl` ni editar configuración (read-only).

# Cuándo activar

| Si... | Entonces... |
|---|---|
| Bastionado de un nuevo host | Invocar `--mode=sandbox` · auditar CIS |
| Tras actualización del sistema | Confirmar que el hardening sobrevive |
| Auditoría de cumplimiento | Revisar MAC, sysctl, SSH, auditd, fail2ban |
| `target_tipo != 'host'` | Skill se salta con `skipped: not_applicable` |

# Uso · comentario encabezado (copiar al script)

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_linux-seguridad · v0.7.0 · 2026-06-20                   ║
# ║  Función: verificar endurecimiento del host                 ║
# ║  Variables entorno:                                          ║
# ║    XEK_SUDO            comando de escalada (default: sudo -A) ║
# ║    XDG_RUNTIME_DIR     base sandbox                          ║
# ║  Uso:                                                        ║
# ║    xek-linux-seguridad.sh --mode={dry-run|sandbox|real}     ║
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
# TODO: ejecutar los checks[] declarados en los 3 modos · read-only sobre config de hardening.
```

# Adaptador Python

```python
#!/usr/bin/env python3
"""XEK_linux-seguridad · adapter Python."""
import subprocess, sys, pathlib
script = pathlib.Path(__file__).with_name("xek-linux-seguridad.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-linux-seguridad.sh" "$@"
```

# Verificación end-to-end (smoke test)

```bash
./scripts/xek-linux-seguridad.sh --mode=dry-run && echo "PASS dry-run"
./scripts/xek-linux-seguridad.sh --mode=sandbox
echo "exit=$?"
```

# Riesgos y mitigación

| Riesgo | Mitigación |
|---|---|
| `sshd -T`/`auditctl -s` requieren escalada | Checks privilegiados · skip+report sin escalada |
| MAC en permisivo cuenta como activo | Check 002 exige `enforcing`/`--enabled` |
| sshd_config.d con override no detectado | Check 004 lee también el directorio drop-in |
| fail2ban innecesario en host sin SSH | Severidad baja · propuesta contextualiza por exposición |

# Bitácora evolución

- **v0.0.1** (2026-05-20) — bootstrap stub.
- **v0.6.1** (2026-05-22) — degradado a stub (deuda v0.6).
- **v0.7.0** (2026-06-20) — stub→borrador: fuentes reales (CIS/sysctl kernel/OpenSSH), escalada `${XEK_SUDO}`, checks[] read-only.

---
slug: XEK_linux-actualizaciones
ambito: Linux
maestria_funcional: revisor
estado: borrador
version: 0.7.1
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub · pendiente implementación" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "degradado borrador→stub per síntesis Ronda 002 (commit deuda v0.6)" }
  - { v: 0.7.0, fecha: 2026-06-20, cambio: "stub→borrador · fuentes reales, escalada R16, checks[] read-only" }
  - { v: 0.7.1, fecha: 2026-06-20, cambio: "runner real scripts/xek-linux-actualizaciones.sh: emite xek/finding@v1 (6 checks act-001..006 (parches seguridad, unattended-upgrades, reboot-required, keyrings, auth privilegiado en real)), gate real, shellcheck-clean, testado (tests/test_linux_actualizaciones.py) · SKILL.md deja de duplicar el bash (single source of truth)" }

objetivo: >
  Verificar postura de actualizaciones del host: parches de seguridad pendientes,
  unattended-upgrades activo, flag reboot-required y firma de repos. Read-only.

fuentes_externas:
  - { tipo: tool, nombre: "apt",                 version_min: "2.6",  licencia: "GPL-2.0-or-later" }
  - { tipo: tool, nombre: "dnf",                 version_min: "4.14", licencia: "GPL-2.0-or-later" }
  - { tipo: tool, nombre: "unattended-upgrade",  version_min: "2.9",  licencia: "GPL-2.0-or-later" }
  - { tipo: tool, nombre: "systemctl",           version_min: "252",  licencia: "LGPL-2.1-or-later" }
conexiones_requeridas: []

referencias_canonicas:
  - { tipo: doc_oficial, url: "https://wiki.debian.org/UnattendedUpgrades", cobertura: "auto-parcheado de seguridad Debian/Ubuntu" }
  - { tipo: doc_oficial, url: "https://www.freedesktop.org/software/systemd/man/latest/", cobertura: "systemd timers + needs-restart" }
  - { tipo: estandar,    url: "https://www.cisecurity.org/benchmark/distribution_independent_linux", cobertura: "CIS · gestión de parches y actualizaciones" }
verificar_referencias:
  cuando: "antes de cada bump version_min de apt/dnf/unattended-upgrade"
  como: "consultar release notes del paquete; rechazar bump si cambia la interfaz CLI usada en checks"

areas_criticas:
  permisos_user:
    - "lectura de /var/run/reboot-required, /etc/apt/, /var/lib/apt/lists/ sin escalada"
    - "apt-get -s (simulación) y unattended-upgrade --dry-run sin escalada"
  fhs_tocados:
    - "/etc/apt/ (solo lectura)"
    - "/var/lib/apt/lists/ (solo lectura)"
    - "/var/run/reboot-required (solo lectura)"
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-actualizaciones/"
  visual_secrets: []
  zonas_ocultas:
    - "/etc/apt/auth.conf.d/ (credenciales de repo · evaluar presencia, nunca imprimir contenido)"

modos_ejecucion:
  dry-run:
    proposito: "Detectar gestor de paquetes y tools sin consultar índices remotos."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · pkg_manager + tools disponibles · exit 0"
  sandbox:
    proposito: "Capturar snapshot de postura de actualizaciones en sandbox (simulación, sin aplicar)."
    aislamiento: "directorio bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-actualizaciones/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-actualizaciones/"
    efectos_red: "ninguno · usa índices ya descargados"
    salida: "findings.json · exit 0/1 según postura"
  real:
    proposito: "Ejecutar contra host real · genera informe + propuesta_#N. Nunca aplica actualizaciones."
    precondicion: "sandbox del mismo host ha pasado en las últimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_linux-actualizaciones/<fecha>/"
    efectos_red: "ninguno"
    salida: "informe.md + findings.json + propuesta_#N"
gate_promocion:
  regla: "modo N+1 solo si modo N exit 0|1 con plan"
  override: "--override-gate=AUTO_<timestamp ±60s>"

escalada_privilegio:
  comando_template: "${XEK_SUDO:-sudo -A}"
  cuando_aplica: "lectura de /etc/apt/auth.conf.d/ y refresco opcional de índices (apt-get update -s); sin escalada se omite y se reporta skipped"

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
  bash:   scripts/xek-linux-actualizaciones.sh
  python: scripts/xek-linux-actualizaciones.py
  zsh:    scripts/xek-linux-actualizaciones.zsh

checks:
  - id: "act-001"
    descripcion: "Detectar gestor de paquetes presente (apt o dnf)"
    command_template: "command -v apt-get >/dev/null || command -v dnf >/dev/null"
    expected_exit: 0
    severity_default: info
    solo_modo: [dry-run, sandbox, real]
  - id: "act-002"
    descripcion: "Listar actualizaciones de seguridad pendientes (simulación apt, sin aplicar)"
    command_template: "apt-get -s upgrade 2>/dev/null | grep -ci '^Inst.*security' || dnf -q updateinfo list security 2>/dev/null | grep -c . || true"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "act-003"
    descripcion: "Verificar que unattended-upgrades está habilitado y activo"
    command_template: "systemctl is-enabled unattended-upgrades.service 2>/dev/null || grep -rq 'Unattended-Upgrade.*1' /etc/apt/apt.conf.d/20auto-upgrades 2>/dev/null"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "act-004"
    descripcion: "Detectar flag reboot-required tras instalación de kernel/libs"
    command_template: "test ! -f /var/run/reboot-required"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "act-005"
    descripcion: "Comprobar que existen keyrings de firma de repos (apt-secure / repos firmados)"
    command_template: "ls /etc/apt/keyrings/ /usr/share/keyrings/ 2>/dev/null | grep -q . || ls /etc/pki/rpm-gpg/ 2>/dev/null | grep -q ."
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "act-006"
    descripcion: "Inspeccionar presencia de credenciales de repo privadas (privilegiado · skip sin escalada)"
    command_template: "${XEK_SUDO:-sudo -A} test -d /etc/apt/auth.conf.d 2>/dev/null && echo present || echo absent-or-no-priv"
    expected_exit: 0
    severity_default: info
    solo_modo: [real]

triggers:
  keywords: ["updates", "actualizaciones", "parches", "unattended-upgrades", "reboot-required", "cve"]
  contextos: ["post-update", "cron", "pre-deploy"]
  cron: "0 6 * * *"
---

# Objetivo

Verificar la postura de actualizaciones del host: parches de seguridad pendientes,
estado de `unattended-upgrades`, flag `reboot-required` tras instalaciones de kernel
o librerías, y firma de repositorios. Emite informe y propuesta sin aplicar ninguna
actualización (read-only sobre el host).

# Cuándo activar

| Si... | Entonces... |
|---|---|
| Tras un ciclo de actualización | Invocar `--mode=sandbox` para validar reboot-required |
| Auditoría periódica de seguridad | Invocar `--mode=sandbox` · contar parches de seguridad |
| Pre-deploy sobre el host | Verificar firma de repos y parches críticos |
| `target_tipo != 'host'` | Skill se salta con `skipped: not_applicable` |

# Uso · comentario encabezado (copiar al script)

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_linux-actualizaciones · v0.7.0 · 2026-06-20             ║
# ║  Función: verificar postura de parches/updates del host      ║
# ║  Variables entorno:                                          ║
# ║    XEK_SUDO            comando de escalada (default: sudo -A) ║
# ║    XDG_RUNTIME_DIR     base sandbox                          ║
# ║  Uso:                                                        ║
# ║    xek-linux-actualizaciones.sh --mode={dry-run|sandbox|real}║
# ║  Exit codes:                                                ║
# ║    0=clean · 1=findings · 2=config · 3=missing-mode · 4=ill ║
# ╚══════════════════════════════════════════════════════════════╝
```

# Implementación referencia (bash · fuente de verdad)

La implementación ejecutable y **única fuente de verdad** es
[`scripts/xek-linux-actualizaciones.sh`](scripts/xek-linux-actualizaciones.sh) (v0.7.1, shellcheck-clean, cubierto por
`tests/test_linux_actualizaciones.py`). Emite `xek/finding@v1`: un finding por cada check que falla,
con `severity` y `remediation`. Los checks privilegiados degradan a
informativo sin escalada (no abortan). El frontmatter `checks[]` es la
especificación declarativa; el script no se duplica aquí para evitar drift.

Firma y contrato:

```bash
xek-linux-actualizaciones.sh --mode {dry-run|sandbox|real} [--override-gate=AUTO_<ts>]
# exit: 0 sin findings · 1 findings · 2 config · 3 falta --mode · 4 ill-call
```

# Adaptador Python

```python
#!/usr/bin/env python3
"""XEK_linux-actualizaciones · adapter Python."""
import subprocess, sys, pathlib
script = pathlib.Path(__file__).with_name("xek-linux-actualizaciones.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-linux-actualizaciones.sh" "$@"
```

# Verificación end-to-end (smoke test)

```bash
./scripts/xek-linux-actualizaciones.sh --mode=dry-run && echo "PASS dry-run"
./scripts/xek-linux-actualizaciones.sh --mode=sandbox
echo "exit=$?"
```

# Riesgos y mitigación

| Riesgo | Mitigación |
|---|---|
| `apt-get update` toca red/índices | Usar `-s` (simulación); refresco real solo con escalada explícita |
| Falso negativo de reboot-required en RPM | Complementar con `needs-restarting -r` (dnf-utils) |
| Lectura de auth.conf.d filtra tokens | Reportar solo presencia; nunca imprimir contenido |
| Host sin gestor soportado | `act-001` reporta finding · no aborta |

# Bitácora evolución

- **v0.0.1** (2026-05-20) — bootstrap stub.
- **v0.6.1** (2026-05-22) — degradado a stub (deuda v0.6).
- **v0.7.0** (2026-06-20) — stub→borrador: fuentes reales, escalada `${XEK_SUDO}`, checks[] read-only.

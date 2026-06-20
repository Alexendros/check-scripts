---
slug: XEK_linux-backup
ambito: Linux
maestria_funcional: revisor
estado: borrador
version: 0.7.1
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub · pendiente implementación" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "degradado borrador→stub per síntesis Ronda 002 (commit deuda v0.6)" }
  - { v: 0.7.0, fecha: 2026-06-20, cambio: "stub→borrador · fuentes reales, escalada R16, checks[] read-only" }
  - { v: 0.7.1, fecha: 2026-06-20, cambio: "runner real scripts/xek-linux-backup.sh: emite xek/finding@v1 (6 checks bkp-001..006 (herramienta, timer/cron, retención, snapshot, restore-test, offsite 3-2-1)), gate real, shellcheck-clean, testado (tests/test_linux_backup.py) · SKILL.md deja de duplicar el bash (single source of truth)" }

objetivo: >
  Verificar postura de copias de seguridad del host: herramienta presente, timer
  programado, política de retención, evidencia de restore-test y copia offsite (3-2-1).

fuentes_externas:
  - { tipo: tool, nombre: "restic",    version_min: "0.16", licencia: "BSD-2-Clause" }
  - { tipo: tool, nombre: "systemctl", version_min: "252",  licencia: "LGPL-2.1-or-later" }
  - { tipo: tool, nombre: "jq",        version_min: "1.7",  licencia: "MIT" }
conexiones_requeridas: []

referencias_canonicas:
  - { tipo: doc_oficial, url: "https://restic.readthedocs.io/", cobertura: "snapshots, forget/prune, check, restore" }
  - { tipo: doc_oficial, url: "https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html", cobertura: "programación de backups vía systemd timers" }
  - { tipo: estandar,    url: "https://www.cisecurity.org/benchmark/distribution_independent_linux", cobertura: "CIS · respaldo y recuperación (3-2-1)" }
verificar_referencias:
  cuando: "antes de cada bump version_min de restic"
  como: "consultar changelog restic; rechazar bump si cambia el formato de `snapshots --json`"

areas_criticas:
  permisos_user:
    - "ejecución de restic snapshots/stats como el usuario dueño del repo de backup"
    - "lectura de unit files systemd vía systemctl --user y de sistema"
  fhs_tocados:
    - "/etc/systemd/system/ y ~/.config/systemd/user/ (solo lectura · timers)"
    - "/etc/cron.d/, /etc/crontab (solo lectura)"
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-backup/"
  visual_secrets:
    - "RESTIC_PASSWORD / claves de repo · evaluar presencia en env o files, NUNCA imprimir"
  zonas_ocultas:
    - "contenido de los snapshots (no enumerar ficheros respaldados en el informe)"

modos_ejecucion:
  dry-run:
    proposito: "Detectar herramienta de backup y timers sin contactar el repositorio."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · backup_tool + timers detectados · exit 0"
  sandbox:
    proposito: "Capturar snapshot de postura de backup en sandbox (solo lectura del repo)."
    aislamiento: "directorio bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-backup/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-backup/"
    efectos_red: "permitido a backend de backup declarado (read-only · snapshots/stats)"
    salida: "findings.json · exit 0/1 según postura"
  real:
    proposito: "Ejecutar contra host real · genera informe + propuesta_#N. Nunca borra ni escribe en el repo."
    precondicion: "sandbox del mismo host ha pasado en las últimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_linux-backup/<fecha>/"
    efectos_red: "read-only al backend de backup"
    salida: "informe.md + findings.json + propuesta_#N"
gate_promocion:
  regla: "modo N+1 solo si modo N exit 0|1 con plan"
  override: "--override-gate=AUTO_<timestamp ±60s>"

escalada_privilegio:
  comando_template: "${XEK_SUDO:-sudo -A}"
  cuando_aplica: "lectura de timers/unit files de backup de sistema y de repos restic propiedad de root; sin escalada se omite el check y se reporta skipped"

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
  bash:   scripts/xek-linux-backup.sh
  python: scripts/xek-linux-backup.py
  zsh:    scripts/xek-linux-backup.zsh

checks:
  - id: "bkp-001"
    descripcion: "Detectar herramienta de backup presente (restic / borg / duplicity)"
    command_template: "command -v restic >/dev/null || command -v borg >/dev/null || command -v duplicity >/dev/null"
    expected_exit: 0
    severity_default: high
    solo_modo: [dry-run, sandbox, real]
  - id: "bkp-002"
    descripcion: "Verificar timer/cron programado para backup (systemd timer o entrada cron)"
    command_template: "systemctl list-timers --all 2>/dev/null | grep -qiE 'backup|restic|borg' || grep -rqiE 'restic|borg|duplicity|backup' /etc/cron.d /etc/crontab 2>/dev/null"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "bkp-003"
    descripcion: "Detectar política de retención declarada (forget --keep-* en unit/script)"
    command_template: "grep -rqE 'forget.*--keep-(daily|weekly|monthly)|--prune' /etc/systemd ~/.config/systemd /etc/cron.d 2>/dev/null"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "bkp-004"
    descripcion: "Comprobar existencia del último snapshot (restic snapshots, read-only)"
    command_template: "restic snapshots --json --latest 1 2>/dev/null | jq -e 'length > 0' >/dev/null"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "bkp-005"
    descripcion: "Buscar evidencia de restore-test (log o marca de verificación periódica)"
    command_template: "find /var/log ~/.local/state -maxdepth 3 \\( -iname '*restore*test*' -o -iname '*restic*check*' \\) 2>/dev/null | grep -q ."
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "bkp-006"
    descripcion: "Detectar segunda copia / offsite (más de un destino o backend remoto · 3-2-1)"
    command_template: "grep -rhoE 'RESTIC_REPOSITORY[0-9]?=[^ ]+|(s3|b2|sftp|rest|azure|gs):[^ ]+' /etc/systemd ~/.config/systemd /etc/environment 2>/dev/null | sort -u | grep -c . | grep -qvx 0"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]

triggers:
  keywords: ["backup", "restic", "snapshot", "retention", "restore", "offsite"]
  contextos: ["cron", "pre-deploy", "post-update"]
  cron: "0 5 * * 1"
---

# Objetivo

Verificar la postura de copias de seguridad del host: presencia de la herramienta
(restic/borg/duplicity), programación vía systemd timer o cron, política de
retención, existencia del último snapshot, evidencia de restore-test y existencia
de una segunda copia u offsite conforme al principio 3-2-1. Read-only sobre el
host y sobre el repositorio de backup.

# Cuándo activar

| Si... | Entonces... |
|---|---|
| Auditoría periódica de resiliencia | Invocar `--mode=sandbox` · validar snapshot + retención |
| Pre-deploy de cambio destructivo | Confirmar último snapshot presente |
| Revisión 3-2-1 | Verificar segunda copia / offsite |
| `target_tipo != 'host'` | Skill se salta con `skipped: not_applicable` |

# Uso · comentario encabezado (copiar al script)

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_linux-backup · v0.7.0 · 2026-06-20                      ║
# ║  Función: verificar postura de backup del host (3-2-1)       ║
# ║  Variables entorno:                                          ║
# ║    XEK_SUDO            comando de escalada (default: sudo -A) ║
# ║    XDG_RUNTIME_DIR     base sandbox                          ║
# ║  Uso:                                                        ║
# ║    xek-linux-backup.sh --mode={dry-run|sandbox|real}        ║
# ║  Exit codes:                                                ║
# ║    0=clean · 1=findings · 2=config · 3=missing-mode · 4=ill ║
# ╚══════════════════════════════════════════════════════════════╝
```

# Implementación referencia (bash · fuente de verdad)

La implementación ejecutable y **única fuente de verdad** es
[`scripts/xek-linux-backup.sh`](scripts/xek-linux-backup.sh) (v0.7.1, shellcheck-clean, cubierto por
`tests/test_linux_backup.py`). Emite `xek/finding@v1`: un finding por cada check que falla,
con `severity` y `remediation`. Los checks privilegiados degradan a
informativo sin escalada (no abortan). El frontmatter `checks[]` es la
especificación declarativa; el script no se duplica aquí para evitar drift.

Firma y contrato:

```bash
xek-linux-backup.sh --mode {dry-run|sandbox|real} [--override-gate=AUTO_<ts>]
# exit: 0 sin findings · 1 findings · 2 config · 3 falta --mode · 4 ill-call
```

# Adaptador Python

```python
#!/usr/bin/env python3
"""XEK_linux-backup · adapter Python."""
import subprocess, sys, pathlib
script = pathlib.Path(__file__).with_name("xek-linux-backup.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-linux-backup.sh" "$@"
```

# Verificación end-to-end (smoke test)

```bash
./scripts/xek-linux-backup.sh --mode=dry-run && echo "PASS dry-run"
./scripts/xek-linux-backup.sh --mode=sandbox
echo "exit=$?"
```

# Riesgos y mitigación

| Riesgo | Mitigación |
|---|---|
| `restic check` recorre todo el repo (coste alto) | En sandbox usar solo `snapshots`/`stats`; `check` queda para propuesta |
| RESTIC_PASSWORD expuesto en env | Reportar solo presencia; nunca imprimir valor |
| Repo de backup propiedad de root | Check marcado privilegiado · skip+report sin escalada |
| Falsa sensación de 3-2-1 con un solo backend | `bkp-006` exige ≥2 destinos distintos |

# Bitácora evolución

- **v0.0.1** (2026-05-20) — bootstrap stub.
- **v0.6.1** (2026-05-22) — degradado a stub (deuda v0.6).
- **v0.7.0** (2026-06-20) — stub→borrador: fuentes reales, escalada `${XEK_SUDO}`, checks[] read-only.

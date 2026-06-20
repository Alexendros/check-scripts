---
slug: XEK_linux-fs
ambito: Linux
maestria_funcional: revisor
estado: borrador
version: 0.7.1
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub · pendiente implementación" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "degradado borrador→stub per síntesis Ronda 002 (commit deuda v0.6)" }
  - { v: 0.7.0, fecha: 2026-06-20, cambio: "stub→borrador · fuentes reales, escalada R16, checks[] read-only" }
  - { v: 0.7.1, fecha: 2026-06-20, cambio: "runner real scripts/xek-linux-fs.sh: emite xek/finding@v1 (8 checks fs-001..006 (mount opts, uso disco, fstab, fstype, SMART privilegiado en real)), gate real, shellcheck-clean, testado (tests/test_linux_fs.py) · SKILL.md deja de duplicar el bash (single source of truth)" }

objetivo: >
  Verificar postura del sistema de ficheros del host: opciones de montaje, uso de
  disco frente a umbrales, salud SMART, coherencia de fstab y tipo de filesystem.

fuentes_externas:
  - { tipo: tool, nombre: "findmnt",   version_min: "2.38", licencia: "GPL-2.0-or-later" }
  - { tipo: tool, nombre: "df",        version_min: "9.1",  licencia: "GPL-3.0-or-later" }
  - { tipo: tool, nombre: "smartctl",  version_min: "7.3",  licencia: "GPL-2.0-or-later" }
conexiones_requeridas: []

referencias_canonicas:
  - { tipo: estandar,    url: "https://refspecs.linuxfoundation.org/FHS_3.0/fhs/index.html", cobertura: "Filesystem Hierarchy Standard 3.0" }
  - { tipo: doc_oficial, url: "https://www.freedesktop.org/software/systemd/man/latest/systemd.mount.html", cobertura: "montajes vía systemd · fstab" }
  - { tipo: estandar,    url: "https://www.cisecurity.org/benchmark/distribution_independent_linux", cobertura: "CIS · opciones de montaje y particiones" }
verificar_referencias:
  cuando: "antes de cada bump version_min de util-linux/smartmontools"
  como: "consultar man pages oficiales; rechazar bump si cambia la salida de `findmnt --json`/`smartctl -H`"

areas_criticas:
  permisos_user:
    - "findmnt, df y lectura de /etc/fstab sin escalada"
    - "smartctl -H requiere acceso a dispositivo de bloque · privilegiado"
  fhs_tocados:
    - "/etc/fstab (solo lectura)"
    - "/proc/mounts, /sys/block/ (solo lectura)"
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-fs/"
  visual_secrets:
    - "claves/passphrase en líneas crypttab adyacentes · no imprimir contenido sensible"
  zonas_ocultas:
    - "/dev/* dispositivos de bloque (inspeccionar salud · nunca escribir)"

modos_ejecucion:
  dry-run:
    proposito: "Enumerar montajes y filesystems sin consultar SMART ni dispositivos."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · mounts + fs_types · exit 0"
  sandbox:
    proposito: "Capturar snapshot de postura de filesystem en sandbox."
    aislamiento: "directorio bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-fs/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-fs/"
    efectos_red: "ninguno"
    salida: "findings.json · exit 0/1 según postura"
  real:
    proposito: "Ejecutar contra host real · genera informe + propuesta_#N. Nunca monta, formatea ni escribe."
    precondicion: "sandbox del mismo host ha pasado en las últimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_linux-fs/<fecha>/"
    efectos_red: "ninguno"
    salida: "informe.md + findings.json + propuesta_#N"
gate_promocion:
  regla: "modo N+1 solo si modo N exit 0|1 con plan"
  override: "--override-gate=AUTO_<timestamp ±60s>"

escalada_privilegio:
  comando_template: "${XEK_SUDO:-sudo -A}"
  cuando_aplica: "lectura de salud SMART (smartctl -H necesita acceso al dispositivo de bloque); sin escalada se omite el check SMART y se reporta skipped"

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
  bash:   scripts/xek-linux-fs.sh
  python: scripts/xek-linux-fs.py
  zsh:    scripts/xek-linux-fs.zsh

checks:
  - id: "fs-001"
    descripcion: "Detectar herramientas de inspección de filesystem presentes (findmnt, df)"
    command_template: "command -v findmnt >/dev/null && command -v df >/dev/null"
    expected_exit: 0
    severity_default: info
    solo_modo: [dry-run, sandbox, real]
  - id: "fs-002"
    descripcion: "Verificar opciones de montaje noatime/relatime en filesystems no temporales"
    command_template: "test -z \"$(findmnt -rno OPTIONS,FSTYPE / 2>/dev/null | grep -vE 'noatime|relatime')\""
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]
  - id: "fs-003"
    descripcion: "Comprobar uso de disco bajo umbral del 90% en todos los filesystems reales"
    command_template: "test -z \"$(df -P -x tmpfs -x devtmpfs -x squashfs 2>/dev/null | awk 'NR>1 && int($5) >= 90')\""
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "fs-004"
    descripcion: "Validar coherencia de fstab (todas las entradas montables se montan)"
    command_template: "findmnt --verify --verbose >/dev/null 2>&1"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "fs-005"
    descripcion: "Identificar el tipo de filesystem del root (ext4/xfs/btrfs/zfs)"
    command_template: "findmnt -rno FSTYPE / 2>/dev/null | grep -qE '^(ext4|xfs|btrfs|zfs|f2fs)$'"
    expected_exit: 0
    severity_default: info
    solo_modo: [sandbox, real]
  - id: "fs-006"
    descripcion: "Leer salud SMART del primer disco (privilegiado · skip sin escalada)"
    command_template: "${XEK_SUDO:-sudo -A} smartctl -H \"$(lsblk -dno PATH,TYPE 2>/dev/null | awk '$2==\"disk\"{print $1; exit}')\" 2>/dev/null | grep -qiE 'PASSED|OK' || echo no-priv-or-absent"
    expected_exit: 0
    severity_default: high
    solo_modo: [real]

triggers:
  keywords: ["filesystem", "fs", "mount", "fstab", "smart", "disk-usage", "noatime"]
  contextos: ["cron", "pre-deploy", "post-update"]
  cron: "0 4 * * *"
---

# Objetivo

Verificar la postura del sistema de ficheros del host: opciones de montaje
(`noatime`/`relatime`), uso de disco frente a umbrales, salud SMART de los
dispositivos, coherencia de `/etc/fstab` y tipo de filesystem del root. Emite
informe y propuesta sin montar, formatear ni escribir en disco (read-only).

# Cuándo activar

| Si... | Entonces... |
|---|---|
| Monitorización periódica de disco | Invocar `--mode=sandbox` · uso vs umbral 90% |
| Antes de un despliegue con datos | Confirmar SMART OK y fstab coherente |
| Auditoría CIS de montajes | Revisar opciones de montaje por partición |
| `target_tipo != 'host'` | Skill se salta con `skipped: not_applicable` |

# Uso · comentario encabezado (copiar al script)

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_linux-fs · v0.7.0 · 2026-06-20                          ║
# ║  Función: verificar postura del sistema de ficheros del host ║
# ║  Variables entorno:                                          ║
# ║    XEK_SUDO            comando de escalada (default: sudo -A) ║
# ║    XDG_RUNTIME_DIR     base sandbox                          ║
# ║  Uso:                                                        ║
# ║    xek-linux-fs.sh --mode={dry-run|sandbox|real}            ║
# ║  Exit codes:                                                ║
# ║    0=clean · 1=findings · 2=config · 3=missing-mode · 4=ill ║
# ╚══════════════════════════════════════════════════════════════╝
```

# Implementación referencia (bash · fuente de verdad)

La implementación ejecutable y **única fuente de verdad** es
[`scripts/xek-linux-fs.sh`](scripts/xek-linux-fs.sh) (v0.7.1, shellcheck-clean, cubierto por
`tests/test_linux_fs.py`). Emite `xek/finding@v1`: un finding por cada check que falla,
con `severity` y `remediation`. Los checks privilegiados degradan a
informativo sin escalada (no abortan). El frontmatter `checks[]` es la
especificación declarativa; el script no se duplica aquí para evitar drift.

Firma y contrato:

```bash
xek-linux-fs.sh --mode {dry-run|sandbox|real} [--override-gate=AUTO_<ts>]
# exit: 0 sin findings · 1 findings · 2 config · 3 falta --mode · 4 ill-call
```

# Adaptador Python

```python
#!/usr/bin/env python3
"""XEK_linux-fs · adapter Python."""
import subprocess, sys, pathlib
script = pathlib.Path(__file__).with_name("xek-linux-fs.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-linux-fs.sh" "$@"
```

# Verificación end-to-end (smoke test)

```bash
./scripts/xek-linux-fs.sh --mode=dry-run && echo "PASS dry-run"
./scripts/xek-linux-fs.sh --mode=sandbox
echo "exit=$?"
```

# Riesgos y mitigación

| Riesgo | Mitigación |
|---|---|
| `smartctl -H` requiere acceso al dispositivo | Check privilegiado marcado · skip+report sin escalada |
| `findmnt --verify` falla en montajes de red | Tratar como finding informativo · no aborta |
| Umbral 90% demasiado estricto para /boot | Severidad alta solo en root y /var; propuesta ajusta umbral |
| crypttab adyacente con passphrase | Reportar presencia; nunca imprimir línea sensible |

# Bitácora evolución

- **v0.0.1** (2026-05-20) — bootstrap stub.
- **v0.6.1** (2026-05-22) — degradado a stub (deuda v0.6).
- **v0.7.0** (2026-06-20) — stub→borrador: fuentes reales, escalada `${XEK_SUDO}`, checks[] read-only.

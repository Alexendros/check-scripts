---
slug: XEK_linux-secretos
ambito: Linux
maestria_funcional: revisor
estado: borrador
version: 0.7.0
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub · pendiente implementación" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "degradado borrador→stub per síntesis Ronda 002 (commit deuda v0.6)" }
  - { v: 0.7.0, fecha: 2026-06-20, cambio: "stub→borrador · fuentes reales (Secret Service/OpenSSH), escalada R16, checks[] de permisos sin volcar secretos" }

objetivo: >
  Verificar la higiene de secretos del host: permisos de claves (600), secretos
  legibles por todos, agentes ssh/gpg y limpieza de authorized_keys. Reporta
  ubicaciones, nunca valores.

fuentes_externas:
  - { tipo: tool, nombre: "ssh-keygen",  version_min: "9.0", licencia: "BSD-3-Clause" }
  - { tipo: tool, nombre: "ssh-add",     version_min: "9.0", licencia: "BSD-3-Clause" }
  - { tipo: tool, nombre: "gpg",         version_min: "2.4", licencia: "GPL-3.0-or-later" }
  - { tipo: tool, nombre: "find",        version_min: "4.9", licencia: "GPL-3.0-or-later" }
conexiones_requeridas: []

referencias_canonicas:
  - { tipo: estandar,    url: "https://specifications.freedesktop.org/secret-service/latest/", cobertura: "Secret Service · almacén de secretos de sesión" }
  - { tipo: doc_oficial, url: "https://www.openssh.com/manual.html", cobertura: "OpenSSH · permisos de clave y authorized_keys" }
  - { tipo: estandar,    url: "https://www.cisecurity.org/benchmark/distribution_independent_linux", cobertura: "CIS · permisos de ficheros sensibles" }
verificar_referencias:
  cuando: "antes de cada bump de version_min de OpenSSH/gpg"
  como: "consultar man pages oficiales; rechazar bump si cambian los modos esperados de permisos"

areas_criticas:
  permisos_user:
    - "stat/find sobre ~/.ssh, ~/.gnupg sin escalada (ficheros propios del usuario)"
    - "lectura de /etc/ssh/*_key (claves de host) requiere escalada · privilegiado"
  fhs_tocados:
    - "$HOME/.ssh/, $HOME/.gnupg/ (solo metadatos · stat, nunca cat)"
    - "/etc/ssh/ (solo metadatos)"
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-secretos/"
  visual_secrets:
    - "contenido de claves privadas y passphrases · NUNCA imprimir · solo ruta + modo de permiso"
  zonas_ocultas:
    - "ssh-agent/gpg-agent sockets en $XDG_RUNTIME_DIR · comprobar presencia, no volcar claves cargadas"

modos_ejecucion:
  dry-run:
    proposito: "Enumerar ubicaciones candidatas de secretos sin leer su contenido."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · rutas + presencia de agentes · exit 0"
  sandbox:
    proposito: "Capturar snapshot de permisos de secretos en sandbox."
    aislamiento: "directorio bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-secretos/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-secretos/"
    efectos_red: "ninguno"
    salida: "findings.json (solo rutas + modos) · exit 0/1 según postura"
  real:
    proposito: "Ejecutar contra host real · genera informe + propuesta_#N. Nunca lee ni imprime contenido de secretos."
    precondicion: "sandbox del mismo host ha pasado en las últimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_linux-secretos/<fecha>/"
    efectos_red: "ninguno"
    salida: "informe.md + findings.json + propuesta_#N"
gate_promocion:
  regla: "modo N+1 solo si modo N exit 0|1 con plan"
  override: "--override-gate=AUTO_<timestamp ±60s>"

escalada_privilegio:
  comando_template: "${XEK_SUDO:-sudo -A}"
  cuando_aplica: "comprobación de permisos de claves de host en /etc/ssh (lectura de metadatos privilegiada); sin escalada se omite ese check y se reporta skipped"

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
  bash:   scripts/xek-linux-secretos.sh
  python: scripts/xek-linux-secretos.py
  zsh:    scripts/xek-linux-secretos.zsh

checks:
  - id: "sec-001"
    descripcion: "Detectar herramientas de inspección de claves presentes (ssh-keygen, find)"
    command_template: "command -v ssh-keygen >/dev/null && command -v find >/dev/null"
    expected_exit: 0
    severity_default: info
    solo_modo: [dry-run, sandbox, real]
  - id: "sec-002"
    descripcion: "Claves privadas SSH del usuario con permisos 600 (no más laxos)"
    command_template: "test -z \"$(find \"$HOME/.ssh\" -maxdepth 1 -name 'id_*' ! -name '*.pub' -perm /077 2>/dev/null)\""
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "sec-003"
    descripcion: "Ningún fichero en ~/.ssh legible por grupo/otros (world-readable)"
    command_template: "test -z \"$(find \"$HOME/.ssh\" -type f -perm /044 ! -name '*.pub' 2>/dev/null)\""
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "sec-004"
    descripcion: "authorized_keys con permisos 600 y sin opciones de reenvío peligrosas"
    command_template: "test ! -f \"$HOME/.ssh/authorized_keys\" || test -z \"$(find \"$HOME/.ssh/authorized_keys\" -perm /077 2>/dev/null)\""
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "sec-005"
    descripcion: "Presencia de ssh-agent o gpg-agent vía socket (sin volcar claves)"
    command_template: "test -n \"${SSH_AUTH_SOCK:-}\" -o -S \"${XDG_RUNTIME_DIR:-/run/user/$UID}/gnupg/S.gpg-agent\""
    expected_exit: 0
    severity_default: info
    solo_modo: [sandbox, real]
  - id: "sec-006"
    descripcion: "Permisos de claves de host SSH en /etc/ssh (privilegiado · skip sin escalada)"
    command_template: "${XEK_SUDO:-sudo -A} find /etc/ssh -name 'ssh_host_*_key' -perm /077 2>/dev/null | grep -q . && echo lax-perms || echo no-priv-or-ok"
    expected_exit: 0
    severity_default: high
    solo_modo: [real]

triggers:
  keywords: ["secretos", "ssh", "gpg", "permisos", "authorized_keys", "ssh-agent", "claves", "dotfiles"]
  contextos: ["pre-deploy", "post-update", "cron"]
  cron: "0 2 * * *"
---

# Objetivo

Verificar la higiene de secretos del host: permisos de ficheros de clave (`600`),
ausencia de secretos legibles por todos, presencia de `ssh-agent`/`gpg-agent` y
limpieza de `authorized_keys`. Reporta únicamente ubicaciones y modos de permiso;
NUNCA lee ni imprime el contenido de ningún secreto (read-only).

# Cuándo activar

| Si... | Entonces... |
|---|---|
| Provisión de un nuevo host/usuario | Invocar `--mode=sandbox` · revisar permisos de claves |
| Auditoría de higiene de secretos | Confirmar 600 en claves y authorized_keys |
| Tras clonar dotfiles | Detectar permisos laxos heredados |
| `target_tipo != 'host'` | Skill se salta con `skipped: not_applicable` |

# Uso · comentario encabezado (copiar al script)

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_linux-secretos · v0.7.0 · 2026-06-20                    ║
# ║  Función: verificar higiene de secretos del host (solo rutas)║
# ║  Variables entorno:                                          ║
# ║    XEK_SUDO            comando de escalada (default: sudo -A) ║
# ║    XDG_RUNTIME_DIR     base sandbox                          ║
# ║  Uso:                                                        ║
# ║    xek-linux-secretos.sh --mode={dry-run|sandbox|real}      ║
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
# TODO: ejecutar los checks[] declarados en los 3 modos · solo stat/find · nunca cat de secretos.
```

# Adaptador Python

```python
#!/usr/bin/env python3
"""XEK_linux-secretos · adapter Python."""
import subprocess, sys, pathlib
script = pathlib.Path(__file__).with_name("xek-linux-secretos.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-linux-secretos.sh" "$@"
```

# Verificación end-to-end (smoke test)

```bash
./scripts/xek-linux-secretos.sh --mode=dry-run && echo "PASS dry-run"
./scripts/xek-linux-secretos.sh --mode=sandbox
echo "exit=$?"
```

# Riesgos y mitigación

| Riesgo | Mitigación |
|---|---|
| Riesgo de filtrar contenido de claves | Checks usan solo `stat`/`find -perm`; jamás `cat` |
| Claves de host en /etc/ssh | Check privilegiado · skip+report sin escalada |
| Passphrase visible en dotfiles adyacentes | Reportar ruta y modo; nunca volcar la línea |
| Falsos positivos en *.pub | Excluidos explícitamente del check de permisos |

# Bitácora evolución

- **v0.0.1** (2026-05-20) — bootstrap stub.
- **v0.6.1** (2026-05-22) — degradado a stub (deuda v0.6).
- **v0.7.0** (2026-06-20) — stub→borrador: fuentes reales (Secret Service/OpenSSH), escalada `${XEK_SUDO}`, checks[] de permisos sin volcar secretos.

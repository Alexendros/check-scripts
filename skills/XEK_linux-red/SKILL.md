---
slug: XEK_linux-red
ambito: Linux
maestria_funcional: revisor
estado: borrador
version: 0.7.0
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub · pendiente implementación" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "degradado borrador→stub per síntesis Ronda 002 (commit deuda v0.6)" }
  - { v: 0.7.0, fecha: 2026-06-20, cambio: "stub→borrador · fuentes reales (nftables/iproute2), escalada R16, checks[] read-only de red" }

objetivo: >
  Verificar la postura de red del host: firewall (nftables/ufw) activo, ausencia de
  puertos a la escucha inesperados, configuración DNS y política IPv6. Read-only.

fuentes_externas:
  - { tipo: tool, nombre: "nft",     version_min: "1.0",  licencia: "GPL-2.0-only" }
  - { tipo: tool, nombre: "ss",      version_min: "6.0",  licencia: "GPL-2.0-or-later" }
  - { tipo: tool, nombre: "ip",      version_min: "6.0",  licencia: "GPL-2.0-or-later" }
  - { tipo: tool, nombre: "ufw",     version_min: "0.36", licencia: "GPL-3.0-only" }
conexiones_requeridas: []

referencias_canonicas:
  - { tipo: doc_oficial, url: "https://www.netfilter.org/projects/nftables/", cobertura: "nftables · firewall del kernel Linux" }
  - { tipo: doc_oficial, url: "https://wiki.linuxfoundation.org/networking/iproute2", cobertura: "iproute2 · ip/ss routing y sockets" }
  - { tipo: estandar,    url: "https://www.cisecurity.org/benchmark/distribution_independent_linux", cobertura: "CIS · firewall, puertos y configuración de red" }
verificar_referencias:
  cuando: "antes de cada bump de version_min de nftables/iproute2"
  como: "consultar man pages oficiales; rechazar bump si cambia la salida de `nft list ruleset`/`ss -tlnp`"

areas_criticas:
  permisos_user:
    - "ss -tuln, ip route, resolvectl status sin escalada"
    - "nft list ruleset requiere escalada · privilegiado"
  fhs_tocados:
    - "/etc/resolv.conf, /etc/hosts, /etc/nsswitch.conf (solo lectura)"
    - "/proc/net/, /sys/class/net/ (solo lectura)"
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-red/"
  visual_secrets:
    - "direcciones IP internas y nombres de host · hash en informes públicos"
  zonas_ocultas:
    - "reglas nftables con marcas/secretos de túnel · listar estructura, no volcar datos sensibles"

modos_ejecucion:
  dry-run:
    proposito: "Detectar herramientas de red presentes y enumerar interfaces sin tocar el firewall."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · tools + interfaces · exit 0"
  sandbox:
    proposito: "Capturar snapshot de postura de red en sandbox."
    aislamiento: "directorio bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-red/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-red/"
    efectos_red: "ninguno · solo lectura de estado local"
    salida: "findings.json · exit 0/1 según postura"
  real:
    proposito: "Ejecutar contra host real · genera informe + propuesta_#N. Nunca modifica reglas ni interfaces."
    precondicion: "sandbox del mismo host ha pasado en las últimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_linux-red/<fecha>/"
    efectos_red: "ninguno · solo lectura de estado local"
    salida: "informe.md + findings.json + propuesta_#N"
gate_promocion:
  regla: "modo N+1 solo si modo N exit 0|1 con plan"
  override: "--override-gate=AUTO_<timestamp ±60s>"

escalada_privilegio:
  comando_template: "${XEK_SUDO:-sudo -A}"
  cuando_aplica: "lectura del ruleset nftables (nft list ruleset necesita CAP_NET_ADMIN); sin escalada se omite ese check y se reporta skipped"

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
  bash:   scripts/xek-linux-red.sh
  python: scripts/xek-linux-red.py
  zsh:    scripts/xek-linux-red.zsh

checks:
  - id: "red-001"
    descripcion: "Detectar herramientas de inspección de red presentes (ss, ip)"
    command_template: "command -v ss >/dev/null && command -v ip >/dev/null"
    expected_exit: 0
    severity_default: info
    solo_modo: [dry-run, sandbox, real]
  - id: "red-002"
    descripcion: "Verificar que existe un firewall activo (ufw activo o nftables con reglas)"
    command_template: "ufw status 2>/dev/null | grep -qi 'Status: active' || nft list ruleset 2>/dev/null | grep -q 'chain'"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "red-003"
    descripcion: "Sin puertos a la escucha en 0.0.0.0/:: fuera de la lista esperada"
    command_template: "test -z \"$(ss -H -tlnp 2>/dev/null | awk '{print $4}' | grep -E '0\\.0\\.0\\.0|\\[::\\]' | grep -vE ':(53|631)$')\""
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "red-004"
    descripcion: "Configuración DNS presente con al menos un nameserver"
    command_template: "test -s /etc/resolv.conf && grep -qE '^nameserver ' /etc/resolv.conf"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "red-005"
    descripcion: "Reenvío IPv6 deshabilitado salvo en hosts router"
    command_template: "test \"$(cat /proc/sys/net/ipv6/conf/all/forwarding 2>/dev/null)\" = 0"
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]
  - id: "red-006"
    descripcion: "Listar ruleset nftables para auditoría (privilegiado · skip sin escalada)"
    command_template: "${XEK_SUDO:-sudo -A} nft list ruleset >/dev/null 2>&1 || echo no-priv-or-absent"
    expected_exit: 0
    severity_default: high
    solo_modo: [real]

triggers:
  keywords: ["red", "firewall", "nftables", "ufw", "puertos", "dns", "ipv6", "listen"]
  contextos: ["pre-deploy", "post-update", "cron"]
  cron: "0 3 * * *"
---

# Objetivo

Verificar la postura de red del host: firewall (`nftables`/`ufw`) activo,
ausencia de puertos a la escucha inesperados, configuración DNS correcta y
política IPv6. Emite informe y propuesta sin modificar reglas, interfaces ni
tablas de enrutamiento (read-only).

# Cuándo activar

| Si... | Entonces... |
|---|---|
| Antes de exponer un servicio | Invocar `--mode=sandbox` · revisar puertos LISTEN |
| Tras cambio de configuración de red | Confirmar firewall activo y DNS coherente |
| Auditoría CIS de red | Revisar política IPv6 y reglas nftables |
| `target_tipo != 'host'` | Skill se salta con `skipped: not_applicable` |

# Uso · comentario encabezado (copiar al script)

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_linux-red · v0.7.0 · 2026-06-20                         ║
# ║  Función: verificar postura de red del host                 ║
# ║  Variables entorno:                                          ║
# ║    XEK_SUDO            comando de escalada (default: sudo -A) ║
# ║    XDG_RUNTIME_DIR     base sandbox                          ║
# ║  Uso:                                                        ║
# ║    xek-linux-red.sh --mode={dry-run|sandbox|real}          ║
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
# TODO: ejecutar los checks[] declarados en los 3 modos · read-only sobre estado de red.
```

# Adaptador Python

```python
#!/usr/bin/env python3
"""XEK_linux-red · adapter Python."""
import subprocess, sys, pathlib
script = pathlib.Path(__file__).with_name("xek-linux-red.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-linux-red.sh" "$@"
```

# Verificación end-to-end (smoke test)

```bash
./scripts/xek-linux-red.sh --mode=dry-run && echo "PASS dry-run"
./scripts/xek-linux-red.sh --mode=sandbox
echo "exit=$?"
```

# Riesgos y mitigación

| Riesgo | Mitigación |
|---|---|
| `nft list ruleset` requiere CAP_NET_ADMIN | Check privilegiado marcado · skip+report sin escalada |
| Puerto 53/631 legítimo en LISTEN | Whitelist en check 003 · propuesta ajusta lista |
| Host es router (forwarding esperado) | Severidad baja · propuesta contextualiza por rol |
| IPs internas en informe | Hash de direcciones; nunca volcar topología cruda |

# Bitácora evolución

- **v0.0.1** (2026-05-20) — bootstrap stub.
- **v0.6.1** (2026-05-22) — degradado a stub (deuda v0.6).
- **v0.7.0** (2026-06-20) — stub→borrador: fuentes reales (nftables/iproute2), escalada `${XEK_SUDO}`, checks[] read-only.

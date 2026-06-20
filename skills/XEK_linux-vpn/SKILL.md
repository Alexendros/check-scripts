---
slug: XEK_linux-vpn
ambito: Linux
maestria_funcional: revisor
estado: borrador
version: 0.7.0
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub · pendiente implementación" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "degradado borrador→stub per síntesis Ronda 002 (commit deuda v0.6)" }
  - { v: 0.7.0, fecha: 2026-06-20, cambio: "stub→borrador · fuentes reales (WireGuard/OpenVPN), escalada R16, checks[] config/DNS-leak/killswitch/perms" }

objetivo: >
  Verificar la postura VPN del host: configuración presente, guarda anti fuga de DNS,
  killswitch (regla de firewall) y permisos de claves de túnel. Read-only.

fuentes_externas:
  - { tipo: tool, nombre: "wg",       version_min: "1.0",  licencia: "GPL-2.0-only" }
  - { tipo: tool, nombre: "openvpn",  version_min: "2.6",  licencia: "GPL-2.0-only" }
  - { tipo: tool, nombre: "ip",       version_min: "6.0",  licencia: "GPL-2.0-or-later" }
  - { tipo: tool, nombre: "resolvectl", version_min: "255", licencia: "LGPL-2.1-or-later" }
conexiones_requeridas: []

referencias_canonicas:
  - { tipo: doc_oficial, url: "https://www.wireguard.com/", cobertura: "WireGuard · túnel y gestión de claves" }
  - { tipo: doc_oficial, url: "https://openvpn.net/community-resources/", cobertura: "OpenVPN community · configuración de túnel" }
  - { tipo: estandar,    url: "https://www.cisecurity.org/benchmark/distribution_independent_linux", cobertura: "CIS · permisos de ficheros sensibles y red" }
verificar_referencias:
  cuando: "antes de cada bump de version_min de WireGuard/OpenVPN"
  como: "consultar man pages oficiales; rechazar bump si cambia la salida de `wg show`/formato de config"

areas_criticas:
  permisos_user:
    - "ip link show, resolvectl status sin escalada"
    - "wg show (claves) y lectura de /etc/wireguard requieren escalada · privilegiado"
  fhs_tocados:
    - "/etc/wireguard/, /etc/openvpn/ (solo metadatos · stat, nunca cat de claves)"
    - "/etc/resolv.conf, /proc/sys/net/ (solo lectura)"
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-vpn/"
  visual_secrets:
    - "PrivateKey/PresharedKey en config WireGuard y certificados OpenVPN · NUNCA imprimir · solo ruta + modo"
  zonas_ocultas:
    - "endpoints y rangos AllowedIPs · listar estructura, hash de endpoints en informe público"

modos_ejecucion:
  dry-run:
    proposito: "Detectar herramientas VPN y enumerar interfaces de túnel sin leer claves."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · tools + interfaces túnel · exit 0"
  sandbox:
    proposito: "Capturar snapshot de postura VPN en sandbox."
    aislamiento: "directorio bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-vpn/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-vpn/"
    efectos_red: "ninguno · solo lectura de estado local"
    salida: "findings.json (rutas + modos, sin claves) · exit 0/1 según postura"
  real:
    proposito: "Ejecutar contra host real · genera informe + propuesta_#N. Nunca levanta, baja ni edita túneles."
    precondicion: "sandbox del mismo host ha pasado en las últimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_linux-vpn/<fecha>/"
    efectos_red: "ninguno · solo lectura de estado local"
    salida: "informe.md + findings.json + propuesta_#N"
gate_promocion:
  regla: "modo N+1 solo si modo N exit 0|1 con plan"
  override: "--override-gate=AUTO_<timestamp ±60s>"

escalada_privilegio:
  comando_template: "${XEK_SUDO:-sudo -A}"
  cuando_aplica: "inspección de túneles WireGuard activos (wg show) y permisos en /etc/wireguard necesitan escalada; sin escalada se omiten esos checks y se reportan skipped"

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
  bash:   scripts/xek-linux-vpn.sh
  python: scripts/xek-linux-vpn.py
  zsh:    scripts/xek-linux-vpn.zsh

checks:
  - id: "vpn-001"
    descripcion: "Detectar herramientas VPN presentes (wg u openvpn)"
    command_template: "command -v wg >/dev/null || command -v openvpn >/dev/null"
    expected_exit: 0
    severity_default: info
    solo_modo: [dry-run, sandbox, real]
  - id: "vpn-002"
    descripcion: "Configuración VPN presente (WireGuard u OpenVPN)"
    command_template: "test -n \"$(ls /etc/wireguard/*.conf 2>/dev/null)\" || test -n \"$(ls /etc/openvpn/*.conf /etc/openvpn/*/*.conf 2>/dev/null)\""
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "vpn-003"
    descripcion: "Permisos de config WireGuard restrictivos (no legibles por grupo/otros)"
    command_template: "test -z \"$(find /etc/wireguard -name '*.conf' -perm /077 2>/dev/null)\""
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "vpn-004"
    descripcion: "Guarda anti fuga de DNS: resolver no apunta fuera del túnel cuando hay interfaz wg/tun activa"
    command_template: "! ip link show type wireguard up 2>/dev/null | grep -q . || resolvectl status 2>/dev/null | grep -q 'DNS Servers'"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "vpn-005"
    descripcion: "Killswitch presente: regla de firewall que bloquea tráfico fuera del túnel"
    command_template: "nft list ruleset 2>/dev/null | grep -qiE 'oifname .*(wg|tun)|drop' || ufw status 2>/dev/null | grep -qi 'Status: active'"
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]
  - id: "vpn-006"
    descripcion: "Inspeccionar túneles WireGuard activos (privilegiado · skip sin escalada)"
    command_template: "${XEK_SUDO:-sudo -A} wg show interfaces >/dev/null 2>&1 || echo no-priv-or-absent"
    expected_exit: 0
    severity_default: medium
    solo_modo: [real]

triggers:
  keywords: ["vpn", "wireguard", "openvpn", "tunel", "dns-leak", "killswitch", "wg", "split-tunnel"]
  contextos: ["pre-deploy", "post-update", "cron"]
  cron: "0 7 * * *"
---

# Objetivo

Verificar la postura VPN del host: configuración presente (`WireGuard`/`OpenVPN`),
guarda anti fuga de DNS, killswitch (regla de firewall que corta el tráfico fuera
del túnel) y permisos de claves. Emite informe y propuesta sin levantar, bajar ni
editar túneles; reporta rutas y modos, NUNCA imprime claves (read-only).

# Cuándo activar

| Si... | Entonces... |
|---|---|
| Provisión de un túnel VPN | Invocar `--mode=sandbox` · revisar permisos de config |
| Auditoría de privacidad | Confirmar killswitch y guarda DNS |
| Tras cambio de red | Detectar fuga de DNS fuera del túnel |
| `target_tipo != 'host'` | Skill se salta con `skipped: not_applicable` |

# Uso · comentario encabezado (copiar al script)

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_linux-vpn · v0.7.0 · 2026-06-20                         ║
# ║  Función: verificar postura VPN del host (solo rutas/estado) ║
# ║  Variables entorno:                                          ║
# ║    XEK_SUDO            comando de escalada (default: sudo -A) ║
# ║    XDG_RUNTIME_DIR     base sandbox                          ║
# ║  Uso:                                                        ║
# ║    xek-linux-vpn.sh --mode={dry-run|sandbox|real}          ║
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
# TODO: ejecutar los checks[] declarados en los 3 modos · read-only · nunca cat de claves de túnel.
```

# Adaptador Python

```python
#!/usr/bin/env python3
"""XEK_linux-vpn · adapter Python."""
import subprocess, sys, pathlib
script = pathlib.Path(__file__).with_name("xek-linux-vpn.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-linux-vpn.sh" "$@"
```

# Verificación end-to-end (smoke test)

```bash
./scripts/xek-linux-vpn.sh --mode=dry-run && echo "PASS dry-run"
./scripts/xek-linux-vpn.sh --mode=sandbox
echo "exit=$?"
```

# Riesgos y mitigación

| Riesgo | Mitigación |
|---|---|
| `wg show` expone claves públicas/handshakes | Check privilegiado · skip+report; nunca volcar claves privadas |
| Config con PrivateKey en /etc/wireguard | Solo `stat`/`find -perm`; jamás `cat` |
| Killswitch implementado fuera de nftables/ufw | Check 005 informativo · propuesta documenta el mecanismo real |
| Endpoints sensibles en informe | Hash de endpoints; nunca volcar topología cruda |

# Bitácora evolución

- **v0.0.1** (2026-05-20) — bootstrap stub.
- **v0.6.1** (2026-05-22) — degradado a stub (deuda v0.6).
- **v0.7.0** (2026-06-20) — stub→borrador: fuentes reales (WireGuard/OpenVPN), escalada `${XEK_SUDO}`, checks[] read-only.

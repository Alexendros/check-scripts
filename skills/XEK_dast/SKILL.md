---
slug: XEK_dast
ambito: DAST
maestria_funcional: revisor
estado: borrador
version: 0.7.0
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub · pendiente implementación" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "degradado borrador→stub per síntesis Ronda 002 (commit deuda v0.6)" }
  - { v: 0.7.0, fecha: 2026-06-20, cambio: "stub→borrador: DAST passive read-only (security headers, TLS, cookies, banner, exposición .git/.env) · checks[] tipados · fuentes canónicas reales" }

objetivo: >
  Verificar pasivamente la superficie HTTP de una app (security headers,
  redirección HTTPS, flags de cookies, banner, exposición .git/.env) en modo
  read-only sin payloads de ataque.

precondiciones_runtime:
  binarios:
    - { nombre: "bash", version_min: "5.0",  licencia: "GPL-3.0", check_cmd: "bash --version" }
    - { nombre: "curl", version_min: "7.79", licencia: "curl",    check_cmd: "curl --version" }
    - { nombre: "grep", version_min: "3.0",  licencia: "GPL-3.0", check_cmd: "grep --version" }
    - { nombre: "test", version_min: "8.0",  licencia: "GPL-3.0", check_cmd: "test --help" }
  capabilities:
    - { cap: "CAP_NONE", razon: "sondeo HTTP read-only de recursos públicos · sin escalada" }
  paths_lectura:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_dast/<run-id>/*.headers"
  paths_escritura:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_dast/"
  conexiones:
    - { destino: "$TARGET_URL", proto: https, auth: none }

escalada:
  adapter: "${XEK_SUDO:-sudo -A}"
  capabilities_requeridas: []
  fallback_sin_escalada: "no aplica · skill sin escalada"
  registrar_en_finding: false

fuentes_externas:
  - { tipo: tool, nombre: curl, version_min: "7.79", licencia: "curl" }
  - { tipo: tool, nombre: grep, version_min: "3.0",  licencia: "GPL-3.0" }
conexiones_requeridas:
  - { destino: "$TARGET_URL", proto: https, auth: none }

referencias_canonicas:
  - { tipo: doc_oficial, url: "https://owasp.org/www-project-web-security-testing-guide/", cobertura: "OWASP WSTG · metodología de pruebas pasivas de configuración, TLS y headers" }
  - { tipo: estandar,    url: "https://owasp.org/Top10/", cobertura: "OWASP Top 10 · A05 Security Misconfiguration · A02 Cryptographic Failures" }
verificar_referencias:
  cuando: "antes de cada bump de version_min de tools"
  como: "consultar doc oficial; rechazar bump si la doc marca cambio breaking en el formato"

areas_criticas:
  permisos_user:
    - "egress HTTP(S) al target público y a sus rutas estáticas"
    - "escritura: $XDG_RUNTIME_DIR/xek-sandbox/XEK_dast/"
  fhs_tocados:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_dast/ (solo escritura de cabeceras cacheadas)"
  visual_secrets:
    - "valores de cookies de sesión · redactar con [REDACTED] en logs públicos"
    - "tokens en cabeceras Authorization · jamás imprimir"
  zonas_ocultas:
    - "endpoints autenticados o tras login · fuera de alcance · solo recursos públicos"
    - "prohibido payload activo · solo inspección de cabeceras/TLS/config"

modos_ejecucion:
  dry-run:
    proposito: "Verificar precondiciones y listar los checks que se ejecutarían sin egress al target."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · plan textual de checks · exit 0 si parse OK"
  sandbox:
    proposito: "Descargar una vez cabeceras y rutas públicas a sandbox y correr los checks contra la copia aislada."
    aislamiento: "directorio bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_dast/<run-id>/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_dast/"
    efectos_red: "GET/HEAD read-only al target declarado · sin payloads activos"
    salida: "findings.json en sandbox path · exit 0|1 según findings"
  real:
    proposito: "Ejecutar contra la URL real (read-only) y persistir informe en cuaderno."
    precondicion: "sandbox del mismo input ha pasado en las últimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_dast/<fecha>/"
    efectos_red: "GET/HEAD read-only al target · sin payloads activos"
    salida: "informe.md + findings.json + propuesta_#N si findings ≥ severidad_min"
gate_promocion:
  regla: "modo N+1 solo si modo N exit 0|1 con plan"
  override: "--override-gate=AUTO_<timestamp ±60s>"

depende_de:
  - { slug: XEK_detecta-stack, modo: sandbox, obligatoria: true, razon: "necesita target_tipo=app-en-vivo y URL base" }
contrato_invocacion:
  modo_subordinado: sandbox
  promocion_real: solo_operador
  consolidacion: "json · merge por slug · schema xek/finding@v1"

checks:
  - id: "dast-001"
    descripcion: "Cabecera Content-Security-Policy presente en la respuesta del target"
    command_template: "curl -sI \"$TARGET_URL\" | grep -qiE '^content-security-policy:'"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "dast-002"
    descripcion: "Cabecera Strict-Transport-Security (HSTS) presente con max-age"
    command_template: "curl -sI \"$TARGET_URL\" | grep -qiE '^strict-transport-security:.*max-age='"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "dast-003"
    descripcion: "Cabecera X-Content-Type-Options con valor nosniff"
    command_template: "curl -sI \"$TARGET_URL\" | grep -qiE '^x-content-type-options:[[:space:]]*nosniff'"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "dast-004"
    descripcion: "Mitigacion clickjacking via X-Frame-Options o frame-ancestors en CSP"
    command_template: "curl -sI \"$TARGET_URL\" | grep -qiE '^x-frame-options:|^content-security-policy:.*frame-ancestors'"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "dast-005"
    descripcion: "Redireccion de la variante http hacia https (301 o 308)"
    command_template: "curl -s -o /dev/null -w '%{http_code}' \"$HTTP_URL\" | grep -qE '^30[18]$'"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "dast-006"
    descripcion: "Cookies con flag Secure cuando se emiten cabeceras Set-Cookie"
    command_template: "! curl -sI \"$TARGET_URL\" | grep -qiE '^set-cookie:' || curl -sI \"$TARGET_URL\" | grep -iE '^set-cookie:' | grep -qiE 'secure'"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "dast-007"
    descripcion: "Sin fuga de version en banner: cabecera Server sin numero de version"
    command_template: "! curl -sI \"$TARGET_URL\" | grep -iE '^server:' | grep -qE '[0-9]+\\.[0-9]+'"
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]
  - id: "dast-008"
    descripcion: "Directorio .git no expuesto: /.git/config no devuelve 200"
    command_template: "test \"$(curl -s -o /dev/null -w '%{http_code}' \"$BASE_URL/.git/config\")\" != 200"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "dast-009"
    descripcion: "Fichero .env no expuesto: /.env no devuelve 200"
    command_template: "test \"$(curl -s -o /dev/null -w '%{http_code}' \"$BASE_URL/.env\")\" != 200"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]

aplicabilidad:
  cuando:
    - "manifest.target_tipo == 'app-en-vivo'"
  prioridad: alta
  coste_relativo: 2

migracion_runtime:
  bash:   scripts/xek-dast.sh
  python: scripts/xek-dast.py
  zsh:    scripts/xek-dast.zsh

triggers:
  keywords: ["dast", "security-headers", "csp", "hsts", "tls", "cookie-flags", "exposed-git"]
  contextos: ["pre-deploy", "post-deploy", "pre-PR"]
  cron: ""
---

# Objetivo

Verificar pasivamente la superficie HTTP de una aplicacion en vivo en modo
read-only: presencia de security headers (CSP, HSTS, X-Content-Type-Options,
X-Frame-Options), redireccion de HTTP a HTTPS, flag `Secure` en cookies, fuga de
version en el banner `Server` y exposicion de rutas sensibles como
`/.git/config` y `/.env`. La skill solo inspecciona cabeceras y respuestas
publicas; nunca envia payloads de ataque activo ni modifica el target.

# Cuando activar

| Si... | Entonces... |
|---|---|
| `manifest.target_tipo == 'app-en-vivo'` con URL publica | Ejecutar `--mode=sandbox` sobre las cabeceras descargadas |
| Pre-deploy de un servicio expuesto a internet | Correr `dast-001..dast-009` y bloquear si severidad high falla |
| Post-deploy para verificar headers y rutas en produccion | Promover a `--mode=real` tras sandbox verde |

# Uso · comentario encabezado (copiar al script)

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_dast · v0.7.0 · 2026-06-20                               ║
# ║  Funcion: DAST pasivo read-only de superficie HTTP           ║
# ║  Variables entorno:                                          ║
# ║    XEK_TARGET_URL     URL publica a inspeccionar             ║
# ║    XDG_RUNTIME_DIR    base sandbox                           ║
# ║  Uso:                                                        ║
# ║    xek-dast.sh --mode={dry-run|sandbox|real} --url <URL>     ║
# ║  Exit codes:                                                 ║
# ║    0=clean · 1=findings · 2=config · 3=missing-mode · 4=ill-call║
# ╚══════════════════════════════════════════════════════════════╝
```

# Implementacion referencia (bash · fuente de verdad)

```bash
#!/usr/bin/env bash
set -euo pipefail

SLUG="XEK_dast"
VERSION="0.7.0"
MODE=""
TARGET_URL="${XEK_TARGET_URL:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode=*) MODE="${1#*=}"; shift ;;
    --url)    TARGET_URL="$2"; shift 2 ;;
    *)        echo "ill-call: $1" >&2; exit 4 ;;
  esac
done

[[ -z "$MODE" ]] && { echo "missing --mode" >&2; exit 3; }
[[ "$MODE" =~ ^(dry-run|sandbox|real)$ ]] || { echo "bad --mode" >&2; exit 2; }

BASE_URL="${TARGET_URL%/}"
HTTP_URL="${BASE_URL/https:/http:}"

if [[ "$MODE" == "dry-run" ]]; then
  echo "## ${SLUG} v${VERSION} · plan dry-run"
  echo "checks: dast-001..dast-009 (headers, HTTPS redirect, cookies, banner, exposicion .git/.env)"
  echo "target: ${TARGET_URL:-<sin --url>}"
  exit 0
fi

[[ -z "$TARGET_URL" ]] && { echo "missing --url" >&2; exit 2; }
# sandbox/real: ejecutar los checks[] del frontmatter contra TARGET_URL/BASE_URL/HTTP_URL.
```

# Adaptador Python

```python
#!/usr/bin/env python3
"""XEK_dast · adapter Python para pipelines orquestados."""
import subprocess, sys, pathlib
script = pathlib.Path(__file__).with_name("xek-dast.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-dast.sh" "$@"
```

# Verificacion end-to-end

```bash
# Caso happy
./scripts/xek-dast.sh --mode=dry-run && echo "PASS dry-run"

# Caso findings esperado (target sin headers de seguridad)
./scripts/xek-dast.sh --mode=sandbox --url https://example.com
echo "exit=$?"  # 1 si faltan headers
```

# Riesgos y mitigacion

| Riesgo | Mitigacion |
|---|---|
| Falso positivo por WAF que filtra HEAD | Repetir con GET; documentar en finding |
| Confundir sondeo pasivo con ataque activo | Solo HEAD/GET de recursos publicos · sin payloads |
| Cookies de sesion impresas en logs | Redaccion `[REDACTED]` antes de persistir |
| Rate-limit del target | Una pasada por run; sin reintentos agresivos |

# Bitacora evolucion

- **v0.0.1** (2026-05-20) — bootstrap stub.
- **v0.6.1** (2026-05-22) — degradado borrador→stub (commit deuda v0.6).
- **v0.7.0** (2026-06-20) — stub→borrador: checks[] pasivos read-only sobre headers/TLS/cookies/banner/exposicion · fuentes canonicas OWASP WSTG + Top 10.

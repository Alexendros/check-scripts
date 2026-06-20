---
slug: XEK_datos-criticos
ambito: DatosCriticos
maestria_funcional: revisor
estado: borrador
version: 0.7.0
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub · pendiente implementación" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "degradado borrador→stub per síntesis Ronda 002 (commit deuda v0.6)" }
  - { v: 0.7.0, fecha: 2026-06-20, cambio: "stub→borrador: detección read-only de secretos/PII (patrones de claves, .env no commiteado, credenciales hardcoded) · checks[] tipados · fuentes canónicas reales" }

objetivo: >
  Detectar y reportar datos críticos expuestos en un repo (patrones de api keys
  y tokens, .env commiteado, credenciales hardcoded, PII en fixtures/logs) en
  modo read-only sin exfiltrar ni modificar.

precondiciones_runtime:
  binarios:
    - { nombre: "bash", version_min: "5.0",  licencia: "GPL-3.0", check_cmd: "bash --version" }
    - { nombre: "git",  version_min: "2.40", licencia: "GPL-2.0", check_cmd: "git --version" }
    - { nombre: "grep", version_min: "3.0",  licencia: "GPL-3.0", check_cmd: "grep --version" }
    - { nombre: "find", version_min: "4.7",  licencia: "GPL-3.0", check_cmd: "find --version" }
  capabilities:
    - { cap: "CAP_NONE", razon: "lectura recursiva del repo target · sin escalada" }
  paths_lectura:
    - "$XEK_TARGET/**"
  paths_escritura:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_datos-criticos/"
  conexiones: []

escalada:
  adapter: "${XEK_SUDO:-sudo -A}"
  capabilities_requeridas: []
  fallback_sin_escalada: "no aplica · skill sin escalada"
  registrar_en_finding: false

fuentes_externas:
  - { tipo: tool, nombre: git,  version_min: "2.40", licencia: "GPL-2.0" }
  - { tipo: tool, nombre: grep, version_min: "3.0",  licencia: "GPL-3.0" }
  - { tipo: tool, nombre: find, version_min: "4.7",  licencia: "GPL-3.0" }
conexiones_requeridas: []

referencias_canonicas:
  - { tipo: estandar,    url: "https://owasp.org/Top10/A02_2021-Cryptographic_Failures/", cobertura: "OWASP Top 10 A02 · exposición de datos sensibles y fallos criptográficos" }
  - { tipo: doc_oficial, url: "https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html", cobertura: "OWASP Secrets Management · patrones de detección y manejo de secretos" }
verificar_referencias:
  cuando: "antes de ampliar los patrones de detección de secretos"
  como: "consultar la cheat sheet vigente; alinear nuevos patrones con sus categorías"

areas_criticas:
  permisos_user:
    - "lectura recursiva del repo target incluyendo historial git"
    - "escritura: $XDG_RUNTIME_DIR/xek-sandbox/XEK_datos-criticos/"
  fhs_tocados:
    - "$XEK_TARGET/ (solo lectura de fuentes, fixtures y logs)"
  visual_secrets:
    - "valores de api keys/tokens detectados · jamás imprimir en claro · solo ruta:línea + tipo"
    - "PII detectada · reportar ubicación, nunca el dato"
  zonas_ocultas:
    - "node_modules/, .venv/, vendor/, dist/ · excluidos del escaneo de secretos"

modos_ejecucion:
  dry-run:
    proposito: "Verificar precondiciones y listar los patrones de detección sin leer contenido sensible."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · plan textual de checks · exit 0 si parse OK"
  sandbox:
    proposito: "Correr los patrones de detección sobre un clon en sandbox; reportar ubicaciones redactadas."
    aislamiento: "git worktree en $XDG_RUNTIME_DIR/xek-sandbox/XEK_datos-criticos/<run-id>/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_datos-criticos/"
    efectos_red: "ninguno · detección local sin egress"
    salida: "findings.json (ubicaciones redactadas) en sandbox path · exit 0|1 según findings"
  real:
    proposito: "Ejecutar contra el repo real (read-only) y persistir informe con hallazgos redactados."
    precondicion: "sandbox del mismo input ha pasado en las últimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_datos-criticos/<fecha>/"
    efectos_red: "ninguno"
    salida: "informe.md + findings.json + propuesta_#N si findings ≥ severidad_min"
gate_promocion:
  regla: "modo N+1 solo si modo N exit 0|1 con plan"
  override: "--override-gate=AUTO_<timestamp ±60s>"

depende_de:
  - { slug: XEK_detecta-stack, modo: sandbox, obligatoria: true, razon: "necesita manifiesto del repo (estructura, lenguajes)" }
contrato_invocacion:
  modo_subordinado: sandbox
  promocion_real: solo_operador
  consolidacion: "json · merge por slug · schema xek/finding@v1"

checks:
  - id: "datos-001"
    descripcion: "Ningun fichero .env esta versionado en el indice git del repo"
    command_template: "! git -C \"$XEK_TARGET\" ls-files --error-unmatch '*.env' '.env' '.env.*' 2>/dev/null | grep -vE '\\.env\\.(example|sample|template)$' | grep -q ."
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "datos-002"
    descripcion: "El .gitignore ignora ficheros .env para evitar commits accidentales"
    command_template: "test -f \"$XEK_TARGET/.gitignore\" && grep -qE '(^|/)\\.env' \"$XEK_TARGET/.gitignore\""
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "datos-003"
    descripcion: "Sin claves privadas PEM commiteadas (BEGIN PRIVATE KEY) en ficheros versionados"
    command_template: "! git -C \"$XEK_TARGET\" grep -lE 'BEGIN ([A-Z ]+ )?PRIVATE KEY' -- . 2>/dev/null | grep -q ."
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "datos-004"
    descripcion: "Sin tokens de proveedor cloud hardcoded (AWS AKIA, Google AIza, GitHub ghp_)"
    command_template: "! git -C \"$XEK_TARGET\" grep -lE '(AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|ghp_[0-9A-Za-z]{36})' -- . 2>/dev/null | grep -q ."
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "datos-005"
    descripcion: "Sin credenciales hardcoded en codigo (password/secret/api_key asignado a literal)"
    command_template: "! git -C \"$XEK_TARGET\" grep -liE '(password|secret|api_?key|token)[\"'\\'' ]*[:=][\"'\\'' ]*[A-Za-z0-9/_+-]{12,}' -- '*.js' '*.ts' '*.py' '*.go' '*.rb' 2>/dev/null | grep -q ."
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "datos-006"
    descripcion: "Sin PII tipo email real en fixtures de test (excluyendo dominios example/test)"
    command_template: "! grep -rhoiE '[a-z0-9._%+-]+@[a-z0-9.-]+\\.[a-z]{2,}' \"$XEK_TARGET\" --include='*fixture*' --include='*.spec.*' --include='*.test.*' 2>/dev/null | grep -viE '@(example|test|localhost)' | grep -q ."
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]

aplicabilidad:
  cuando:
    - "manifest.target_tipo == 'repo'"
  prioridad: alta
  coste_relativo: 3

migracion_runtime:
  bash:   scripts/xek-datos-criticos.sh
  python: scripts/xek-datos-criticos.py
  zsh:    scripts/xek-datos-criticos.zsh

triggers:
  keywords: ["datos-criticos", "secret-detection", "hardcoded-credentials", "env-leak", "pii", "api-key-leak", "token-leak"]
  contextos: ["pre-PR", "post-merge", "pre-deploy"]
  cron: "0 6 * * 1"
---

# Objetivo

Detectar y reportar datos criticos expuestos en un repositorio en modo
read-only: ficheros `.env` versionados, ausencia de regla `.gitignore` para
`.env`, claves privadas PEM commiteadas, tokens de proveedor cloud hardcoded
(AWS, Google, GitHub), credenciales literales en codigo y PII tipo email real en
fixtures de test. La skill solo lee y reporta ubicaciones redactadas
(`ruta:linea` + tipo); nunca imprime el valor del secreto, lo exfiltra ni
modifica el repo.

# Cuando activar

| Si... | Entonces... |
|---|---|
| `manifest.target_tipo == 'repo'` | Ejecutar `--mode=sandbox` sobre fuentes y fixtures |
| Apertura de PR con cambios en config o fixtures | Correr `datos-001..datos-006` y bloquear si severidad high falla |
| Auditoria de higiene de secretos previa a release | Promover a `--mode=real` tras sandbox verde |

# Uso · comentario encabezado (copiar al script)

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_datos-criticos · v0.7.0 · 2026-06-20                     ║
# ║  Funcion: deteccion read-only de secretos/PII (solo reporta) ║
# ║  Variables entorno:                                          ║
# ║    XEK_TARGET         path absoluto al repo                  ║
# ║    XDG_RUNTIME_DIR    base sandbox                           ║
# ║  Uso:                                                        ║
# ║    xek-datos-criticos.sh --mode={dry-run|sandbox|real} --target <PATH>║
# ║  Exit codes:                                                 ║
# ║    0=clean · 1=findings · 2=config · 3=missing-mode · 4=ill-call║
# ╚══════════════════════════════════════════════════════════════╝
```

# Implementacion referencia (bash · fuente de verdad)

```bash
#!/usr/bin/env bash
set -euo pipefail

SLUG="XEK_datos-criticos"
VERSION="0.7.0"
MODE=""
XEK_TARGET="${XEK_TARGET:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode=*)  MODE="${1#*=}"; shift ;;
    --target)  XEK_TARGET="$2"; shift 2 ;;
    *)         echo "ill-call: $1" >&2; exit 4 ;;
  esac
done

[[ -z "$MODE" ]] && { echo "missing --mode" >&2; exit 3; }
[[ "$MODE" =~ ^(dry-run|sandbox|real)$ ]] || { echo "bad --mode" >&2; exit 2; }

if [[ "$MODE" == "dry-run" ]]; then
  echo "## ${SLUG} v${VERSION} · plan dry-run"
  echo "checks: datos-001..datos-006 (.env, claves PEM, tokens cloud, credenciales, PII)"
  echo "nota: hallazgos se reportan como ruta:linea + tipo, nunca el valor"
  echo "target: ${XEK_TARGET:-<sin --target>}"
  exit 0
fi

[[ -d "$XEK_TARGET" ]] || { echo "target inexistente: $XEK_TARGET" >&2; exit 2; }
export XEK_TARGET
# sandbox/real: ejecutar los checks[] del frontmatter sobre $XEK_TARGET; redactar valores.
```

# Adaptador Python

```python
#!/usr/bin/env python3
"""XEK_datos-criticos · adapter Python para pipelines orquestados."""
import subprocess, sys, pathlib
script = pathlib.Path(__file__).with_name("xek-datos-criticos.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-datos-criticos.sh" "$@"
```

# Verificacion end-to-end

```bash
# Caso happy
./scripts/xek-datos-criticos.sh --mode=dry-run && echo "PASS dry-run"

# Caso findings esperado (repo con .env commiteado)
./scripts/xek-datos-criticos.sh --mode=sandbox --target /tmp/repo-con-secreto
echo "exit=$?"  # 1 si detecta secretos
```

# Riesgos y mitigacion

| Riesgo | Mitigacion |
|---|---|
| Falso positivo en `.env.example` | `datos-001` excluye example/sample/template |
| Impresion accidental del secreto | Salida limitada a ruta:linea + tipo · valor redactado |
| Falso positivo de email en fixtures | `datos-006` excluye dominios example/test/localhost |
| Coste de grep sobre historial grande | Escaneo del arbol indexado · node_modules excluido |

# Bitacora evolucion

- **v0.0.1** (2026-05-20) — bootstrap stub.
- **v0.6.1** (2026-05-22) — degradado borrador→stub (commit deuda v0.6).
- **v0.7.0** (2026-06-20) — stub→borrador: checks[] read-only de secretos/PII (deteccion y reporte) · fuentes canonicas OWASP A02 + Secrets Management Cheat Sheet.

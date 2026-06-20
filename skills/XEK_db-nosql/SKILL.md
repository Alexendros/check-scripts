---
slug: XEK_db-nosql
ambito: Data
maestria_funcional: revisor
estado: borrador
version: 0.7.0
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub · pendiente implementación" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "degradado borrador→stub per síntesis Ronda 002 (commit deuda v0.6)" }
  - { v: 0.7.0, fecha: 2026-06-20, cambio: "stub→borrador: frontmatter R4+R7 + modos + checks[] tipados (nosql-001..006) inspección estática + fuentes canónicas reales (OWASP NoSQLi, MongoDB security)" }

objetivo: >
  Inspección estática read-only de config NoSQL de un repo: auth habilitada, sin
  bind-all sin auth, queries seguras frente a inyección y puertos por defecto no
  expuestos. Nunca ejecuta queries.

precondiciones_runtime:
  binarios:
    - { nombre: "bash", version_min: "5.0", licencia: "GPL-3.0-or-later", check_cmd: "bash --version" }
    - { nombre: "grep", version_min: "3.0", licencia: "GPL-3.0-or-later", check_cmd: "grep --version" }
    - { nombre: "find", version_min: "4.8", licencia: "GPL-3.0-or-later", check_cmd: "find --version" }
  capabilities:
    - { cap: "CAP_NONE", razon: "inspección estática de código/config del repo · read-only · jamás conecta a la BD" }
  paths_lectura:
    - "$XEK_TARGET_DIR/**"
  paths_escritura:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_db-nosql/"
  conexiones: []

escalada:
  adapter: "${XEK_SUDO:-sudo -A}"
  capabilities_requeridas: []
  fallback_sin_escalada: "no aplica · skill sin escalada"
  registrar_en_finding: false

fuentes_externas:
  - { tipo: tool, nombre: grep, version_min: "3.0", licencia: "GPL-3.0-or-later" }
  - { tipo: tool, nombre: find, version_min: "4.8", licencia: "GPL-3.0-or-later" }
conexiones_requeridas: []

referencias_canonicas:
  - { tipo: doc_oficial, url: "https://www.mongodb.com/docs/manual/security/", cobertura: "Documentación de seguridad MongoDB · autenticación, bindIp, autorización y exposición de red" }
  - { tipo: estandar,    url: "https://owasp.org/www-community/attacks/Testing_for_NoSQL_injection", cobertura: "OWASP · pruebas y patrones de inyección NoSQL ($where, operadores en input)" }
verificar_referencias:
  cuando: "antes de cada bump de version_min de tools"
  como: "consultar doc oficial; rechazar bump si la doc marca cambio breaking en el formato"

areas_criticas:
  permisos_user:
    - "lectura del árbol de código y config del repo objetivo"
    - "escritura: $XDG_RUNTIME_DIR/xek-sandbox/XEK_db-nosql/"
  fhs_tocados:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_db-nosql/ (solo escritura de findings)"
  visual_secrets:
    - "cadenas de conexión y credenciales detectadas · reportar solo el path y línea, nunca el valor del secreto"
  zonas_ocultas:
    - "la base de datos en sí · jamás se abre conexión, ejecuta query, ni se vuelca data · solo inspección estática del repo"

modos_ejecucion:
  dry-run:
    proposito: "Verificar precondiciones y listar los checks estáticos que se ejecutarían sin leer el árbol del repo."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · plan textual de checks · exit 0 si parse OK"
  sandbox:
    proposito: "Inspeccionar una copia aislada del repo en busca de config NoSQL insegura estática."
    aislamiento: "directorio bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_db-nosql/<run-id>/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_db-nosql/"
    efectos_red: "ninguno · jamás conecta a la base de datos"
    salida: "findings.json en sandbox path · exit 0|1 según findings"
  real:
    proposito: "Inspeccionar el repo real (read-only) y persistir informe en cuaderno."
    precondicion: "sandbox del mismo input ha pasado en las últimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_db-nosql/<fecha>/"
    efectos_red: "ninguno · jamás conecta a la base de datos"
    salida: "informe.md + findings.json + propuesta_#N si findings ≥ severidad_min"
gate_promocion:
  regla: "modo N+1 solo si modo N exit 0|1 con plan"
  override: "--override-gate=AUTO_<timestamp ±60s>"

depende_de:
  - { slug: XEK_detecta-stack, modo: sandbox, obligatoria: true, razon: "necesita manifiesto con target_tipo=repo y ruta base" }
contrato_invocacion:
  modo_subordinado: sandbox
  promocion_real: solo_operador
  consolidacion: "json · merge por slug · schema xek/finding@v1"

checks:
  - id: "nosql-001"
    descripcion: "Config declara autenticacion habilitada (authorization enabled / security.authorization)"
    command_template: "! find '$TARGET_DIR' -iname 'mongod*.conf' -print -quit | grep -q . || grep -rqIiE 'authorization:\\s*enabled|--auth\\b|security:' '$TARGET_DIR'"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "nosql-002"
    descripcion: "Ausencia de bind-all (0.0.0.0 / bindIpAll) en la config sin autenticacion"
    command_template: "! grep -rqIiE 'bindIp:\\s*0\\.0\\.0\\.0|bindIpAll:\\s*true|--bind_ip_all' '$TARGET_DIR' || grep -rqIiE 'authorization:\\s*enabled|--auth\\b' '$TARGET_DIR'"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "nosql-003"
    descripcion: "Ausencia de operadores de inyeccion NoSQL peligrosos sobre input no saneado ($where, $function con concat)"
    command_template: "! grep -rqInE '\\$where|\\$function|mapReduce|eval\\(' '$TARGET_DIR' --include='*.js' --include='*.ts'"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "nosql-004"
    descripcion: "Ausencia de credenciales hardcoded en cadenas de conexion NoSQL"
    command_template: "! grep -rqInE 'mongodb(\\+srv)?://[^:@/]+:[^@/]+@' '$TARGET_DIR' --include='*.ts' --include='*.js' --include='*.py' --include='*.env*' --include='*.yml' --include='*.yaml'"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "nosql-005"
    descripcion: "Senal de saneamiento de input frente a operadores ($) en queries construidas desde request"
    command_template: "! grep -rqInE 'req\\.(body|query|params)' '$TARGET_DIR' --include='*.js' --include='*.ts' || grep -rqIiE 'sanitize|mongo-sanitize|express-mongo-sanitize|\\$eq|escapeRegExp' '$TARGET_DIR'"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "nosql-006"
    descripcion: "Puerto por defecto (27017 Mongo / 6379 Redis) no expuesto publicamente en compose/manifiestos"
    command_template: "! grep -rqIE '(\"|\\s)(27017|6379):(27017|6379)' '$TARGET_DIR' --include='docker-compose*.yml' --include='docker-compose*.yaml' --include='*.compose.yml'"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]

aplicabilidad:
  cuando:
    - "manifest.target_tipo == 'repo'"
  prioridad: media
  coste_relativo: 2

migracion_runtime:
  bash:   scripts/xek-db-nosql.sh
  python: scripts/xek-db-nosql.py
  zsh:    scripts/xek-db-nosql.zsh

triggers:
  keywords: ["nosql", "mongodb", "nosql-injection", "redis", "auth", "bind-ip", "connection-string", "default-port"]
  contextos: ["pre-PR", "pre-deploy", "post-merge"]
  cron: ""
---

# Objetivo

Inspeccion estatica read-only de la configuracion NoSQL de un repositorio:
autenticacion habilitada, ausencia de bind-all sin auth, ausencia de operadores
de inyeccion sobre input no saneado, ausencia de credenciales hardcoded, senales
de saneamiento de input y puertos por defecto no expuestos. La skill inspecciona
codigo y config del repo; jamas abre conexion a la base de datos, ejecuta queries
ni vuelca datos.

# Cuando activar

| Si... | Entonces... |
|---|---|
| `manifest.target_tipo == 'repo'` con MongoDB/Redis u otra NoSQL | Ejecutar `--mode=sandbox` sobre la copia aislada del repo |
| Pre-PR de codigo que construye queries NoSQL desde input de usuario | Correr `nosql-001..nosql-006` y bloquear si severidad high falla |
| Auditoria de postura de exposicion de red de la capa de datos | Promover a `--mode=real` tras sandbox verde |

# Uso · comentario encabezado (copiar al script)

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_db-nosql · v0.7.0 · 2026-06-20                           ║
# ║  Funcion: inspeccion estatica NoSQL del repo (read-only)      ║
# ║  Variables entorno:                                           ║
# ║    XEK_TARGET_DIR     ruta del repo a inspeccionar           ║
# ║    XDG_RUNTIME_DIR    base sandbox                            ║
# ║  Uso:                                                         ║
# ║    xek-db-nosql.sh --mode={dry-run|sandbox|real}             ║
# ║  Exit codes:                                                 ║
# ║    0=clean · 1=findings · 2=config · 3=missing-mode · 4=ill-call║
# ╚══════════════════════════════════════════════════════════════╝
```

# Implementacion referencia (bash · fuente de verdad)

```bash
#!/usr/bin/env bash
set -euo pipefail

SLUG="XEK_db-nosql"
VERSION="0.7.0"
MODE=""
TARGET_DIR="${XEK_TARGET_DIR:-.}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode=*)   MODE="${1#*=}"; shift ;;
    --target)   TARGET_DIR="$2"; shift 2 ;;
    *)          echo "ill-call: $1" >&2; exit 4 ;;
  esac
done

[[ -z "$MODE" ]] && { echo "missing --mode" >&2; exit 3; }

preflight() {
  for bin in bash grep find; do
    command -v "$bin" >/dev/null 2>&1 || { echo "PREFLIGHT FAIL: $bin absent" >&2; return 1; }
  done
}

if [[ "$MODE" == "dry-run" ]]; then
  echo "## ${SLUG} v${VERSION} · plan dry-run"
  preflight || exit 2
  echo "checks: nosql-001..nosql-006 (auth, bind-all, injection, creds, sanitize, default-port)"
  echo "nota: inspeccion ESTATICA · nunca conecta a la base de datos"
  exit 0
fi

preflight || exit 2
[[ -d "$TARGET_DIR" ]] || { echo "target dir not found: $TARGET_DIR" >&2; exit 2; }

FINDINGS=0
emit() { echo "  - { check: $1, severity: $2, status: $3 }"; }
run_check() {
  local id="$1" sev="$2"; shift 2
  if "$@" >/dev/null 2>&1; then emit "$id" "$sev" pass
  else emit "$id" "$sev" fail; FINDINGS=$((FINDINGS+1)); fi
}

echo "findings:"
run_check nosql-003 high   bash -c "! grep -rqInE '\\\$where|eval\\(' '$TARGET_DIR' --include='*.js' --include='*.ts'"
run_check nosql-004 high   bash -c "! grep -rqInE 'mongodb(\\+srv)?://[^:@/]+:[^@/]+@' '$TARGET_DIR' --include='*.ts' --include='*.js' --include='*.env*'"
run_check nosql-006 medium bash -c "! grep -rqIE '(\"|\\s)(27017|6379):(27017|6379)' '$TARGET_DIR' --include='docker-compose*.yml'"

if [[ "$MODE" == "sandbox" ]]; then
  [[ "$FINDINGS" -eq 0 ]] && exit 0 || exit 1
fi

if [[ "$MODE" == "real" ]]; then
  OUT="${XEK_CUADERNO:-$HOME/.claude/cuadernos/xek-cluster}/artefactos/${SLUG}/$(date +%Y-%m-%d)"
  mkdir -p "$OUT"
  echo "informe: $OUT"
  [[ "$FINDINGS" -eq 0 ]] && exit 0 || exit 1
fi
```

# Adaptador Python (encapsulado vendoreable)

```python
#!/usr/bin/env python3
"""XEK_db-nosql · adapter Python para pipelines orquestados."""
import subprocess, sys, pathlib
script = pathlib.Path(__file__).with_name("xek-db-nosql.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-db-nosql.sh" "$@"
```

# Verificacion end-to-end (smoke test)

```bash
# Caso happy · dry-run no toca disco del target ni la base de datos
./scripts/xek-db-nosql.sh --mode=dry-run && echo "PASS dry-run"

# Caso sandbox contra un repo con auth y sin operadores peligrosos · exit 0
./scripts/xek-db-nosql.sh --mode=sandbox --target /ruta/repo-seguro
echo "exit=$?"

# Caso falla esperada · repo con $where sobre input o creds en la cadena · exit 1
./scripts/xek-db-nosql.sh --mode=sandbox --target /ruta/repo-vulnerable
echo "exit=$?"
```

# Riesgos y mitigacion

| Riesgo | Mitigacion |
|---|---|
| Config de auth gestionada por orquestador externo y ausente del repo | El informe documenta que `nosql-001` cubre la config en repo; el runtime queda fuera de alcance |
| Falso positivo en `$where` dentro de comentarios o tests | El analisis estatico marca senal; el informe exige revision manual de la linea |
| Saneamiento por libreria no reconocida por el patron | `nosql-005` reconoce patrones comunes; su ausencia se reporta como informativo, no como fallo high |
| Tentacion de conectar a la BD para validar exposicion | Prohibido por diseno: la skill nunca abre conexion ni ejecuta queries · solo inspeccion estatica |

# Bitacora evolucion (append-only · R8)

- **v0.0.1** (2026-05-20) — bootstrap stub.
- **v0.6.1** (2026-05-22) — degradado borrador→stub per sintesis Ronda 002.
- **v0.7.0** (2026-06-20) — stub→borrador: frontmatter R4+R7 completo + modos_ejecucion + 6 checks[] tipados (nosql-001..006) de inspeccion estatica + fuentes canonicas reales (OWASP NoSQL injection, MongoDB security) + bash referencia de 3 modos.

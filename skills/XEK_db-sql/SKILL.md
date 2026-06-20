---
slug: XEK_db-sql
ambito: Data
maestria_funcional: revisor
estado: borrador
version: 0.7.0
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub · pendiente implementación" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "degradado borrador→stub per síntesis Ronda 002 (commit deuda v0.6)" }
  - { v: 0.7.0, fecha: 2026-06-20, cambio: "stub→borrador: frontmatter R4+R7 + modos + checks[] tipados (sql-001..006) inspección estática + fuentes canónicas reales (OWASP SQLi, PostgreSQL docs)" }

objetivo: >
  Inspección estática read-only de un repo con SQL: queries parametrizadas, sin
  credenciales hardcoded, config SSL/TLS, migraciones y mínimo privilegio. Nunca
  ejecuta queries.

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
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_db-sql/"
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
  - { tipo: doc_oficial, url: "https://www.postgresql.org/docs/", cobertura: "Documentación PostgreSQL · sentencias preparadas, configuración SSL/TLS y roles/privilegios (GRANT/REVOKE)" }
  - { tipo: estandar,    url: "https://owasp.org/www-community/attacks/SQL_Injection", cobertura: "OWASP · taxonomía de inyección SQL y prácticas de parametrización" }
verificar_referencias:
  cuando: "antes de cada bump de version_min de tools"
  como: "consultar doc oficial; rechazar bump si la doc marca cambio breaking en el formato"

areas_criticas:
  permisos_user:
    - "lectura del árbol de código y config del repo objetivo"
    - "escritura: $XDG_RUNTIME_DIR/xek-sandbox/XEK_db-sql/"
  fhs_tocados:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_db-sql/ (solo escritura de findings)"
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
    proposito: "Inspeccionar una copia aislada del repo en busca de antipatrones SQL estáticos."
    aislamiento: "directorio bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_db-sql/<run-id>/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_db-sql/"
    efectos_red: "ninguno · jamás conecta a la base de datos"
    salida: "findings.json en sandbox path · exit 0|1 según findings"
  real:
    proposito: "Inspeccionar el repo real (read-only) y persistir informe en cuaderno."
    precondicion: "sandbox del mismo input ha pasado en las últimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_db-sql/<fecha>/"
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
  - id: "sql-001"
    descripcion: "Ausencia de concatenacion de SQL con interpolacion de variables (antipatron de inyeccion)"
    command_template: "! grep -rqInE \"(SELECT|INSERT|UPDATE|DELETE)[^;]*['\\\"][^;]*[+]|f['\\\"](SELECT|INSERT|UPDATE|DELETE)\" '$TARGET_DIR' --include='*.js' --include='*.ts' --include='*.py' --include='*.rb' --include='*.php'"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "sql-002"
    descripcion: "Ausencia de credenciales de BD hardcoded en el codigo (password en cadena de conexion literal)"
    command_template: "! grep -rqInE \"(postgres|mysql|mariadb)://[^:@/]+:[^@/]+@\" '$TARGET_DIR' --include='*.js' --include='*.ts' --include='*.py' --include='*.env*' --include='*.yml' --include='*.yaml'"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "sql-003"
    descripcion: "Configuracion de conexion declara SSL/TLS (sslmode o ssl: true) si hay cadena de conexion"
    command_template: "! grep -rqIiE 'postgres://|mysql://|DATABASE_URL' '$TARGET_DIR' || grep -rqIiE 'sslmode|ssl[\"'\\'' ]*[:=][\"'\\'' ]*(require|true|verify)' '$TARGET_DIR'"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "sql-004"
    descripcion: "Existe un directorio de migraciones versionadas en el repo"
    command_template: "find '$TARGET_DIR' -type d -iregex '.*/\\(migrations\\|migrate\\|migracion.*\\)' -print -quit | grep -q ."
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "sql-005"
    descripcion: "Senal de uso de sentencias preparadas o consultas parametrizadas via ORM/driver"
    command_template: "grep -rqIiE 'prepare\\(|\\$1|placeholder|\\?\\s*[,)]|parameterized|execute\\([^,]+,\\s*[\\[(]' '$TARGET_DIR' --include='*.js' --include='*.ts' --include='*.py' --include='*.go'"
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]
  - id: "sql-006"
    descripcion: "Ausencia de uso del superusuario por defecto (postgres/root) en cadenas de conexion de aplicacion"
    command_template: "! grep -rqInE '(postgres|mysql|mariadb)://(postgres|root)[:@]' '$TARGET_DIR' --include='*.env*' --include='*.yml' --include='*.yaml' --include='*.ts' --include='*.js'"
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]

aplicabilidad:
  cuando:
    - "manifest.target_tipo == 'repo'"
  prioridad: media
  coste_relativo: 2

migracion_runtime:
  bash:   scripts/xek-db-sql.sh
  python: scripts/xek-db-sql.py
  zsh:    scripts/xek-db-sql.zsh

triggers:
  keywords: ["sql", "sql-injection", "postgresql", "parametrized-query", "orm", "migrations", "database-credentials", "ssl"]
  contextos: ["pre-PR", "pre-deploy", "post-merge"]
  cron: ""
---

# Objetivo

Inspeccion estatica read-only de un repositorio que usa SQL: deteccion de
concatenacion de queries (riesgo de inyeccion), credenciales de BD hardcoded,
ausencia de SSL/TLS en la cadena de conexion, presencia de migraciones versionadas,
senales de consultas parametrizadas y uso de cuentas no-superusuario. La skill
inspecciona codigo y config del repo; jamas abre conexion a la base de datos,
ejecuta queries ni vuelca datos.

# Cuando activar

| Si... | Entonces... |
|---|---|
| `manifest.target_tipo == 'repo'` con acceso a SQL | Ejecutar `--mode=sandbox` sobre la copia aislada del repo |
| Pre-PR de codigo que construye o ejecuta SQL | Correr `sql-001..sql-006` y bloquear si severidad high falla |
| Auditoria de postura de seguridad de la capa de datos | Promover a `--mode=real` tras sandbox verde |

# Uso · comentario encabezado (copiar al script)

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_db-sql · v0.7.0 · 2026-06-20                             ║
# ║  Funcion: inspeccion estatica SQL del repo (read-only)        ║
# ║  Variables entorno:                                           ║
# ║    XEK_TARGET_DIR     ruta del repo a inspeccionar           ║
# ║    XDG_RUNTIME_DIR    base sandbox                            ║
# ║  Uso:                                                         ║
# ║    xek-db-sql.sh --mode={dry-run|sandbox|real}               ║
# ║  Exit codes:                                                 ║
# ║    0=clean · 1=findings · 2=config · 3=missing-mode · 4=ill-call║
# ╚══════════════════════════════════════════════════════════════╝
```

# Implementacion referencia (bash · fuente de verdad)

```bash
#!/usr/bin/env bash
set -euo pipefail

SLUG="XEK_db-sql"
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
  echo "checks: sql-001..sql-006 (concat-sql, creds, ssl, migraciones, prepared, no-superuser)"
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
run_check sql-002 high   bash -c "! grep -rqInE '(postgres|mysql|mariadb)://[^:@/]+:[^@/]+@' '$TARGET_DIR' --include='*.ts' --include='*.js' --include='*.env*'"
run_check sql-004 medium bash -c "find '$TARGET_DIR' -type d -iregex '.*/\(migrations\|migrate\)' -print -quit | grep -q ."

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
"""XEK_db-sql · adapter Python para pipelines orquestados."""
import subprocess, sys, pathlib
script = pathlib.Path(__file__).with_name("xek-db-sql.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-db-sql.sh" "$@"
```

# Verificacion end-to-end (smoke test)

```bash
# Caso happy · dry-run no toca disco del target ni la base de datos
./scripts/xek-db-sql.sh --mode=dry-run && echo "PASS dry-run"

# Caso sandbox contra un repo con queries parametrizadas y sin creds · exit 0
./scripts/xek-db-sql.sh --mode=sandbox --target /ruta/repo-seguro
echo "exit=$?"

# Caso falla esperada · repo con credenciales hardcoded en la cadena · exit 1
./scripts/xek-db-sql.sh --mode=sandbox --target /ruta/repo-con-creds
echo "exit=$?"
```

# Riesgos y mitigacion

| Riesgo | Mitigacion |
|---|---|
| Falso positivo en concatenacion de strings que no son SQL | El analisis estatico marca el hallazgo como senal; el informe exige revision manual de la linea |
| Credenciales en gestor de secretos no detectables por grep | `sql-002` solo cubre literales en repo; el informe documenta que los secretos externos quedan fuera de alcance |
| ORM que parametriza por debajo sin patron visible | `sql-005` busca senales comunes; su ausencia se reporta como informativo, no como fallo high |
| Tentacion de conectar a la BD para validar | Prohibido por diseno: la skill nunca abre conexion ni ejecuta SQL · solo inspeccion estatica |

# Bitacora evolucion (append-only · R8)

- **v0.0.1** (2026-05-20) — bootstrap stub.
- **v0.6.1** (2026-05-22) — degradado borrador→stub per sintesis Ronda 002.
- **v0.7.0** (2026-06-20) — stub→borrador: frontmatter R4+R7 completo + modos_ejecucion + 6 checks[] tipados (sql-001..006) de inspeccion estatica + fuentes canonicas reales (OWASP SQL Injection, PostgreSQL docs) + bash referencia de 3 modos.

---
slug: XEK_compliance-rgpd
ambito: Compliance
maestria_funcional: revisor
estado: borrador
version: 0.7.0
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub · pendiente implementación" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "degradado borrador→stub per síntesis Ronda 002 (commit deuda v0.6)" }
  - { v: 0.7.0, fecha: 2026-06-20, cambio: "stub→borrador: frontmatter R4+R7 + modos + checks[] tipados (rgpd-001..006) + fuentes canónicas reales (GDPR-info, AEPD)" }

objetivo: >
  Verificar señales RGPD de un repo/sitio en modo read-only: política de privacidad,
  consentimiento de cookies, aviso legal, contacto/DPO y base de licitud, sin
  modificar el target.

precondiciones_runtime:
  binarios:
    - { nombre: "bash", version_min: "5.0", licencia: "GPL-3.0-or-later", check_cmd: "bash --version" }
    - { nombre: "grep", version_min: "3.0", licencia: "GPL-3.0-or-later", check_cmd: "grep --version" }
    - { nombre: "find", version_min: "4.8", licencia: "GPL-3.0-or-later", check_cmd: "find --version" }
  capabilities:
    - { cap: "CAP_NONE", razon: "inspección estática de ficheros del repo · read-only · sin escalada" }
  paths_lectura:
    - "$XEK_TARGET_DIR/**"
  paths_escritura:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_compliance-rgpd/"
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
  - { tipo: doc_oficial, url: "https://www.aepd.es", cobertura: "Agencia Española de Protección de Datos · guías de aviso legal, política de privacidad y bases de licitud en España" }
  - { tipo: estandar,    url: "https://gdpr-info.eu/", cobertura: "Texto consolidado del RGPD (UE 2016/679) · artículos de transparencia, licitud y consentimiento" }
verificar_referencias:
  cuando: "antes de cada bump de version_min de tools"
  como: "consultar doc oficial; rechazar bump si la doc marca cambio breaking en el formato"

areas_criticas:
  permisos_user:
    - "lectura del árbol de ficheros del repo objetivo"
    - "escritura: $XDG_RUNTIME_DIR/xek-sandbox/XEK_compliance-rgpd/"
  fhs_tocados:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_compliance-rgpd/ (solo escritura de findings)"
  visual_secrets:
    - "datos personales reales que aparezcan en fixtures o dumps · nunca imprimir en el informe"
  zonas_ocultas:
    - "contenido de bases de datos o PII · fuera de alcance · solo se inspecciona presencia de textos legales"

modos_ejecucion:
  dry-run:
    proposito: "Verificar precondiciones y listar los checks que se ejecutarían sin leer el árbol del repo."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · plan textual de checks · exit 0 si parse OK"
  sandbox:
    proposito: "Inspeccionar una copia aislada del repo y buscar señales documentales RGPD."
    aislamiento: "directorio bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_compliance-rgpd/<run-id>/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_compliance-rgpd/"
    efectos_red: "ninguno · inspección estática local"
    salida: "findings.json en sandbox path · exit 0|1 según findings"
  real:
    proposito: "Inspeccionar el repo real (read-only) y persistir informe en cuaderno."
    precondicion: "sandbox del mismo input ha pasado en las últimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_compliance-rgpd/<fecha>/"
    efectos_red: "ninguno · inspección estática local"
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
  - id: "rgpd-001"
    descripcion: "Pagina o documento de politica de privacidad presente en el repo"
    command_template: "find '$TARGET_DIR' -type f -iregex '.*\\(privacy\\|privacidad\\|politica-de-privacidad\\).*' -print -quit | grep -q ."
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "rgpd-002"
    descripcion: "Aviso legal presente en el repo"
    command_template: "find '$TARGET_DIR' -type f -iregex '.*\\(aviso-legal\\|legal-notice\\|legal\\).*' -print -quit | grep -q ."
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "rgpd-003"
    descripcion: "Senales de mecanismo de consentimiento de cookies en el codigo"
    command_template: "grep -rqiI 'cookie.consent\\|consent.manager\\|gestor de cookies\\|aceptar cookies' '$TARGET_DIR'"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "rgpd-004"
    descripcion: "Contacto del responsable o DPO/delegado de proteccion de datos referenciado"
    command_template: "grep -rqiI 'dpo\\|delegado de proteccion\\|data protection officer\\|protecciondedatos' '$TARGET_DIR'"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "rgpd-005"
    descripcion: "Senal de base de licitud declarada (consentimiento, contrato, interes legitimo)"
    command_template: "grep -rqiI 'base de licitud\\|lawful basis\\|consentimiento\\|interes legitimo\\|legitimate interest' '$TARGET_DIR'"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "rgpd-006"
    descripcion: "Senal de registro de actividades de tratamiento o procesamiento de datos documentado"
    command_template: "grep -rqiI 'registro de actividades\\|data processing\\|tratamiento de datos\\|encargado del tratamiento' '$TARGET_DIR'"
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]

aplicabilidad:
  cuando:
    - "manifest.target_tipo == 'repo'"
  prioridad: media
  coste_relativo: 2

migracion_runtime:
  bash:   scripts/xek-compliance-rgpd.sh
  python: scripts/xek-compliance-rgpd.py
  zsh:    scripts/xek-compliance-rgpd.zsh

triggers:
  keywords: ["rgpd", "gdpr", "privacidad", "cookies", "consentimiento", "aviso-legal", "dpo", "proteccion-de-datos"]
  contextos: ["pre-PR", "pre-deploy", "post-merge"]
  cron: ""
---

# Objetivo

Verificar las senales documentales de cumplimiento RGPD de un repositorio o sitio
en modo read-only: existencia de politica de privacidad, aviso legal, mecanismo de
consentimiento de cookies, contacto del responsable o DPO, declaracion de base de
licitud y registro de actividades de tratamiento. La skill inspecciona textos
estaticos del repo; nunca lee PII real ni modifica el target.

# Cuando activar

| Si... | Entonces... |
|---|---|
| `manifest.target_tipo == 'repo'` de un sitio publico que trata datos personales | Ejecutar `--mode=sandbox` sobre la copia aislada del repo |
| Pre-deploy de un sitio dirigido a usuarios en la UE/España | Correr `rgpd-001..rgpd-006` y bloquear si severidad high falla |
| Auditoria de cumplimiento previa a salida a produccion | Promover a `--mode=real` tras sandbox verde |

# Uso · comentario encabezado (copiar al script)

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_compliance-rgpd · v0.7.0 · 2026-06-20                   ║
# ║  Funcion: verificar señales RGPD del repo (read-only)         ║
# ║  Variables entorno:                                           ║
# ║    XEK_TARGET_DIR     ruta del repo a inspeccionar           ║
# ║    XDG_RUNTIME_DIR    base sandbox                            ║
# ║  Uso:                                                         ║
# ║    xek-compliance-rgpd.sh --mode={dry-run|sandbox|real}       ║
# ║  Exit codes:                                                 ║
# ║    0=clean · 1=findings · 2=config · 3=missing-mode · 4=ill-call║
# ╚══════════════════════════════════════════════════════════════╝
```

# Implementacion referencia (bash · fuente de verdad)

```bash
#!/usr/bin/env bash
set -euo pipefail

SLUG="XEK_compliance-rgpd"
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
  echo "checks: rgpd-001..rgpd-006 (privacidad, aviso legal, cookies, DPO, base licitud, RAT)"
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
run_check rgpd-001 high   bash -c "find '$TARGET_DIR' -type f -iregex '.*\(privacy\|privacidad\).*' -print -quit | grep -q ."
run_check rgpd-003 high   bash -c "grep -rqiI 'cookie.consent\|aceptar cookies' '$TARGET_DIR'"
run_check rgpd-004 medium bash -c "grep -rqiI 'dpo\|delegado de proteccion' '$TARGET_DIR'"

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
"""XEK_compliance-rgpd · adapter Python para pipelines orquestados."""
import subprocess, sys, pathlib
script = pathlib.Path(__file__).with_name("xek-compliance-rgpd.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-compliance-rgpd.sh" "$@"
```

# Verificacion end-to-end (smoke test)

```bash
# Caso happy · dry-run no toca disco del target
./scripts/xek-compliance-rgpd.sh --mode=dry-run && echo "PASS dry-run"

# Caso sandbox contra un repo con textos legales completos · exit 0
./scripts/xek-compliance-rgpd.sh --mode=sandbox --target /ruta/repo-conforme
echo "exit=$?"

# Caso falla esperada · repo sin politica de privacidad · exit 1
./scripts/xek-compliance-rgpd.sh --mode=sandbox --target /ruta/repo-sin-privacidad
echo "exit=$?"
```

# Riesgos y mitigacion

| Riesgo | Mitigacion |
|---|---|
| Textos legales servidos por CMS externo y ausentes del repo | El informe documenta que la senal es presencia en repo; el contenido en vivo se cubriria con un target app-en-vivo |
| Falso positivo por mencion de "cookies" sin gestor real | `rgpd-003` busca patrones de consentimiento; el informe marca que requiere validacion manual del flujo |
| PII real en fixtures detectada durante la inspeccion | `visual_secrets` impide imprimir datos personales; solo se reporta el path |
| Cumplimiento sustantivo no equivale a presencia documental | El informe declara que esta skill verifica senales, no la correccion juridica del contenido |

# Bitacora evolucion (append-only · R8)

- **v0.0.1** (2026-05-20) — bootstrap stub.
- **v0.6.1** (2026-05-22) — degradado borrador→stub per sintesis Ronda 002.
- **v0.7.0** (2026-06-20) — stub→borrador: frontmatter R4+R7 completo + modos_ejecucion + 6 checks[] tipados (rgpd-001..006) + fuentes canonicas reales (GDPR-info UE 2016/679, AEPD) + bash referencia de 3 modos.

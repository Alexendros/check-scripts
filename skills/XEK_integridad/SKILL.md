---
slug: XEK_integridad
ambito: Integridad
maestria_funcional: revisor
estado: borrador
version: 0.7.0
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub · pendiente implementación" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "degradado borrador→stub per síntesis Ronda 002 (commit deuda v0.6)" }
  - { v: 0.7.0, fecha: 2026-06-20, cambio: "stub→borrador: integridad cadena de suministro read-only (SRI, hashes lockfile, provenance SLSA, firmas sigstore) · checks[] tipados · fuentes canónicas reales" }

objetivo: >
  Verificar la integridad de la cadena de suministro de un repo (SRI, hashes de
  lockfile, provenance SLSA, firmas sigstore) en modo read-only sin modificar
  artefactos.

precondiciones_runtime:
  binarios:
    - { nombre: "bash", version_min: "5.0",  licencia: "GPL-3.0", check_cmd: "bash --version" }
    - { nombre: "find", version_min: "4.7",  licencia: "GPL-3.0", check_cmd: "find --version" }
    - { nombre: "grep", version_min: "3.0",  licencia: "GPL-3.0", check_cmd: "grep --version" }
    - { nombre: "jq",   version_min: "1.7",  licencia: "MIT",     check_cmd: "jq --version" }
    - { nombre: "test", version_min: "8.0",  licencia: "GPL-3.0", check_cmd: "test --help" }
  capabilities:
    - { cap: "CAP_NONE", razon: "lectura recursiva del repo target · sin escalada" }
  paths_lectura:
    - "$XEK_TARGET/**/*.html"
    - "$XEK_TARGET/**/*.lock"
    - "$XEK_TARGET/.github/workflows/*.yml"
  paths_escritura:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_integridad/"
  conexiones:
    - { destino: "rekor.sigstore.dev", proto: https, auth: none }

escalada:
  adapter: "${XEK_SUDO:-sudo -A}"
  capabilities_requeridas: []
  fallback_sin_escalada: "no aplica · skill sin escalada"
  registrar_en_finding: false

fuentes_externas:
  - { tipo: tool, nombre: jq,   version_min: "1.7", licencia: "MIT" }
  - { tipo: tool, nombre: grep, version_min: "3.0", licencia: "GPL-3.0" }
  - { tipo: tool, nombre: find, version_min: "4.7", licencia: "GPL-3.0" }
conexiones_requeridas:
  - { destino: "rekor.sigstore.dev", proto: https, auth: none }

referencias_canonicas:
  - { tipo: estandar,    url: "https://slsa.dev", cobertura: "SLSA · niveles de provenance y requisitos de cadena de suministro" }
  - { tipo: doc_oficial, url: "https://www.sigstore.dev", cobertura: "Sigstore · firma y verificación de artefactos y provenance" }
  - { tipo: estandar,    url: "https://developer.mozilla.org/en-US/docs/Web/Security/Subresource_Integrity", cobertura: "Subresource Integrity · atributo integrity en scripts externos" }
verificar_referencias:
  cuando: "antes de cada cambio en la semántica de los checks de provenance"
  como: "consultar especificación SLSA/SRI; rechazar si la categoría cambió de definición"

areas_criticas:
  permisos_user:
    - "lectura recursiva del repo target"
    - "escritura: $XDG_RUNTIME_DIR/xek-sandbox/XEK_integridad/"
  fhs_tocados:
    - "$XEK_TARGET/ (solo lectura de HTML, lockfiles y workflows)"
  visual_secrets:
    - "claves de firma o tokens en workflows · redactar con [REDACTED]"
  zonas_ocultas:
    - "node_modules/, dist/, build/ · evaluar fuentes, no artefactos generados"

modos_ejecucion:
  dry-run:
    proposito: "Verificar precondiciones y listar los checks de integridad sin egress a transparencia."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · plan textual de checks · exit 0 si parse OK"
  sandbox:
    proposito: "Correr los checks sobre un clon en sandbox; consultar transparencia sigstore read-only."
    aislamiento: "git worktree en $XDG_RUNTIME_DIR/xek-sandbox/XEK_integridad/<run-id>/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_integridad/"
    efectos_red: "GET read-only a rekor.sigstore.dev para verificación de firmas"
    salida: "findings.json en sandbox path · exit 0|1 según findings"
  real:
    proposito: "Ejecutar contra el repo real (read-only) y persistir informe en cuaderno."
    precondicion: "sandbox del mismo input ha pasado en las últimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_integridad/<fecha>/"
    efectos_red: "GET read-only a rekor.sigstore.dev"
    salida: "informe.md + findings.json + propuesta_#N si findings ≥ severidad_min"
gate_promocion:
  regla: "modo N+1 solo si modo N exit 0|1 con plan"
  override: "--override-gate=AUTO_<timestamp ±60s>"

depende_de:
  - { slug: XEK_detecta-stack, modo: sandbox, obligatoria: true, razon: "necesita manifiesto del repo (workflows, lockfiles)" }
contrato_invocacion:
  modo_subordinado: sandbox
  promocion_real: solo_operador
  consolidacion: "json · merge por slug · schema xek/finding@v1"

checks:
  - id: "integridad-001"
    descripcion: "Todo script externo en HTML con src de CDN declara atributo integrity (SRI)"
    command_template: "! grep -rilE '<script[^>]+src=.https?://' \"$XEK_TARGET\" --include='*.html' | xargs -r grep -LE '<script[^>]+src=.https?://[^>]+integrity=' | grep -q ."
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "integridad-002"
    descripcion: "El lockfile npm declara hashes de integridad para los paquetes resueltos"
    command_template: "! test -f \"$XEK_TARGET/package-lock.json\" || jq -e '[.. | objects | select(has(\"resolved\")) | select(has(\"integrity\") | not)] | length == 0' \"$XEK_TARGET/package-lock.json\""
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "integridad-003"
    descripcion: "El lockfile pnpm contiene hashes de integridad (campo integrity)"
    command_template: "! test -f \"$XEK_TARGET/pnpm-lock.yaml\" || grep -qE 'integrity:' \"$XEK_TARGET/pnpm-lock.yaml\""
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "integridad-004"
    descripcion: "Existe un workflow de CI que genera provenance o attestation (SLSA)"
    command_template: "grep -rilE 'slsa-framework/slsa-github-generator|actions/attest-build-provenance|attestations:[[:space:]]*write' \"$XEK_TARGET/.github/workflows\" | grep -q ."
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "integridad-005"
    descripcion: "El repo declara firma de releases o uso de sigstore/cosign en su CI"
    command_template: "grep -rilE 'sigstore|cosign sign|gh attestation' \"$XEK_TARGET/.github/workflows\" | grep -q ."
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "integridad-006"
    descripcion: "Las github actions de CI estan pinneadas a SHA y no a tag mutable"
    command_template: "! grep -rhE '^[[:space:]]*uses:[[:space:]]*[^@]+@v[0-9]' \"$XEK_TARGET/.github/workflows\" | grep -q ."
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]

aplicabilidad:
  cuando:
    - "manifest.target_tipo == 'repo'"
  prioridad: alta
  coste_relativo: 2

migracion_runtime:
  bash:   scripts/xek-integridad.sh
  python: scripts/xek-integridad.py
  zsh:    scripts/xek-integridad.zsh

triggers:
  keywords: ["integridad", "sri", "subresource-integrity", "slsa", "provenance", "sigstore", "lockfile-hashes"]
  contextos: ["pre-PR", "pre-deploy", "post-merge"]
  cron: ""
---

# Objetivo

Verificar la integridad de la cadena de suministro de un repositorio en modo
read-only: presencia del atributo `integrity` (Subresource Integrity) en scripts
externos del HTML, hashes de integridad en los lockfiles npm y pnpm, existencia
de generacion de provenance SLSA en CI, uso de firma sigstore/cosign y pinneo de
GitHub Actions a SHA en lugar de tag mutable. La skill solo lee fuentes y
configuracion; nunca firma, modifica ni regenera artefactos.

# Cuando activar

| Si... | Entonces... |
|---|---|
| `manifest.target_tipo == 'repo'` con frontend o releases | Ejecutar `--mode=sandbox` sobre HTML y lockfiles |
| Apertura de PR que toca workflows de CI | Correr `integridad-001..integridad-006` y bloquear si severidad high falla |
| Auditoria de supply-chain previa a release | Promover a `--mode=real` tras sandbox verde |

# Uso · comentario encabezado (copiar al script)

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_integridad · v0.7.0 · 2026-06-20                         ║
# ║  Funcion: integridad supply-chain read-only (SRI/SLSA/firma) ║
# ║  Variables entorno:                                          ║
# ║    XEK_TARGET         path absoluto al repo                  ║
# ║    XDG_RUNTIME_DIR    base sandbox                           ║
# ║  Uso:                                                        ║
# ║    xek-integridad.sh --mode={dry-run|sandbox|real} --target <PATH>║
# ║  Exit codes:                                                 ║
# ║    0=clean · 1=findings · 2=config · 3=missing-mode · 4=ill-call║
# ╚══════════════════════════════════════════════════════════════╝
```

# Implementacion referencia (bash · fuente de verdad)

```bash
#!/usr/bin/env bash
set -euo pipefail

SLUG="XEK_integridad"
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
  echo "checks: integridad-001..integridad-006 (SRI, hashes lockfile, provenance SLSA, firma, pin SHA)"
  echo "target: ${XEK_TARGET:-<sin --target>}"
  exit 0
fi

[[ -d "$XEK_TARGET" ]] || { echo "target inexistente: $XEK_TARGET" >&2; exit 2; }
export XEK_TARGET
# sandbox/real: ejecutar los checks[] del frontmatter sobre $XEK_TARGET.
```

# Adaptador Python

```python
#!/usr/bin/env python3
"""XEK_integridad · adapter Python para pipelines orquestados."""
import subprocess, sys, pathlib
script = pathlib.Path(__file__).with_name("xek-integridad.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-integridad.sh" "$@"
```

# Verificacion end-to-end

```bash
# Caso happy
./scripts/xek-integridad.sh --mode=dry-run && echo "PASS dry-run"

# Caso findings esperado (script CDN sin integrity)
./scripts/xek-integridad.sh --mode=sandbox --target /tmp/repo-sin-sri
echo "exit=$?"  # 1 si falta SRI o hashes
```

# Riesgos y mitigacion

| Riesgo | Mitigacion |
|---|---|
| Falso positivo SRI en scripts inline | `integridad-001` solo evalua src http(s) externos |
| Lockfile de gestor no soportado | Check correspondiente se salta documentandolo |
| Actions pinneadas via tag por convencion del repo | `integridad-006` severidad medium · informativo |
| rekor.sigstore.dev no disponible | Verificacion de firma reporta config error exit 2 |

# Bitacora evolucion

- **v0.0.1** (2026-05-20) — bootstrap stub.
- **v0.6.1** (2026-05-22) — degradado borrador→stub (commit deuda v0.6).
- **v0.7.0** (2026-06-20) — stub→borrador: checks[] read-only SRI/hashes/SLSA/sigstore/pin · fuentes canonicas SLSA + Sigstore + MDN SRI.

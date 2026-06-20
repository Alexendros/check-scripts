---
slug: XEK_sca
ambito: SCA
maestria_funcional: revisor
estado: borrador
version: 0.7.1
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub · pendiente implementación" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "degradado borrador→stub per síntesis Ronda 002 (commit deuda v0.6)" }
  - { v: 0.7.0, fecha: 2026-06-20, cambio: "stub→borrador: SCA read-only (lockfile, advisories osv-scanner, versiones pinneadas, SBOM CycloneDX) · checks[] tipados · fuentes canónicas reales" }
  - { v: 0.7.1, fecha: 2026-06-20, cambio: "runner real scripts/xek-sca.sh: emite xek/finding@v1 (6 checks sca-001..006 (lockfile, vulns CRITICAL vía osv-scanner si está disponible, rangos abiertos, SBOM CycloneDX)), gate real, shellcheck-clean, testado (tests/test_sca.py) · SKILL.md deja de duplicar el bash (single source of truth)" }

objetivo: >
  Verificar la composición de software de un repo (lockfile, advisories osv,
  versiones pinneadas, SBOM CycloneDX) en modo read-only sin modificar
  dependencias.

precondiciones_runtime:
  binarios:
    - { nombre: "bash",        version_min: "5.0",  licencia: "GPL-3.0",   check_cmd: "bash --version" }
    - { nombre: "find",        version_min: "4.7",  licencia: "GPL-3.0",   check_cmd: "find --version" }
    - { nombre: "grep",        version_min: "3.0",  licencia: "GPL-3.0",   check_cmd: "grep --version" }
    - { nombre: "jq",          version_min: "1.7",  licencia: "MIT",       check_cmd: "jq --version" }
    - { nombre: "osv-scanner", version_min: "1.7",  licencia: "Apache-2.0", check_cmd: "osv-scanner --version" }
  capabilities:
    - { cap: "CAP_NONE", razon: "lectura recursiva del repo target · sin escalada" }
  paths_lectura:
    - "$XEK_TARGET/**/*.lock"
    - "$XEK_TARGET/**/package.json"
  paths_escritura:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_sca/"
  conexiones:
    - { destino: "api.osv.dev", proto: https, auth: none }

escalada:
  adapter: "${XEK_SUDO:-sudo -A}"
  capabilities_requeridas: []
  fallback_sin_escalada: "no aplica · skill sin escalada"
  registrar_en_finding: false

fuentes_externas:
  - { tipo: tool, nombre: osv-scanner, version_min: "1.7", licencia: "Apache-2.0" }
  - { tipo: tool, nombre: jq,          version_min: "1.7", licencia: "MIT" }
  - { tipo: tool, nombre: grep,        version_min: "3.0", licencia: "GPL-3.0" }
conexiones_requeridas:
  - { destino: "api.osv.dev", proto: https, auth: none }

referencias_canonicas:
  - { tipo: doc_oficial, url: "https://owasp.org/www-project-dependency-check/", cobertura: "OWASP Dependency-Check · metodología de detección de dependencias vulnerables" }
  - { tipo: estandar,    url: "https://osv.dev", cobertura: "OSV · esquema y base de datos de advisories de vulnerabilidades" }
  - { tipo: estandar,    url: "https://cyclonedx.org", cobertura: "CycloneDX · estándar de formato SBOM" }
verificar_referencias:
  cuando: "antes de cada bump de version_min de osv-scanner"
  como: "consultar changelog upstream; rechazar bump si hay cambio breaking en el formato de salida"

areas_criticas:
  permisos_user:
    - "lectura recursiva del repo target"
    - "escritura: $XDG_RUNTIME_DIR/xek-sandbox/XEK_sca/"
  fhs_tocados:
    - "$XEK_TARGET/ (solo lectura de lockfiles y manifiestos)"
  visual_secrets:
    - "tokens de registries privados en lockfiles · redactar con [REDACTED]"
  zonas_ocultas:
    - "node_modules/, .venv/, vendor/ · evaluar lockfile, no escanear árbol instalado"

modos_ejecucion:
  dry-run:
    proposito: "Verificar precondiciones y listar los checks y manifiestos detectados sin consultar advisories."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · plan textual de checks · exit 0 si parse OK"
  sandbox:
    proposito: "Correr los checks sobre un clon en sandbox y consultar advisories OSV read-only."
    aislamiento: "git worktree en $XDG_RUNTIME_DIR/xek-sandbox/XEK_sca/<run-id>/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_sca/"
    efectos_red: "GET read-only a api.osv.dev para advisories"
    salida: "findings.json en sandbox path · exit 0|1 según findings"
  real:
    proposito: "Ejecutar contra el repo real (read-only) y persistir informe en cuaderno."
    precondicion: "sandbox del mismo input ha pasado en las últimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_sca/<fecha>/"
    efectos_red: "GET read-only a api.osv.dev"
    salida: "informe.md + findings.json + propuesta_#N si findings ≥ severidad_min"
gate_promocion:
  regla: "modo N+1 solo si modo N exit 0|1 con plan"
  override: "--override-gate=AUTO_<timestamp ±60s>"

depende_de:
  - { slug: XEK_detecta-stack, modo: sandbox, obligatoria: true, razon: "necesita manifiesto del repo (gestor, lockfiles)" }
contrato_invocacion:
  modo_subordinado: sandbox
  promocion_real: solo_operador
  consolidacion: "json · merge por slug · schema xek/finding@v1"

checks:
  - id: "sca-001"
    descripcion: "Existe al menos un lockfile reconocido en el repo (npm/pnpm/yarn/cargo/poetry)"
    command_template: "find \"$XEK_TARGET\" -maxdepth 3 -type f \\( -name 'package-lock.json' -o -name 'pnpm-lock.yaml' -o -name 'yarn.lock' -o -name 'Cargo.lock' -o -name 'poetry.lock' \\) | grep -q ."
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "sca-002"
    descripcion: "osv-scanner no reporta vulnerabilidades sobre los lockfiles del repo"
    command_template: "osv-scanner --format json --recursive \"$XEK_TARGET\" | jq -e '[.results[].packages[].vulnerabilities[]?] | length == 0'"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "sca-003"
    descripcion: "Sin advisories de severidad CRITICAL en el resultado de osv-scanner"
    command_template: "osv-scanner --format json --recursive \"$XEK_TARGET\" | jq -e '[.results[].packages[].vulnerabilities[]?.database_specific.severity? // empty | ascii_upcase | select(. == \"CRITICAL\")] | length == 0'"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "sca-004"
    descripcion: "package.json sin rangos abiertos peligrosos (sin dependencia en '*' o 'latest')"
    command_template: "! find \"$XEK_TARGET\" -maxdepth 2 -name package.json -exec grep -lE '\"[^\"]+\"[[:space:]]*:[[:space:]]*\"(\\*|latest)\"' {} + | grep -q ."
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "sca-005"
    descripcion: "Presencia de un SBOM CycloneDX en la raiz del repo (bom.json o *.cdx.json)"
    command_template: "find \"$XEK_TARGET\" -maxdepth 2 -type f \\( -name 'bom.json' -o -name '*.cdx.json' -o -name 'cyclonedx.json' \\) | grep -q ."
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]
  - id: "sca-006"
    descripcion: "El SBOM CycloneDX, si existe, declara bomFormat CycloneDX y es JSON valido"
    command_template: "! find \"$XEK_TARGET\" -maxdepth 2 -name 'bom.json' | grep -q . || jq -e '.bomFormat == \"CycloneDX\"' \"$XEK_TARGET/bom.json\""
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]

aplicabilidad:
  cuando:
    - "manifest.target_tipo == 'repo'"
  prioridad: alta
  coste_relativo: 3

migracion_runtime:
  bash:   scripts/xek-sca.sh
  python: scripts/xek-sca.py
  zsh:    scripts/xek-sca.zsh

triggers:
  keywords: ["sca", "osv-scanner", "dependency-vulnerabilities", "lockfile", "sbom", "cyclonedx", "supply-chain"]
  contextos: ["pre-PR", "post-merge", "pre-deploy"]
  cron: "0 6 * * 1"
---

# Objetivo

Verificar la composicion de software (SCA) de un repositorio en modo read-only:
presencia de un lockfile reconocido, advisories de vulnerabilidad consultados con
`osv-scanner` contra la base de datos OSV, ausencia de rangos de version abiertos
peligrosos en `package.json` y presencia y validez de un SBOM CycloneDX. La skill
solo lee lockfiles y manifiestos; nunca instala, actualiza ni modifica
dependencias.

# Cuando activar

| Si... | Entonces... |
|---|---|
| `manifest.target_tipo == 'repo'` con lockfile | Ejecutar `--mode=sandbox` y consultar advisories OSV |
| Apertura de PR que toca dependencias | Correr `sca-001..sca-006` y bloquear si severidad high falla |
| Auditoria periodica de supply-chain | Promover a `--mode=real` tras sandbox verde |

# Uso · comentario encabezado (copiar al script)

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_sca · v0.7.0 · 2026-06-20                                ║
# ║  Funcion: SCA read-only (lockfile, OSV advisories, SBOM)     ║
# ║  Variables entorno:                                          ║
# ║    XEK_TARGET         path absoluto al repo                  ║
# ║    XDG_RUNTIME_DIR    base sandbox                           ║
# ║  Uso:                                                        ║
# ║    xek-sca.sh --mode={dry-run|sandbox|real} --target <PATH> ║
# ║  Exit codes:                                                 ║
# ║    0=clean · 1=findings · 2=config · 3=missing-mode · 4=ill-call║
# ╚══════════════════════════════════════════════════════════════╝
```

# Implementacion referencia (bash · fuente de verdad)

La implementación ejecutable y **única fuente de verdad** es
[`scripts/xek-sca.sh`](scripts/xek-sca.sh) (v0.7.1, shellcheck-clean, cubierto por
`tests/test_sca.py`). Emite `xek/finding@v1`: un finding por cada check que
falla, con `severity` y `remediation`. Opera read-only sobre el repo target
(`--target`, default cwd). El frontmatter `checks[]` es la especificación
declarativa; el script no se duplica aquí.

Firma y contrato:

```bash
xek-sca.sh --mode {dry-run|sandbox|real} [--target /ruta/repo] [--override-gate=AUTO_<ts>]
# exit: 0 sin findings · 1 findings · 2 config · 3 falta --mode · 4 ill-call
```

# Adaptador Python

```python
#!/usr/bin/env python3
"""XEK_sca · adapter Python para pipelines orquestados."""
import subprocess, sys, pathlib
script = pathlib.Path(__file__).with_name("xek-sca.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-sca.sh" "$@"
```

# Verificacion end-to-end

```bash
# Caso happy
./scripts/xek-sca.sh --mode=dry-run && echo "PASS dry-run"

# Caso findings esperado (repo con dependencia vulnerable conocida)
./scripts/xek-sca.sh --mode=sandbox --target /tmp/repo-con-cve
echo "exit=$?"  # 1 si osv-scanner reporta advisories
```

# Riesgos y mitigacion

| Riesgo | Mitigacion |
|---|---|
| api.osv.dev no disponible | `sca-002`/`sca-003` reportan config error exit 2, no falso clean |
| Lockfile de gestor no soportado | `sca-001` documenta el gestor en el finding |
| Token de registry privado en lockfile | Redaccion `[REDACTED]` antes de persistir |
| SBOM ausente en repos pequenos | `sca-005` severidad low · informativo |

# Bitacora evolucion

- **v0.0.1** (2026-05-20) — bootstrap stub.
- **v0.6.1** (2026-05-22) — degradado borrador→stub (commit deuda v0.6).
- **v0.7.0** (2026-06-20) — stub→borrador: checks[] read-only lockfile/OSV/SBOM · fuentes canonicas OWASP Dependency-Check + OSV + CycloneDX.

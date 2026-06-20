---
slug: XEK_compliance-licencias
ambito: Compliance
maestria_funcional: revisor
estado: borrador
version: 0.7.1
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub · pendiente implementación" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "degradado borrador→stub per síntesis Ronda 002 (commit deuda v0.6)" }
  - { v: 0.7.0, fecha: 2026-06-20, cambio: "stub→borrador: frontmatter R4+R7 + modos + checks[] tipados (lic-001..006) + fuentes canónicas reales (SPDX, REUSE)" }
  - { v: 0.7.1, fecha: 2026-06-20, cambio: "runner real scripts/xek-compliance-licencias.sh: emite xek/finding@v1 (6 checks lic-001..006 (LICENSE, SPDX, license en package.json, NonCommercial, copyleft+NOTICE, REUSE)), gate real, shellcheck-clean, testado (tests/test_compliance_licencias.py) · SKILL.md deja de duplicar el bash (single source of truth)" }

objetivo: >
  Verificar licenciamiento de un repo en modo read-only: presencia de LICENSE,
  identificadores SPDX, compatibilidad de licencias de dependencias y atribución
  NOTICE, sin modificar el target.

precondiciones_runtime:
  binarios:
    - { nombre: "bash", version_min: "5.0", licencia: "GPL-3.0-or-later", check_cmd: "bash --version" }
    - { nombre: "grep", version_min: "3.0", licencia: "GPL-3.0-or-later", check_cmd: "grep --version" }
    - { nombre: "find", version_min: "4.8", licencia: "GPL-3.0-or-later", check_cmd: "find --version" }
    - { nombre: "jq",   version_min: "1.7", licencia: "MIT",              check_cmd: "jq --version" }
  capabilities:
    - { cap: "CAP_NONE", razon: "inspección estática de ficheros del repo · read-only · sin escalada" }
  paths_lectura:
    - "$XEK_TARGET_DIR/**"
  paths_escritura:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_compliance-licencias/"
  conexiones: []

escalada:
  adapter: "${XEK_SUDO:-sudo -A}"
  capabilities_requeridas: []
  fallback_sin_escalada: "no aplica · skill sin escalada"
  registrar_en_finding: false

fuentes_externas:
  - { tipo: tool, nombre: grep, version_min: "3.0", licencia: "GPL-3.0-or-later" }
  - { tipo: tool, nombre: find, version_min: "4.8", licencia: "GPL-3.0-or-later" }
  - { tipo: tool, nombre: jq,   version_min: "1.7", licencia: "MIT" }
conexiones_requeridas: []

referencias_canonicas:
  - { tipo: doc_oficial, url: "https://spdx.org/licenses/", cobertura: "Lista canónica de identificadores SPDX de licencia · forma normalizada para cabeceras y metadatos" }
  - { tipo: estandar,    url: "https://reuse.software/", cobertura: "Especificación REUSE · LICENSES/, cabeceras SPDX por fichero y declaración de atribución" }
verificar_referencias:
  cuando: "antes de cada bump de version_min de tools"
  como: "consultar doc oficial; rechazar bump si la doc marca cambio breaking en el formato"

areas_criticas:
  permisos_user:
    - "lectura del árbol de ficheros del repo objetivo"
    - "escritura: $XDG_RUNTIME_DIR/xek-sandbox/XEK_compliance-licencias/"
  fhs_tocados:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_compliance-licencias/ (solo escritura de findings)"
  visual_secrets: []
  zonas_ocultas:
    - "ficheros fuera del directorio del repo declarado · fuera de alcance"

modos_ejecucion:
  dry-run:
    proposito: "Verificar precondiciones y listar los checks que se ejecutarían sin leer el árbol del repo."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · plan textual de checks · exit 0 si parse OK"
  sandbox:
    proposito: "Inspeccionar una copia aislada del repo y correr los checks de licenciamiento sobre ella."
    aislamiento: "directorio bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_compliance-licencias/<run-id>/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_compliance-licencias/"
    efectos_red: "ninguno · inspección estática local"
    salida: "findings.json en sandbox path · exit 0|1 según findings"
  real:
    proposito: "Inspeccionar el repo real (read-only) y persistir informe en cuaderno."
    precondicion: "sandbox del mismo input ha pasado en las últimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_compliance-licencias/<fecha>/"
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
  - id: "lic-001"
    descripcion: "Fichero LICENSE o COPYING presente en la raiz del repo"
    command_template: "find '$TARGET_DIR' -maxdepth 1 -iregex '.*/\\(license\\|licence\\|copying\\)\\([.][a-z]+\\)?' -print -quit | grep -q ."
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "lic-002"
    descripcion: "Al menos un identificador SPDX-License-Identifier presente en el codigo o metadatos"
    command_template: "grep -rqI 'SPDX-License-Identifier:' '$TARGET_DIR'"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "lic-003"
    descripcion: "package.json declara campo license no vacio si existe"
    command_template: "! test -f '$TARGET_DIR/package.json' || jq -e '.license | type==\"string\" and length>0' '$TARGET_DIR/package.json' >/dev/null"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "lic-004"
    descripcion: "Ausencia de licencias NonCommercial declaradas en LICENSE (incompatibles con uso comercial)"
    command_template: "! grep -rqiI 'noncommercial\\|CC-BY-NC' '$TARGET_DIR'/LICENSE* 2>/dev/null"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "lic-005"
    descripcion: "Si hay dependencias copyleft fuerte (GPL/AGPL) en metadatos, existe declaracion explicita de compatibilidad"
    command_template: "! grep -rqiE 'AGPL|GPL-3' '$TARGET_DIR'/package.json '$TARGET_DIR'/Cargo.toml '$TARGET_DIR'/pyproject.toml 2>/dev/null || test -f '$TARGET_DIR/NOTICE'"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "lic-006"
    descripcion: "Estructura REUSE: directorio LICENSES/ presente si se usan cabeceras SPDX por fichero"
    command_template: "! grep -rqI 'SPDX-License-Identifier:' '$TARGET_DIR' || test -d '$TARGET_DIR/LICENSES'"
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]

aplicabilidad:
  cuando:
    - "manifest.target_tipo == 'repo'"
  prioridad: media
  coste_relativo: 2

migracion_runtime:
  bash:   scripts/xek-compliance-licencias.sh
  python: scripts/xek-compliance-licencias.py
  zsh:    scripts/xek-compliance-licencias.zsh

triggers:
  keywords: ["licencia", "license", "spdx", "copyleft", "gpl", "reuse", "notice", "atribucion"]
  contextos: ["pre-PR", "pre-deploy", "post-merge"]
  cron: ""
---

# Objetivo

Verificar el licenciamiento de un repositorio en modo read-only: presencia de
`LICENSE`/`COPYING`, identificadores SPDX, declaracion de licencia en metadatos
de paquete, ausencia de clausulas NonCommercial, senales de compatibilidad ante
dependencias copyleft fuerte y estructura REUSE (`LICENSES/`). La skill inspecciona
ficheros estaticos; nunca modifica el repo ni descarga metadatos remotos.

# Cuando activar

| Si... | Entonces... |
|---|---|
| `manifest.target_tipo == 'repo'` | Ejecutar `--mode=sandbox` sobre la copia aislada del repo |
| Pre-PR de un repo que se distribuye o publica | Correr `lic-001..lic-006` y bloquear si severidad high falla |
| Auditoria de cumplimiento de licencias de terceros | Promover a `--mode=real` tras sandbox verde |

# Uso · comentario encabezado (copiar al script)

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_compliance-licencias · v0.7.0 · 2026-06-20              ║
# ║  Funcion: verificar licenciamiento del repo (read-only)       ║
# ║  Variables entorno:                                           ║
# ║    XEK_TARGET_DIR     ruta del repo a inspeccionar           ║
# ║    XDG_RUNTIME_DIR    base sandbox                            ║
# ║  Uso:                                                         ║
# ║    xek-compliance-licencias.sh --mode={dry-run|sandbox|real} ║
# ║  Exit codes:                                                 ║
# ║    0=clean · 1=findings · 2=config · 3=missing-mode · 4=ill-call║
# ╚══════════════════════════════════════════════════════════════╝
```

# Implementacion referencia (bash · fuente de verdad)

La implementación ejecutable y **única fuente de verdad** es
[`scripts/xek-compliance-licencias.sh`](scripts/xek-compliance-licencias.sh) (v0.7.1, shellcheck-clean, cubierto por
`tests/test_compliance_licencias.py`). Emite `xek/finding@v1`: un finding por cada check que
falla, con `severity` y `remediation`. Opera read-only sobre el repo target
(`--target`, default cwd). El frontmatter `checks[]` es la especificación
declarativa; el script no se duplica aquí.

Firma y contrato:

```bash
xek-compliance-licencias.sh --mode {dry-run|sandbox|real} [--target /ruta/repo] [--override-gate=AUTO_<ts>]
# exit: 0 sin findings · 1 findings · 2 config · 3 falta --mode · 4 ill-call
```

# Adaptador Python (encapsulado vendoreable)

```python
#!/usr/bin/env python3
"""XEK_compliance-licencias · adapter Python para pipelines orquestados."""
import subprocess, sys, pathlib
script = pathlib.Path(__file__).with_name("xek-compliance-licencias.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-compliance-licencias.sh" "$@"
```

# Verificacion end-to-end (smoke test)

```bash
# Caso happy · dry-run no toca disco del target
./scripts/xek-compliance-licencias.sh --mode=dry-run && echo "PASS dry-run"

# Caso sandbox contra un repo con LICENSE correcto · exit 0
./scripts/xek-compliance-licencias.sh --mode=sandbox --target /ruta/repo-con-licencia
echo "exit=$?"

# Caso falla esperada · repo sin LICENSE genera findings · exit 1
./scripts/xek-compliance-licencias.sh --mode=sandbox --target /ruta/repo-sin-licencia
echo "exit=$?"
```

# Riesgos y mitigacion

| Riesgo | Mitigacion |
|---|---|
| Licencia en formato no estandar no detectada por nombre de fichero | `lic-001` cubre `LICENSE`, `LICENCE`, `COPYING` con o sin extension |
| Falso negativo en compatibilidad copyleft (analisis solo por metadatos) | `lic-005` inspecciona manifiestos de paquete; el informe marca que el analisis transitivo completo queda fuera de alcance |
| Identificador SPDX mal escrito frente a la lista canonica | El informe enlaza a la lista oficial SPDX para validacion manual del identificador |
| NonCommercial dentro de un fichero distinto a LICENSE | `lic-004` se centra en LICENSE; el informe documenta el alcance |

# Bitacora evolucion (append-only · R8)

- **v0.0.1** (2026-05-20) — bootstrap stub.
- **v0.6.1** (2026-05-22) — degradado borrador→stub per sintesis Ronda 002.
- **v0.7.0** (2026-06-20) — stub→borrador: frontmatter R4+R7 completo + modos_ejecucion + 6 checks[] tipados (lic-001..006) + fuentes canonicas reales (SPDX License List, REUSE) + bash referencia de 3 modos.

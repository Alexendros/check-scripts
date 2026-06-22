---
slug: XEK_a11y-web
ambito: A11y
maestria_funcional: revisor
estado: borrador
version: 0.7.1
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub · pendiente implementación" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "degradado borrador→stub per síntesis Ronda 002 (commit deuda v0.6)" }
  - { v: 0.7.0, fecha: 2026-06-20, cambio: "stub→borrador: frontmatter R4+R7 + modos + checks[] tipados + fuentes canónicas reales (WCAG 2.2 + ARIA APG)" }
  - { v: 0.7.1, fecha: 2026-06-21, cambio: "runner real scripts/xek-a11y-web.sh: emite xek/finding@v1 (8 checks a11y-001..008 (html lang, img alt, h1 único, jerarquía headings, roles ARIA, input label, well-formed[xmllint], nav)) con compuerta de aplicabilidad (skipped:not_applicable) y guardas de red/xmllint, gate real, shellcheck-clean, testado (tests/test_a11y_web.py) · SKILL.md deja de duplicar el bash (single source of truth)" }

objetivo: >
  Verificar accesibilidad estatica de una pagina HTML (lang, alt, orden de
  headings, roles ARIA, pistas de contraste) en modo read-only sin modificar el
  target.

precondiciones_runtime:
  binarios:
    - { nombre: "bash",    version_min: "5.0",  licencia: "GPL-3.0",   check_cmd: "bash --version" }
    - { nombre: "curl",    version_min: "7.79", licencia: "curl",      check_cmd: "curl --version" }
    - { nombre: "grep",    version_min: "3.0",  licencia: "GPL-3.0",   check_cmd: "grep --version" }
    - { nombre: "xmllint", version_min: "2.9",  licencia: "MIT",       check_cmd: "xmllint --version" }
  capabilities:
    - { cap: "CAP_NONE", razon: "inspeccion HTTP read-only de HTML publico · sin escalada" }
  paths_lectura:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_a11y-web/<run-id>/*.html"
  paths_escritura:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_a11y-web/"
  conexiones:
    - { destino: "$TARGET_URL", proto: https, auth: none }

escalada:
  adapter: "${XEK_SUDO:-sudo -A}"
  capabilities_requeridas: []
  fallback_sin_escalada: "no aplica · skill sin escalada"
  registrar_en_finding: false

fuentes_externas:
  - { tipo: tool, nombre: curl,    version_min: "7.79", licencia: "curl" }
  - { tipo: tool, nombre: grep,    version_min: "3.0",  licencia: "GPL-3.0" }
  - { tipo: tool, nombre: xmllint, version_min: "2.9",  licencia: "MIT" }
conexiones_requeridas:
  - { destino: "$TARGET_URL", proto: https, auth: none }

referencias_canonicas:
  - { tipo: estandar, url: "https://www.w3.org/TR/WCAG22/", cobertura: "WCAG 2.2 · criterios de exito para lang, texto alternativo, estructura de encabezados y contraste" }
  - { tipo: estandar, url: "https://www.w3.org/WAI/ARIA/apg/", cobertura: "ARIA Authoring Practices Guide · uso correcto de roles, estados y propiedades ARIA" }
verificar_referencias:
  cuando: "antes de cada bump de version_min de tools"
  como: "consultar la recomendacion W3C; rechazar bump si la doc marca cambio breaking en criterios"

areas_criticas:
  permisos_user:
    - "egress HTTP(S) al target publico"
    - "escritura: $XDG_RUNTIME_DIR/xek-sandbox/XEK_a11y-web/"
  fhs_tocados:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_a11y-web/ (solo escritura de HTML cacheado)"
  visual_secrets: []
  zonas_ocultas:
    - "endpoints autenticados o tras login · fuera de alcance · solo HTML publico"
    - "contraste real renderizado · solo se inspeccionan pistas estaticas, no el render final"

modos_ejecucion:
  dry-run:
    proposito: "Verificar precondiciones y listar los checks que se ejecutarian sin egress al target."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · plan textual de checks · exit 0 si parse OK"
  sandbox:
    proposito: "Descargar el HTML publico una vez a sandbox y correr los checks contra la copia aislada."
    aislamiento: "directorio bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_a11y-web/<run-id>/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_a11y-web/"
    efectos_red: "GET read-only al target declarado"
    salida: "findings.json en sandbox path · exit 0|1 segun findings"
  real:
    proposito: "Ejecutar contra la URL real (read-only) y persistir informe en cuaderno."
    precondicion: "sandbox del mismo input ha pasado en las ultimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_a11y-web/<fecha>/"
    efectos_red: "GET read-only al target"
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
  - id: "a11y-001"
    descripcion: "El elemento html declara un atributo lang no vacio"
    command_template: "grep -qiE '<html[^>]+lang=.[a-z]' '$HTML'"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "a11y-002"
    descripcion: "Ninguna etiqueta img carece de atributo alt"
    command_template: "! grep -oiE '<img[^>]*>' '$HTML' | grep -viqE 'alt='"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "a11y-003"
    descripcion: "Existe exactamente un h1 en el documento"
    command_template: "test \"$(grep -oiE '<h1[ >]' '$HTML' | wc -l)\" -eq 1"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "a11y-004"
    descripcion: "No hay salto de nivel mayor que uno entre encabezados consecutivos"
    command_template: "grep -oiE '<h[1-6][ >]' '$HTML' | grep -oiE '[1-6]' | awk 'NR>1 && $0 > prev+1 {bad=1} {prev=$0} END {exit bad+0}'"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "a11y-005"
    descripcion: "Los roles ARIA usados pertenecen al vocabulario valido (heuristica de roles comunes)"
    command_template: "! grep -oiE 'role=.[a-z]+' '$HTML' | grep -viqE 'role=.(button|navigation|main|banner|contentinfo|complementary|search|dialog|alert|list|listitem|tab|tabpanel|tablist|menu|menuitem|region|form|article|heading|img|link|presentation|none|status|switch|checkbox|radio|tooltip|grid|row|cell|combobox|option|progressbar|slider|textbox|tree|treeitem|toolbar|group|figure|table)'"
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]
  - id: "a11y-006"
    descripcion: "Todo input visible tiene id, aria-label o aria-labelledby asociable"
    command_template: "! grep -oiE '<input[^>]*>' '$HTML' | grep -viqE '(id=|aria-label|aria-labelledby|type=.hidden|type=.submit|type=.button)'"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "a11y-007"
    descripcion: "El HTML es parseable por xmllint en modo html, pista de estructura bien anidada"
    command_template: "xmllint --html --noout '$HTML' 2>/dev/null; test $? -le 1"
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]
  - id: "a11y-008"
    descripcion: "Existe al menos un landmark de navegacion (nav o role=navigation)"
    command_template: "grep -qiE '<nav[ >]|role=.navigation.' '$HTML'"
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]

aplicabilidad:
  cuando:
    - "manifest.target_tipo == 'app-en-vivo'"
  prioridad: media
  coste_relativo: 2

migracion_runtime:
  bash:   scripts/xek-a11y-web.sh
  python: scripts/xek-a11y-web.py
  zsh:    scripts/xek-a11y-web.zsh

triggers:
  keywords: ["a11y", "accesibilidad", "wcag", "aria", "alt-text", "contraste", "lang", "headings"]
  contextos: ["pre-PR", "pre-deploy", "post-deploy"]
  cron: ""
---

# Objetivo

Verificar la accesibilidad estatica de una pagina HTML en modo read-only:
atributo `lang` del documento, presencia de texto alternativo en imagenes,
orden y unicidad de encabezados, validez de los roles ARIA usados, asociacion
de etiquetas en formularios y presencia de landmarks de navegacion. La skill
inspecciona el HTML publico servido; nunca modifica el target ni accede a zonas
autenticadas. Las comprobaciones cubren un subconjunto verificable estaticamente
de WCAG 2.2 y de la ARIA Authoring Practices Guide.

# Cuando activar

| Si... | Entonces... |
|---|---|
| `manifest.target_tipo == 'app-en-vivo'` con URL publica | Ejecutar `--mode=sandbox` sobre el HTML descargado |
| Pre-deploy de una pagina con requisitos de accesibilidad | Correr `a11y-001..a11y-008` y bloquear si severidad high falla |
| Post-deploy para verificar lang y alt en produccion | Promover a `--mode=real` tras sandbox verde |

# Uso · comentario encabezado (copiar al script)

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_a11y-web · v0.7.0 · 2026-06-20                           ║
# ║  Funcion: verificar accesibilidad estatica HTML (read-only)   ║
# ║  Variables entorno:                                           ║
# ║    XEK_TARGET_URL     URL publica a inspeccionar              ║
# ║    XDG_RUNTIME_DIR    base sandbox                            ║
# ║  Uso:                                                         ║
# ║    xek-a11y-web.sh --mode={dry-run|sandbox|real} --url <URL>  ║
# ║  Exit codes:                                                  ║
# ║    0=clean · 1=findings · 2=config · 3=missing-mode · 4=ill-call║
# ╚══════════════════════════════════════════════════════════════╝
```

# Implementacion referencia (bash · fuente de verdad)

La implementación ejecutable y **única fuente de verdad** es
[`scripts/xek-a11y-web.sh`](scripts/xek-a11y-web.sh) (v0.7.1, shellcheck-clean, cubierto por
`tests/test_a11y_web.py`). Emite `xek/finding@v1`: un finding por cada check que
falla. Target: artefacto HTML. Incluye **compuerta de aplicabilidad**: sin artefacto
HTML emite `skipped:{razon:not_applicable}` y exit 0. Los checks que requieren
el sitio en vivo (`curl`) o `xmllint` se omiten si falta el input/binario. El
frontmatter `checks[]` es la especificación declarativa; el script no se duplica aquí.

Firma y contrato:

```bash
xek-a11y-web.sh --mode {dry-run|sandbox|real} --target <html> [...] [--override-gate=AUTO_<ts>]
# exit: 0 sin findings / no aplica · 1 findings · 2 config · 3 falta --mode · 4 ill-call
```

# Adaptador Python (encapsulado vendoreable)

```python
#!/usr/bin/env python3
"""XEK_a11y-web · adapter Python para pipelines orquestados."""
import subprocess, sys, pathlib
script = pathlib.Path(__file__).with_name("xek-a11y-web.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-a11y-web.sh" "$@"
```

# Verificacion end-to-end (smoke test)

```bash
# Caso happy · dry-run no toca red
./scripts/xek-a11y-web.sh --mode=dry-run && echo "PASS dry-run"

# Caso sandbox contra una pagina accesible · exit 0 si todos los checks pasan
./scripts/xek-a11y-web.sh --mode=sandbox --url https://example.com
echo "exit=$?"

# Caso falla esperada · pagina sin lang ni alt genera findings · exit 1
./scripts/xek-a11y-web.sh --mode=sandbox --url https://httpbin.org/html
echo "exit=$?"
```

# Riesgos y mitigacion

| Riesgo | Mitigacion |
|---|---|
| HTML renderizado por JS (SPA) sin contenido en el HTML inicial | La skill inspecciona el HTML servido; documenta que el SSR/prerender es prerrequisito del target |
| El contraste real depende del render CSS, no del HTML | La skill solo reporta pistas estaticas; el contraste se marca como zona_oculta, no se afirma cumplimiento WCAG de contraste |
| Roles ARIA validos fuera de la lista heuristica | `a11y-005` usa una lista de roles comunes; un rol no listado se reporta como pista, no como fallo duro |
| Rate-limiting del target ante multiples GET | Descarga el HTML una sola vez a sandbox y corre los checks sobre la copia local |

# Bitacora evolucion (append-only · R8)

- **v0.0.1** (2026-05-20) — bootstrap stub.
- **v0.6.1** (2026-05-22) — degradado borrador→stub per sintesis Ronda 002.
- **v0.7.0** (2026-06-20) — stub→borrador: frontmatter R4+R7 completo + modos_ejecucion + 8 checks[] tipados (a11y-001..008) + fuentes canonicas reales (WCAG 2.2, ARIA APG) + bash referencia de 3 modos.

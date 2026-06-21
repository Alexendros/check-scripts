---
slug: XEK_seo
ambito: SEO
maestria_funcional: revisor
estado: borrador
version: 0.7.1
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub · pendiente implementación" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "degradado borrador→stub per síntesis Ronda 002 (commit deuda v0.6)" }
  - { v: 0.7.0, fecha: 2026-06-20, cambio: "stub→borrador: frontmatter R4+R7 + modos + checks[] tipados + fuentes canónicas reales" }
  - { v: 0.7.1, fecha: 2026-06-21, cambio: "runner real scripts/xek-seo.sh: emite xek/finding@v1 (8 checks seo-001..008 (title, meta description, canonical, robots/sitemap[curl], JSON-LD, OpenGraph, hreflang); fix de drift en seo-006 (falso positivo sin JSON-LD)) con compuerta de aplicabilidad (skipped:not_applicable) y guardas de red/xmllint, gate real, shellcheck-clean, testado (tests/test_seo.py) · SKILL.md deja de duplicar el bash (single source of truth)" }

objetivo: >
  Verificar SEO on-page estático de una URL (title, meta-description, canonical,
  robots.txt, sitemap.xml, JSON-LD, Open Graph, hreflang) en modo read-only sin
  modificar el target.

precondiciones_runtime:
  binarios:
    - { nombre: "bash",    version_min: "5.0",  licencia: "GPL-3.0",   check_cmd: "bash --version" }
    - { nombre: "curl",    version_min: "7.79", licencia: "curl",      check_cmd: "curl --version" }
    - { nombre: "grep",    version_min: "3.0",  licencia: "GPL-3.0",   check_cmd: "grep --version" }
    - { nombre: "jq",      version_min: "1.7",  licencia: "MIT",       check_cmd: "jq --version" }
    - { nombre: "xmllint", version_min: "2.9",  licencia: "MIT",       check_cmd: "xmllint --version" }
  capabilities:
    - { cap: "CAP_NONE", razon: "inspección HTTP read-only de recursos públicos · sin escalada" }
  paths_lectura:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_seo/<run-id>/*.html"
  paths_escritura:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_seo/"
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
  - { tipo: tool, nombre: jq,      version_min: "1.7",  licencia: "MIT" }
  - { tipo: tool, nombre: xmllint, version_min: "2.9",  licencia: "MIT" }
conexiones_requeridas:
  - { destino: "$TARGET_URL", proto: https, auth: none }

referencias_canonicas:
  - { tipo: doc_oficial, url: "https://developers.google.com/search/docs", cobertura: "Guía title/meta-description/canonical/structured-data · directrices de indexación" }
  - { tipo: estandar,    url: "https://schema.org/", cobertura: "Vocabulario de tipos para JSON-LD structured data" }
  - { tipo: estandar,    url: "https://www.sitemaps.org/protocol.html", cobertura: "Protocolo sitemap XML · estructura urlset/loc" }
  - { tipo: estandar,    url: "https://www.rfc-editor.org/rfc/rfc9309", cobertura: "Robots Exclusion Protocol · semántica de robots.txt" }
verificar_referencias:
  cuando: "antes de cada bump de version_min de tools"
  como: "consultar doc oficial; rechazar bump si la doc marca cambio breaking en el formato"

areas_criticas:
  permisos_user:
    - "egress HTTP(S) al target público y a sus robots.txt/sitemap.xml"
    - "escritura: $XDG_RUNTIME_DIR/xek-sandbox/XEK_seo/"
  fhs_tocados:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_seo/ (solo escritura de HTML cacheado)"
  visual_secrets: []
  zonas_ocultas:
    - "endpoints autenticados o tras login · fuera de alcance · solo HTML público"

modos_ejecucion:
  dry-run:
    proposito: "Verificar precondiciones y listar los checks que se ejecutarían sin egress al target."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · plan textual de checks · exit 0 si parse OK"
  sandbox:
    proposito: "Descargar el HTML público una vez a sandbox y correr los checks contra la copia aislada."
    aislamiento: "directorio bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_seo/<run-id>/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_seo/"
    efectos_red: "GET read-only al target declarado + robots.txt + sitemap.xml"
    salida: "findings.json en sandbox path · exit 0|1 según findings"
  real:
    proposito: "Ejecutar contra la URL real (read-only) y persistir informe en cuaderno."
    precondicion: "sandbox del mismo input ha pasado en las últimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_seo/<fecha>/"
    efectos_red: "GET read-only al target + robots.txt + sitemap.xml"
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
  - id: "seo-001"
    descripcion: "Presencia de un unico title no vacio en el HTML"
    command_template: "test \"$(grep -oiE '<title>[^<]+</title>' '$HTML' | wc -l)\" -eq 1"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "seo-002"
    descripcion: "Presencia de meta description no vacia"
    command_template: "grep -qiE '<meta[^>]+name=.description.[^>]+content=.[^\"]+' '$HTML'"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "seo-003"
    descripcion: "Presencia de link rel=canonical apuntando a una URL absoluta"
    command_template: "grep -qiE '<link[^>]+rel=.canonical.[^>]+href=.https?://' '$HTML'"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "seo-004"
    descripcion: "robots.txt accesible con HTTP 200 en la raiz del host"
    command_template: "test \"$(curl -s -o /dev/null -w '%{http_code}' \"$BASE_URL/robots.txt\")\" = 200"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "seo-005"
    descripcion: "sitemap.xml accesible y XML bien formado (urlset o sitemapindex)"
    command_template: "curl -s \"$BASE_URL/sitemap.xml\" | xmllint --noout - && curl -s \"$BASE_URL/sitemap.xml\" | grep -qiE '<urlset|<sitemapindex'"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "seo-006"
    descripcion: "Structured data JSON-LD presente y parseable como JSON"
    command_template: "! grep -qiE '<script[^>]+type=.application/ld.json.' '$HTML' || { grep -oziE '<script[^>]+type=.application/ld.json.[^>]*>[^<]+' '$HTML' | sed -E 's/<script[^>]*>//' | jq -e . >/dev/null; }"
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]
  - id: "seo-007"
    descripcion: "Open Graph minimo: og:title, og:type y og:url presentes"
    command_template: "grep -qiE 'property=.og:title.' '$HTML' && grep -qiE 'property=.og:type.' '$HTML' && grep -qiE 'property=.og:url.' '$HTML'"
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]
  - id: "seo-008"
    descripcion: "Consistencia hreflang: si hay alternates, cada uno declara href absoluto"
    command_template: "! grep -iE '<link[^>]+rel=.alternate.[^>]+hreflang=' '$HTML' || grep -qiE '<link[^>]+rel=.alternate.[^>]+hreflang=[^>]+href=.https?://' '$HTML'"
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]

aplicabilidad:
  cuando:
    - "manifest.target_tipo == 'app-en-vivo'"
  prioridad: media
  coste_relativo: 2

migracion_runtime:
  bash:   scripts/xek-seo.sh
  python: scripts/xek-seo.py
  zsh:    scripts/xek-seo.zsh

triggers:
  keywords: ["seo", "sitemap", "canonical", "meta-tags", "structured-data", "open-graph", "hreflang", "robots.txt"]
  contextos: ["pre-PR", "pre-deploy", "post-deploy"]
  cron: ""
---

# Objetivo

Verificar el SEO on-page estatico de una URL en modo read-only: title y meta
description, link canonical, accesibilidad de `robots.txt` y `sitemap.xml`,
presencia de structured data JSON-LD, etiquetas Open Graph y consistencia de
`hreflang`. La skill inspecciona HTML y cabeceras publicas; nunca modifica el
target ni accede a zonas autenticadas.

# Cuando activar

| Si... | Entonces... |
|---|---|
| `manifest.target_tipo == 'app-en-vivo'` con URL publica | Ejecutar `--mode=sandbox` sobre el HTML descargado |
| Pre-deploy de un sitio con SEO relevante | Correr los checks `seo-001..seo-008` y bloquear si severidad high falla |
| Post-deploy para verificar sitemap y canonical en produccion | Promover a `--mode=real` tras sandbox verde |

# Uso · comentario encabezado (copiar al script)

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_seo · v0.7.0 · 2026-06-20                                ║
# ║  Funcion: verificar SEO on-page estatico (read-only)          ║
# ║  Variables entorno:                                           ║
# ║    XEK_TARGET_URL     URL publica a inspeccionar              ║
# ║    XDG_RUNTIME_DIR    base sandbox                            ║
# ║  Uso:                                                         ║
# ║    xek-seo.sh --mode={dry-run|sandbox|real} --url <URL>       ║
# ║  Exit codes:                                                  ║
# ║    0=clean · 1=findings · 2=config · 3=missing-mode · 4=ill-call║
# ╚══════════════════════════════════════════════════════════════╝
```

# Implementacion referencia (bash · fuente de verdad)

La implementación ejecutable y **única fuente de verdad** es
[`scripts/xek-seo.sh`](scripts/xek-seo.sh) (v0.7.1, shellcheck-clean, cubierto por
`tests/test_seo.py`). Emite `xek/finding@v1`: un finding por cada check que
falla. Target: artefacto HTML (+ --base-url para robots/sitemap vía curl). Incluye **compuerta de aplicabilidad**: sin artefacto
HTML emite `skipped:{razon:not_applicable}` y exit 0. Los checks que requieren
el sitio en vivo (`curl`) o `xmllint` se omiten si falta el input/binario. El
frontmatter `checks[]` es la especificación declarativa; el script no se duplica aquí.

Firma y contrato:

```bash
xek-seo.sh --mode {dry-run|sandbox|real} --target <html> [...] [--override-gate=AUTO_<ts>]
# exit: 0 sin findings / no aplica · 1 findings · 2 config · 3 falta --mode · 4 ill-call
```

# Adaptador Python (encapsulado vendoreable)

```python
#!/usr/bin/env python3
"""XEK_seo · adapter Python para pipelines orquestados."""
import subprocess, sys, pathlib
script = pathlib.Path(__file__).with_name("xek-seo.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-seo.sh" "$@"
```

# Verificacion end-to-end (smoke test)

```bash
# Caso happy · dry-run no toca red
./scripts/xek-seo.sh --mode=dry-run && echo "PASS dry-run"

# Caso sandbox contra una URL con SEO correcto · exit 0 si todos los checks pasan
./scripts/xek-seo.sh --mode=sandbox --url https://example.com
echo "exit=$?"

# Caso falla esperada · URL sin canonical ni sitemap genera findings · exit 1
./scripts/xek-seo.sh --mode=sandbox --url https://httpbin.org/html
echo "exit=$?"
```

# Riesgos y mitigacion

| Riesgo | Mitigacion |
|---|---|
| HTML renderizado por JS (SPA) sin SEO en el HTML inicial | La skill inspecciona el HTML servido; documenta que el SSR/prerender es prerrequisito del target |
| Rate-limiting del target ante multiples GET | Descarga el HTML una sola vez a sandbox y corre los checks sobre la copia local |
| `sitemap.xml` como indice de sitemaps anidados | `seo-005` acepta `sitemapindex` ademas de `urlset` |
| Falso positivo en hreflang sin alternates | `seo-008` pasa por vacuidad si no hay `rel="alternate"` declarado |

# Bitacora evolucion (append-only · R8)

- **v0.0.1** (2026-05-20) — bootstrap stub.
- **v0.6.1** (2026-05-22) — degradado borrador→stub per sintesis Ronda 002.
- **v0.7.0** (2026-06-20) — stub→borrador: frontmatter R4+R7 completo + modos_ejecucion + 8 checks[] tipados (seo-001..008) + fuentes canonicas reales (Google Search Central, schema.org, sitemaps.org, RFC 9309) + bash referencia de 3 modos.

---
slug: XEK_cookies
ambito: Cookies
maestria_funcional: revisor
estado: borrador
version: 0.7.1
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub · pendiente implementación" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "degradado borrador→stub per síntesis Ronda 002 (commit deuda v0.6)" }
  - { v: 0.7.0, fecha: 2026-06-20, cambio: "stub→borrador: frontmatter R4+R7 + modos + checks[] tipados + fuentes canónicas reales (AEPD guía cookies + MDN Set-Cookie)" }
  - { v: 0.7.1, fecha: 2026-06-21, cambio: "runner real scripts/xek-cookies.sh: emite xek/finding@v1 (8 checks cookies-001..008 (banner CMP, Secure/HttpOnly/SameSite, tracking, scripts, política, Max-Age); fix de drift en cookies-008 (! erróneo en patrón awk)) con compuerta de aplicabilidad (skipped:not_applicable) y guardas de red/xmllint, gate real, shellcheck-clean, testado (tests/test_cookies.py) · SKILL.md deja de duplicar el bash (single source of truth)" }

objetivo: >
  Verificar cumplimiento estatico de cookies (banner de consentimiento, flags
  Secure/HttpOnly/SameSite, ausencia de trackers pre-consentimiento) en modo
  read-only sin modificar el target.

precondiciones_runtime:
  binarios:
    - { nombre: "bash", version_min: "5.0",  licencia: "GPL-3.0", check_cmd: "bash --version" }
    - { nombre: "curl", version_min: "7.79", licencia: "curl",    check_cmd: "curl --version" }
    - { nombre: "grep", version_min: "3.0",  licencia: "GPL-3.0", check_cmd: "grep --version" }
    - { nombre: "test", version_min: "8.0",  licencia: "GPL-3.0", check_cmd: "test --help" }
  capabilities:
    - { cap: "CAP_NONE", razon: "inspeccion HTTP read-only de HTML y cabeceras Set-Cookie publicas · sin escalada" }
  paths_lectura:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_cookies/<run-id>/*.html"
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_cookies/<run-id>/*.headers"
  paths_escritura:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_cookies/"
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
  - { tipo: doc_oficial, url: "https://www.aepd.es", cobertura: "AEPD · guia sobre el uso de cookies · consentimiento previo y exencion de cookies tecnicas" }
  - { tipo: estandar,    url: "https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie", cobertura: "MDN Set-Cookie · semantica de atributos Secure, HttpOnly y SameSite" }
verificar_referencias:
  cuando: "antes de cada bump de version_min de tools"
  como: "consultar la guia AEPD y MDN; rechazar bump si la doc marca cambio breaking en flags o consentimiento"

areas_criticas:
  permisos_user:
    - "egress HTTP(S) al target publico para HTML y cabeceras Set-Cookie"
    - "escritura: $XDG_RUNTIME_DIR/xek-sandbox/XEK_cookies/"
  fhs_tocados:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_cookies/ (solo escritura de HTML y cabeceras cacheadas)"
  visual_secrets:
    - "valores de cookies de sesion · nunca imprimir el value, solo nombre y flags"
  zonas_ocultas:
    - "endpoints autenticados o tras login · fuera de alcance · solo respuesta publica inicial"
    - "cookies fijadas por JS tras consentimiento · no se simula interaccion con el banner"

modos_ejecucion:
  dry-run:
    proposito: "Verificar precondiciones y listar los checks que se ejecutarian sin egress al target."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · plan textual de checks · exit 0 si parse OK"
  sandbox:
    proposito: "Descargar el HTML y cabeceras publicas una vez a sandbox y correr los checks contra la copia aislada."
    aislamiento: "directorio bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_cookies/<run-id>/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_cookies/"
    efectos_red: "GET read-only al target declarado + inspeccion de Set-Cookie"
    salida: "findings.json en sandbox path · exit 0|1 segun findings"
  real:
    proposito: "Ejecutar contra la URL real (read-only) y persistir informe en cuaderno."
    precondicion: "sandbox del mismo input ha pasado en las ultimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_cookies/<fecha>/"
    efectos_red: "GET read-only al target + inspeccion de Set-Cookie"
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
  - id: "cookies-001"
    descripcion: "El HTML publica un banner o dialogo de consentimiento (CMP) identificable"
    command_template: "grep -qiE '(cookie-consent|cookie-banner|cmp|consent|aceptar cookies|gestionar cookies|cookiebot|onetrust)' '$HTML'"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "cookies-002"
    descripcion: "Toda cookie de la respuesta inicial declara el atributo Secure"
    command_template: "! grep -iE '^set-cookie:' '$HEADERS' | grep -viqE 'Secure'"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "cookies-003"
    descripcion: "Toda cookie de la respuesta inicial declara el atributo HttpOnly"
    command_template: "! grep -iE '^set-cookie:' '$HEADERS' | grep -viqE 'HttpOnly'"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "cookies-004"
    descripcion: "Toda cookie declara SameSite (Lax, Strict o None con Secure)"
    command_template: "! grep -iE '^set-cookie:' '$HEADERS' | grep -viqE 'SameSite=(Lax|Strict|None)'"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "cookies-005"
    descripcion: "No se fijan cookies de tracking conocidas antes del consentimiento (heuristica de nombres)"
    command_template: "! grep -iE '^set-cookie:' '$HEADERS' | grep -qiE '(_ga|_gid|_fbp|_gcl_au|IDE|_uetsid|mp_[a-z0-9]+_mixpanel)'"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "cookies-006"
    descripcion: "No se cargan scripts de trackers de terceros antes del consentimiento (heuristica de dominios)"
    command_template: "! grep -oiE 'src=.https?://[^\"'\\'' ]+' '$HTML' | grep -qiE '(googletagmanager|google-analytics|connect.facebook|doubleclick|hotjar|clarity.ms)'"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "cookies-007"
    descripcion: "Existe un enlace a la politica de cookies o privacidad"
    command_template: "grep -qiE '<a[^>]+href=[^>]*(cookies|privacidad|privacy|politica)' '$HTML'"
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]
  - id: "cookies-008"
    descripcion: "Ninguna cookie de sesion declara expiracion persistente excesiva (heuristica Max-Age > 1 ano)"
    command_template: "grep -iE '^set-cookie:' '$HEADERS' | grep -oiE 'Max-Age=[0-9]+' | grep -oiE '[0-9]+' | awk '$0 > 31536000 {bad=1} END {exit bad+0}'"
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]

aplicabilidad:
  cuando:
    - "manifest.target_tipo == 'app-en-vivo'"
  prioridad: media
  coste_relativo: 2

migracion_runtime:
  bash:   scripts/xek-cookies.sh
  python: scripts/xek-cookies.py
  zsh:    scripts/xek-cookies.zsh

triggers:
  keywords: ["cookies", "consentimiento", "cmp", "gdpr", "rgpd", "aepd", "set-cookie", "samesite", "tracking"]
  contextos: ["pre-PR", "pre-deploy", "post-deploy"]
  cron: ""
---

# Objetivo

Verificar el cumplimiento estatico de cookies de una pagina publica en modo
read-only: presencia de un banner/CMP de consentimiento, flags `Secure`,
`HttpOnly` y `SameSite` en las cookies de la respuesta inicial, ausencia de
trackers conocidos fijados antes del consentimiento, enlace a la politica de
cookies y duraciones razonables. La skill inspecciona el HTML y las cabeceras
`Set-Cookie` publicas; nunca modifica el target, no simula interaccion con el
banner ni imprime valores de cookies. Las heuristicas se alinean con la guia de
cookies de la AEPD y la semantica `Set-Cookie` documentada por MDN.

# Cuando activar

| Si... | Entonces... |
|---|---|
| `manifest.target_tipo == 'app-en-vivo'` con scope EU | Ejecutar `--mode=sandbox` sobre el HTML y cabeceras descargadas |
| Pre-deploy de un sitio con audiencia europea | Correr `cookies-001..cookies-008` y bloquear si severidad high falla |
| Post-deploy para verificar flags y CMP en produccion | Promover a `--mode=real` tras sandbox verde |

# Uso · comentario encabezado (copiar al script)

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_cookies · v0.7.0 · 2026-06-20                            ║
# ║  Funcion: verificar cumplimiento estatico de cookies          ║
# ║  Variables entorno:                                           ║
# ║    XEK_TARGET_URL     URL publica a inspeccionar              ║
# ║    XDG_RUNTIME_DIR    base sandbox                            ║
# ║  Uso:                                                         ║
# ║    xek-cookies.sh --mode={dry-run|sandbox|real} --url <URL>   ║
# ║  Exit codes:                                                  ║
# ║    0=clean · 1=findings · 2=config · 3=missing-mode · 4=ill-call║
# ╚══════════════════════════════════════════════════════════════╝
```

# Implementacion referencia (bash · fuente de verdad)

La implementación ejecutable y **única fuente de verdad** es
[`scripts/xek-cookies.sh`](scripts/xek-cookies.sh) (v0.7.1, shellcheck-clean, cubierto por
`tests/test_cookies.py`). Emite `xek/finding@v1`: un finding por cada check que
falla. Target: artefacto HTML (+ --headers para cookies). Incluye **compuerta de aplicabilidad**: sin artefacto
HTML emite `skipped:{razon:not_applicable}` y exit 0. Los checks que requieren
el sitio en vivo (`curl`) o `xmllint` se omiten si falta el input/binario. El
frontmatter `checks[]` es la especificación declarativa; el script no se duplica aquí.

Firma y contrato:

```bash
xek-cookies.sh --mode {dry-run|sandbox|real} --target <html> [...] [--override-gate=AUTO_<ts>]
# exit: 0 sin findings / no aplica · 1 findings · 2 config · 3 falta --mode · 4 ill-call
```

# Adaptador Python (encapsulado vendoreable)

```python
#!/usr/bin/env python3
"""XEK_cookies · adapter Python para pipelines orquestados."""
import subprocess, sys, pathlib
script = pathlib.Path(__file__).with_name("xek-cookies.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-cookies.sh" "$@"
```

# Verificacion end-to-end (smoke test)

```bash
# Caso happy · dry-run no toca red
./scripts/xek-cookies.sh --mode=dry-run && echo "PASS dry-run"

# Caso sandbox contra un sitio con CMP y cookies con flags · exit 0 si pasan
./scripts/xek-cookies.sh --mode=sandbox --url https://example.com
echo "exit=$?"

# Caso falla esperada · cookies sin Secure ni banner · exit 1
./scripts/xek-cookies.sh --mode=sandbox --url https://httpbin.org/cookies/set?foo=bar
echo "exit=$?"
```

# Riesgos y mitigacion

| Riesgo | Mitigacion |
|---|---|
| Cookies y trackers fijados por JS tras aceptar el banner | La skill solo inspecciona la respuesta inicial sin interaccion; se documenta como zona_oculta |
| Deteccion del CMP por heuristica de cadenas puede dar falso negativo | `cookies-001` usa una lista amplia de marcadores y nombres de CMP comunes; ampliable |
| Exposicion de valores de cookies en logs | El script imprime solo nombre y flags; el value se marca como visual_secret y no se vuelca |
| Lista de trackers no exhaustiva | `cookies-005`/`cookies-006` cubren los trackers mas comunes; se reporta como senal, no veredicto legal |

# Bitacora evolucion (append-only · R8)

- **v0.0.1** (2026-05-20) — bootstrap stub.
- **v0.6.1** (2026-05-22) — degradado borrador→stub per sintesis Ronda 002.
- **v0.7.0** (2026-06-20) — stub→borrador: frontmatter R4+R7 completo + modos_ejecucion + 8 checks[] tipados (cookies-001..008) + fuentes canonicas reales (AEPD guia cookies, MDN Set-Cookie) + bash referencia de 3 modos.

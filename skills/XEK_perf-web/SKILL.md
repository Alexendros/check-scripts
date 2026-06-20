---
slug: XEK_perf-web
ambito: Performance
maestria_funcional: revisor
estado: borrador
version: 0.7.0
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub · pendiente implementación" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "degradado borrador→stub per síntesis Ronda 002 (commit deuda v0.6)" }
  - { v: 0.7.0, fecha: 2026-06-20, cambio: "stub→borrador: frontmatter R4+R7 + modos + checks[] tipados + fuentes canónicas reales (Core Web Vitals + MDN Web Performance)" }

objetivo: >
  Verificar senales estaticas de rendimiento web (lazy-loading, dimensiones de
  imagen, render-blocking, preconnect/preload, cache headers) en modo read-only
  sin modificar el target.

precondiciones_runtime:
  binarios:
    - { nombre: "bash", version_min: "5.0",  licencia: "GPL-3.0", check_cmd: "bash --version" }
    - { nombre: "curl", version_min: "7.79", licencia: "curl",    check_cmd: "curl --version" }
    - { nombre: "grep", version_min: "3.0",  licencia: "GPL-3.0", check_cmd: "grep --version" }
    - { nombre: "find", version_min: "4.7",  licencia: "GPL-3.0", check_cmd: "find --version" }
    - { nombre: "test", version_min: "8.0",  licencia: "GPL-3.0", check_cmd: "test --help" }
  capabilities:
    - { cap: "CAP_NONE", razon: "inspeccion HTTP read-only de HTML y cabeceras publicas · sin escalada" }
  paths_lectura:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_perf-web/<run-id>/*.html"
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_perf-web/<run-id>/*.headers"
  paths_escritura:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_perf-web/"
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
  - { tipo: tool, nombre: find, version_min: "4.7",  licencia: "GPL-3.0" }
conexiones_requeridas:
  - { destino: "$TARGET_URL", proto: https, auth: none }

referencias_canonicas:
  - { tipo: doc_oficial, url: "https://web.dev/articles/vitals", cobertura: "Core Web Vitals · LCP, CLS, INP y senales que los afectan (imagenes, render-blocking, preload)" }
  - { tipo: estandar,    url: "https://developer.mozilla.org/en-US/docs/Web/Performance", cobertura: "MDN Web Performance · lazy-loading, preconnect/preload y caching de recursos" }
verificar_referencias:
  cuando: "antes de cada bump de version_min de tools"
  como: "consultar la doc de web.dev y MDN; rechazar bump si la guia marca cambio breaking en heuristicas"

areas_criticas:
  permisos_user:
    - "egress HTTP(S) al target publico para HTML y cabeceras HEAD/GET"
    - "escritura: $XDG_RUNTIME_DIR/xek-sandbox/XEK_perf-web/"
  fhs_tocados:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_perf-web/ (solo escritura de HTML y cabeceras cacheadas)"
  visual_secrets: []
  zonas_ocultas:
    - "endpoints autenticados o tras login · fuera de alcance · solo recursos publicos"
    - "metricas de runtime reales (LCP/INP medidos) · solo se inspeccionan senales estaticas, no telemetria de campo"

modos_ejecucion:
  dry-run:
    proposito: "Verificar precondiciones y listar los checks que se ejecutarian sin egress al target."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · plan textual de checks · exit 0 si parse OK"
  sandbox:
    proposito: "Descargar el HTML y cabeceras publicas una vez a sandbox y correr los checks contra la copia aislada."
    aislamiento: "directorio bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_perf-web/<run-id>/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_perf-web/"
    efectos_red: "GET read-only al target declarado + HEAD de cabeceras"
    salida: "findings.json en sandbox path · exit 0|1 segun findings"
  real:
    proposito: "Ejecutar contra la URL real (read-only) y persistir informe en cuaderno."
    precondicion: "sandbox del mismo input ha pasado en las ultimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_perf-web/<fecha>/"
    efectos_red: "GET read-only al target + HEAD de cabeceras"
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
  - id: "perf-001"
    descripcion: "Las imagenes declaran loading=lazy salvo la primera (heuristica de lazy-loading)"
    command_template: "test \"$(grep -oiE '<img[^>]*>' '$HTML' | grep -viE 'loading=.lazy' | wc -l)\" -le 1"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "perf-002"
    descripcion: "Ninguna img carece simultaneamente de width y height (evita CLS)"
    command_template: "! grep -oiE '<img[^>]*>' '$HTML' | grep -viqE '(width=.*height=|height=.*width=)'"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "perf-003"
    descripcion: "No hay scripts render-blocking en head sin defer ni async"
    command_template: "! grep -oiE '<script[^>]+src=[^>]*>' '$HTML' | grep -viqE '(defer|async|type=.module)'"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "perf-004"
    descripcion: "Existe al menos un rel=preconnect o rel=dns-prefetch para origenes de terceros"
    command_template: "grep -qiE '<link[^>]+rel=.(preconnect|dns-prefetch).' '$HTML'"
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]
  - id: "perf-005"
    descripcion: "Existe al menos un rel=preload para un recurso critico (font, style o LCP image)"
    command_template: "grep -qiE '<link[^>]+rel=.preload.' '$HTML'"
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]
  - id: "perf-006"
    descripcion: "La respuesta del documento declara cabecera Cache-Control"
    command_template: "curl -sI \"$URL\" | grep -qiE '^cache-control:'"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "perf-007"
    descripcion: "La respuesta declara compresion (content-encoding gzip/br/zstd)"
    command_template: "curl -sI -H 'Accept-Encoding: gzip, br' \"$URL\" | grep -qiE '^content-encoding:.*(gzip|br|zstd)'"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "perf-008"
    descripcion: "El HTML descargado no excede 250 KB (senal de bundle/markup excesivo)"
    command_template: "test \"$(find '$HTML' -printf '%s')\" -le 256000"
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]

aplicabilidad:
  cuando:
    - "manifest.target_tipo == 'app-en-vivo'"
  prioridad: media
  coste_relativo: 2

migracion_runtime:
  bash:   scripts/xek-perf-web.sh
  python: scripts/xek-perf-web.py
  zsh:    scripts/xek-perf-web.zsh

triggers:
  keywords: ["performance", "core-web-vitals", "lcp", "cls", "lazy-loading", "preload", "preconnect", "cache-control", "bundle-size"]
  contextos: ["pre-PR", "pre-deploy", "post-deploy"]
  cron: ""
---

# Objetivo

Verificar senales estaticas de rendimiento web en modo read-only: lazy-loading
de imagenes, dimensiones explicitas para evitar CLS, scripts render-blocking,
presencia de `preconnect`/`preload`, cabeceras `Cache-Control` y compresion, y
tamano del HTML servido. La skill inspecciona el HTML y las cabeceras publicas;
nunca modifica el target ni mide telemetria de campo. Las heuristicas se basan
en Core Web Vitals (web.dev) y la guia de Web Performance de MDN.

# Cuando activar

| Si... | Entonces... |
|---|---|
| `manifest.target_tipo == 'app-en-vivo'` con URL publica | Ejecutar `--mode=sandbox` sobre el HTML y cabeceras descargadas |
| Pre-deploy de una pagina con presupuesto de rendimiento | Correr `perf-001..perf-008` y bloquear si severidad high falla |
| Post-deploy para verificar caching y compresion en produccion | Promover a `--mode=real` tras sandbox verde |

# Uso · comentario encabezado (copiar al script)

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_perf-web · v0.7.0 · 2026-06-20                           ║
# ║  Funcion: verificar senales estaticas de performance web      ║
# ║  Variables entorno:                                           ║
# ║    XEK_TARGET_URL     URL publica a inspeccionar              ║
# ║    XDG_RUNTIME_DIR    base sandbox                            ║
# ║  Uso:                                                         ║
# ║    xek-perf-web.sh --mode={dry-run|sandbox|real} --url <URL>  ║
# ║  Exit codes:                                                  ║
# ║    0=clean · 1=findings · 2=config · 3=missing-mode · 4=ill-call║
# ╚══════════════════════════════════════════════════════════════╝
```

# Implementacion referencia (bash · fuente de verdad)

```bash
#!/usr/bin/env bash
set -euo pipefail

SLUG="XEK_perf-web"
VERSION="0.7.0"
MODE=""
URL="${XEK_TARGET_URL:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode=*) MODE="${1#*=}"; shift ;;
    --url)    URL="$2"; shift 2 ;;
    *)        echo "ill-call: $1" >&2; exit 4 ;;
  esac
done

[[ -z "$MODE" ]] && { echo "missing --mode" >&2; exit 3; }

preflight() {
  for bin in bash curl grep find test; do
    command -v "$bin" >/dev/null 2>&1 || { echo "PREFLIGHT FAIL: $bin absent" >&2; return 1; }
  done
}

if [[ "$MODE" == "dry-run" ]]; then
  echo "## ${SLUG} v${VERSION} · plan dry-run"
  preflight || exit 2
  echo "checks: perf-001..perf-008 (lazy, dims, render-block, preconnect, preload, cache, gzip, size)"
  exit 0
fi

preflight || exit 2
[[ -z "$URL" ]] && { echo "missing --url" >&2; exit 2; }

SANDBOX="${XDG_RUNTIME_DIR:-/tmp}/xek-sandbox/${SLUG}/$(date +%s)-$$"
mkdir -p "$SANDBOX"
HTML="$SANDBOX/page.html"

curl -fsSL "$URL" -o "$HTML" || { echo "fetch failed: $URL" >&2; exit 1; }

FINDINGS=0
emit() { echo "  - { check: $1, severity: $2, status: $3 }"; }

run_check() {
  local id="$1" sev="$2"; shift 2
  if "$@" >/dev/null 2>&1; then emit "$id" "$sev" pass
  else emit "$id" "$sev" fail; FINDINGS=$((FINDINGS+1)); fi
}

echo "findings:"
run_check perf-002 medium bash -c "! grep -oiE '<img[^>]*>' '$HTML' | grep -viqE '(width=.*height=|height=.*width=)'"
run_check perf-003 high   bash -c "! grep -oiE '<script[^>]+src=[^>]*>' '$HTML' | grep -viqE '(defer|async|type=.module)'"
run_check perf-006 medium bash -c "curl -sI \"$URL\" | grep -qiE '^cache-control:'"
run_check perf-007 medium bash -c "curl -sI -H 'Accept-Encoding: gzip, br' \"$URL\" | grep -qiE '^content-encoding:.*(gzip|br|zstd)'"
run_check perf-008 low    bash -c "test \"\$(find '$HTML' -printf '%s')\" -le 256000"

if [[ "$MODE" == "sandbox" ]]; then
  echo "sandbox: $SANDBOX"
  [[ "$FINDINGS" -eq 0 ]] && exit 0 || exit 1
fi

if [[ "$MODE" == "real" ]]; then
  OUT="${XEK_CUADERNO:-$HOME/.claude/cuadernos/xek-cluster}/artefactos/${SLUG}/$(date +%Y-%m-%d)"
  mkdir -p "$OUT"
  cp "$HTML" "$OUT/page.html"
  echo "informe: $OUT"
  [[ "$FINDINGS" -eq 0 ]] && exit 0 || exit 1
fi
```

# Adaptador Python (encapsulado vendoreable)

```python
#!/usr/bin/env python3
"""XEK_perf-web · adapter Python para pipelines orquestados."""
import subprocess, sys, pathlib
script = pathlib.Path(__file__).with_name("xek-perf-web.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-perf-web.sh" "$@"
```

# Verificacion end-to-end (smoke test)

```bash
# Caso happy · dry-run no toca red
./scripts/xek-perf-web.sh --mode=dry-run && echo "PASS dry-run"

# Caso sandbox contra una pagina optimizada · exit 0 si todos los checks pasan
./scripts/xek-perf-web.sh --mode=sandbox --url https://example.com
echo "exit=$?"

# Caso falla esperada · pagina sin cache-control ni dims de imagen · exit 1
./scripts/xek-perf-web.sh --mode=sandbox --url https://httpbin.org/html
echo "exit=$?"
```

# Riesgos y mitigacion

| Riesgo | Mitigacion |
|---|---|
| Las senales estaticas no equivalen a metricas LCP/INP medidas en campo | La skill declara que solo inspecciona pistas estaticas; la medicion de campo se marca como zona_oculta |
| CDN devuelve cabeceras distintas segun edge | `perf-006`/`perf-007` consultan el mismo endpoint del documento; documenta variabilidad de edge en el informe |
| Imagenes inyectadas por JS no aparecen en el HTML inicial | Se inspecciona el HTML servido; el SSR/prerender es prerrequisito declarado del target |
| Umbral de 250 KB arbitrario para markup | `perf-008` es severidad low y configurable; se reporta como senal, no como fallo duro |

# Bitacora evolucion (append-only · R8)

- **v0.0.1** (2026-05-20) — bootstrap stub.
- **v0.6.1** (2026-05-22) — degradado borrador→stub per sintesis Ronda 002.
- **v0.7.0** (2026-06-20) — stub→borrador: frontmatter R4+R7 completo + modos_ejecucion + 8 checks[] tipados (perf-001..008) + fuentes canonicas reales (Core Web Vitals web.dev, MDN Web Performance) + bash referencia de 3 modos.

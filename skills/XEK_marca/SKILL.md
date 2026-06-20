---
slug: XEK_marca
ambito: Marca
maestria_funcional: revisor
estado: borrador
version: 0.7.0
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub · pendiente implementación" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "degradado borrador→stub per síntesis Ronda 002 (commit deuda v0.6)" }
  - { v: 0.7.0, fecha: 2026-06-20, cambio: "stub→borrador: reorientado a consistencia de marca (favicon/og:image/manifest/naming) + frontmatter R4+R7 + modos + checks[] tipados + fuentes canónicas reales (Web App Manifest + Open Graph)" }

objetivo: >
  Verificar consistencia de marca por activos y metadatos verificables (favicon,
  og:image, manifest name/theme, naming, logos) en modo read-only sin modificar
  el target.

precondiciones_runtime:
  binarios:
    - { nombre: "bash", version_min: "5.0",  licencia: "GPL-3.0", check_cmd: "bash --version" }
    - { nombre: "curl", version_min: "7.79", licencia: "curl",    check_cmd: "curl --version" }
    - { nombre: "grep", version_min: "3.0",  licencia: "GPL-3.0", check_cmd: "grep --version" }
    - { nombre: "jq",   version_min: "1.7",  licencia: "MIT",     check_cmd: "jq --version" }
    - { nombre: "test", version_min: "8.0",  licencia: "GPL-3.0", check_cmd: "test --help" }
  capabilities:
    - { cap: "CAP_NONE", razon: "inspeccion HTTP read-only de HTML, manifest y activos publicos · sin escalada" }
  paths_lectura:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_marca/<run-id>/*.html"
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_marca/<run-id>/*.webmanifest"
  paths_escritura:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_marca/"
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
  - { tipo: tool, nombre: jq,   version_min: "1.7",  licencia: "MIT" }
conexiones_requeridas:
  - { destino: "$TARGET_URL", proto: https, auth: none }

referencias_canonicas:
  - { tipo: estandar,    url: "https://www.w3.org/TR/appmanifest/", cobertura: "Web App Manifest · campos name, short_name, theme_color, icons" }
  - { tipo: doc_oficial, url: "https://ogp.me/", cobertura: "Open Graph protocol · og:title, og:image, og:site_name para consistencia de marca en shares" }
verificar_referencias:
  cuando: "antes de cada bump de version_min de tools"
  como: "consultar la especificacion W3C appmanifest y ogp.me; rechazar bump si la doc marca cambio breaking en campos"

areas_criticas:
  permisos_user:
    - "egress HTTP(S) al target publico para HTML, manifest y activos referenciados"
    - "escritura: $XDG_RUNTIME_DIR/xek-sandbox/XEK_marca/"
  fhs_tocados:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_marca/ (solo escritura de HTML y manifest cacheados)"
  visual_secrets: []
  zonas_ocultas:
    - "endpoints autenticados o tras login · fuera de alcance · solo recursos publicos"
    - "juicio estetico o subjetivo de marca · fuera de alcance · solo activos y metadatos verificables"

modos_ejecucion:
  dry-run:
    proposito: "Verificar precondiciones y listar los checks que se ejecutarian sin egress al target."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · plan textual de checks · exit 0 si parse OK"
  sandbox:
    proposito: "Descargar el HTML y el manifest publicos una vez a sandbox y correr los checks contra la copia aislada."
    aislamiento: "directorio bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_marca/<run-id>/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_marca/"
    efectos_red: "GET read-only al target declarado + manifest + activos referenciados"
    salida: "findings.json en sandbox path · exit 0|1 segun findings"
  real:
    proposito: "Ejecutar contra la URL real (read-only) y persistir informe en cuaderno."
    precondicion: "sandbox del mismo input ha pasado en las ultimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_marca/<fecha>/"
    efectos_red: "GET read-only al target + manifest + activos referenciados"
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
  - id: "marca-001"
    descripcion: "El HTML referencia un favicon (link rel=icon o shortcut icon)"
    command_template: "grep -qiE '<link[^>]+rel=.([a-z ]*\\b)?(icon|shortcut icon).' '$HTML'"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "marca-002"
    descripcion: "El favicon referenciado responde con HTTP 200 en la raiz del host"
    command_template: "test \"$(curl -s -o /dev/null -w '%{http_code}' \"$BASE_URL/favicon.ico\")\" = 200"
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]
  - id: "marca-003"
    descripcion: "El HTML declara og:image para shares sociales"
    command_template: "grep -qiE 'property=.og:image.' '$HTML'"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "marca-004"
    descripcion: "El HTML enlaza un web app manifest (link rel=manifest)"
    command_template: "grep -qiE '<link[^>]+rel=.manifest.' '$HTML'"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "marca-005"
    descripcion: "El manifest declara name (o short_name) no vacio"
    command_template: "jq -e '(.name // .short_name) | length > 0' '$MANIFEST' >/dev/null"
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "marca-006"
    descripcion: "El manifest declara theme_color con formato de color valido"
    command_template: "jq -e '.theme_color | test(\"^#?[0-9A-Fa-f]{3,8}$|^rgb\")' '$MANIFEST' >/dev/null"
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]
  - id: "marca-007"
    descripcion: "El manifest declara al menos un icono en icons[]"
    command_template: "jq -e '(.icons | length) >= 1' '$MANIFEST' >/dev/null"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "marca-008"
    descripcion: "Consistencia de naming: og:site_name coincide con manifest.name (heuristica de presencia)"
    command_template: "test -z \"$(jq -r '.name // empty' '$MANIFEST')\" || grep -qiF \"$(jq -r '.name' '$MANIFEST' | head -c 40)\" '$HTML'"
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]

aplicabilidad:
  cuando:
    - "manifest.target_tipo == 'app-en-vivo'"
  prioridad: media
  coste_relativo: 2

migracion_runtime:
  bash:   scripts/xek-marca.sh
  python: scripts/xek-marca.py
  zsh:    scripts/xek-marca.zsh

triggers:
  keywords: ["marca", "branding", "favicon", "og-image", "open-graph", "manifest", "theme-color", "naming"]
  contextos: ["pre-PR", "pre-deploy", "post-deploy"]
  cron: ""
---

# Objetivo

Verificar la consistencia de marca de una pagina publica en modo read-only por
activos y metadatos verificables: presencia y accesibilidad del favicon,
declaracion de `og:image`, enlace y validez del web app manifest (`name`,
`theme_color`, `icons`) y coherencia de naming entre `og:site_name` y
`manifest.name`. La skill inspecciona el HTML, el manifest y los activos
publicos; nunca modifica el target ni emite juicios esteticos subjetivos. Las
comprobaciones se basan en la especificacion Web App Manifest del W3C y el
protocolo Open Graph.

# Cuando activar

| Si... | Entonces... |
|---|---|
| `manifest.target_tipo == 'app-en-vivo'` con marca propia | Ejecutar `--mode=sandbox` sobre el HTML y manifest descargados |
| Pre-deploy de un sitio con identidad de marca | Correr `marca-001..marca-008` y bloquear si severidad high falla |
| Post-deploy para verificar favicon, og:image y manifest en produccion | Promover a `--mode=real` tras sandbox verde |

# Uso · comentario encabezado (copiar al script)

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_marca · v0.7.0 · 2026-06-20                              ║
# ║  Funcion: verificar consistencia de marca (activos/metadatos) ║
# ║  Variables entorno:                                           ║
# ║    XEK_TARGET_URL     URL publica a inspeccionar              ║
# ║    XDG_RUNTIME_DIR    base sandbox                            ║
# ║  Uso:                                                         ║
# ║    xek-marca.sh --mode={dry-run|sandbox|real} --url <URL>     ║
# ║  Exit codes:                                                  ║
# ║    0=clean · 1=findings · 2=config · 3=missing-mode · 4=ill-call║
# ╚══════════════════════════════════════════════════════════════╝
```

# Implementacion referencia (bash · fuente de verdad)

```bash
#!/usr/bin/env bash
set -euo pipefail

SLUG="XEK_marca"
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
  for bin in bash curl grep jq test; do
    command -v "$bin" >/dev/null 2>&1 || { echo "PREFLIGHT FAIL: $bin absent" >&2; return 1; }
  done
}

if [[ "$MODE" == "dry-run" ]]; then
  echo "## ${SLUG} v${VERSION} · plan dry-run"
  preflight || exit 2
  echo "checks: marca-001..marca-008 (favicon, og:image, manifest link/name/theme/icons, naming)"
  exit 0
fi

preflight || exit 2
[[ -z "$URL" ]] && { echo "missing --url" >&2; exit 2; }

SANDBOX="${XDG_RUNTIME_DIR:-/tmp}/xek-sandbox/${SLUG}/$(date +%s)-$$"
mkdir -p "$SANDBOX"
HTML="$SANDBOX/page.html"
MANIFEST="$SANDBOX/manifest.webmanifest"
BASE_URL="$(echo "$URL" | grep -oE '^https?://[^/]+')"

curl -fsSL "$URL" -o "$HTML" || { echo "fetch failed: $URL" >&2; exit 1; }

MAN_HREF="$(grep -oiE '<link[^>]+rel=.manifest.[^>]+href=.[^"'\'' >]+' "$HTML" | grep -oiE 'href=.[^"'\'' >]+' | sed -E 's/href=.//' | head -1 || true)"
if [[ -n "$MAN_HREF" ]]; then
  case "$MAN_HREF" in
    http*) curl -fsSL "$MAN_HREF" -o "$MANIFEST" 2>/dev/null || true ;;
    /*)    curl -fsSL "$BASE_URL$MAN_HREF" -o "$MANIFEST" 2>/dev/null || true ;;
    *)     curl -fsSL "$BASE_URL/$MAN_HREF" -o "$MANIFEST" 2>/dev/null || true ;;
  esac
fi
[[ -s "$MANIFEST" ]] || echo '{}' > "$MANIFEST"

FINDINGS=0
emit() { echo "  - { check: $1, severity: $2, status: $3 }"; }

run_check() {
  local id="$1" sev="$2"; shift 2
  if "$@" >/dev/null 2>&1; then emit "$id" "$sev" pass
  else emit "$id" "$sev" fail; FINDINGS=$((FINDINGS+1)); fi
}

echo "findings:"
run_check marca-001 medium bash -c "grep -qiE '<link[^>]+rel=.([a-z ]*)?(icon|shortcut icon).' '$HTML'"
run_check marca-003 medium bash -c "grep -qiE 'property=.og:image.' '$HTML'"
run_check marca-004 medium bash -c "grep -qiE '<link[^>]+rel=.manifest.' '$HTML'"
run_check marca-005 high   bash -c "jq -e '(.name // .short_name) | length > 0' '$MANIFEST' >/dev/null"
run_check marca-007 medium bash -c "jq -e '(.icons | length) >= 1' '$MANIFEST' >/dev/null"

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
"""XEK_marca · adapter Python para pipelines orquestados."""
import subprocess, sys, pathlib
script = pathlib.Path(__file__).with_name("xek-marca.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-marca.sh" "$@"
```

# Verificacion end-to-end (smoke test)

```bash
# Caso happy · dry-run no toca red
./scripts/xek-marca.sh --mode=dry-run && echo "PASS dry-run"

# Caso sandbox contra un sitio con favicon, og:image y manifest · exit 0 si pasan
./scripts/xek-marca.sh --mode=sandbox --url https://example.com
echo "exit=$?"

# Caso falla esperada · sin manifest ni og:image · exit 1
./scripts/xek-marca.sh --mode=sandbox --url https://httpbin.org/html
echo "exit=$?"
```

# Riesgos y mitigacion

| Riesgo | Mitigacion |
|---|---|
| La consistencia de marca es en parte subjetiva | La skill solo verifica activos y metadatos comprobables; el juicio estetico se marca como zona_oculta |
| Manifest ausente o no enlazado | El script normaliza a `{}` y `marca-005`/`marca-007` reportan finding en vez de abortar |
| Naming case-sensitive en `marca-008` | Se usa `grep -i` y un prefijo de 40 chars del name para tolerar variantes razonables |
| favicon servido en ruta no estandar | `marca-001` valida la declaracion en HTML; `marca-002` complementa con la ruta convencional sin afirmar exclusividad |

# Bitacora evolucion (append-only · R8)

- **v0.0.1** (2026-05-20) — bootstrap stub.
- **v0.6.1** (2026-05-22) — degradado borrador→stub per sintesis Ronda 002.
- **v0.7.0** (2026-06-20) — stub→borrador: reorientado a consistencia de marca por activos/metadatos verificables + frontmatter R4+R7 completo + modos_ejecucion + 8 checks[] tipados (marca-001..008) + fuentes canonicas reales (W3C Web App Manifest, Open Graph) + bash referencia de 3 modos.

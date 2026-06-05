---
slug: XEK_detecta-stack
ambito: Meta
maestria_funcional: revisor
estado: borrador
version: 0.7.0
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "bump de estado stub a borrador per degradacion masiva ronda-002" }
  - { v: 0.7.0, fecha: 2026-05-22, cambio: "SKILL.md completo: frontmatter R4+R7+R14 + precondiciones_runtime + checks[] tipado + bash ejecutable · estado borrador (beta gateado a linter ejecutable)" }

objetivo: >
  Detectar el tipo de target (repo|app-en-vivo|host) e inspeccionar sus huellas
  para emitir un manifiesto xek/manifest@v2 que alimenta la aplicabilidad
  declarativa del resto de skills.

precondiciones_runtime:
  binarios:
    - { nombre: "bash",  version_min: "5.0",  licencia: "GPL-3.0",  check_cmd: "bash --version" }
    - { nombre: "jq",    version_min: "1.7",  licencia: "MIT",       check_cmd: "jq --version" }
    - { nombre: "git",   version_min: "2.40", licencia: "LGPL-2.1", check_cmd: "git --version" }
    - { nombre: "find",  version_min: "4.9",  licencia: "GPL-3.0",  check_cmd: "find --version" }
    - { nombre: "grep",  version_min: "3.0",  licencia: "GPL-3.0",  check_cmd: "grep --version" }
  capabilities:
    - { cap: "CAP_NONE", razon: "skill ejecuta como usuario sin escalada para repo/host normal" }
  paths_lectura:
    - "$TARGET/**/{package.json,pyproject.toml,Cargo.toml,go.mod,composer.json}"
    - "$TARGET/**/{.github,.eslintrc*,.prettierrc*,vitest.config*,jest.config*}"
    - "/etc/{os-release,debian_version,arch-release,fedora-release}"
    - "/proc/{version,modules}"
    - "/sys/class/drm/"
    - "/run/user/$UID/"
  paths_escritura:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_detecta-stack/"
  conexiones: []

escalada:
  adapter: "${XEK_SUDO:-sudo -A}"
  capabilities_requeridas: []
  fallback_sin_escalada: "skip huellas privilegiadas · reportar como skipped en manifest"
  registrar_en_finding: true

referencias_canonicas:
  - { tipo: doc_oficial, url: "https://raw.githubusercontent.com/Alexendros/check-scripts/main/skills/XEK_orquesta/schemas/manifest.schema.json", cobertura: "Schema xek/manifest@v2 · campos requeridos y enum de target_tipo" }
  - { tipo: doc_oficial, url: "https://docs.npmjs.com/cli/v10/configuring-npm/package-json", cobertura: "Estructura package.json · frameworks · gestores de paquetes" }
  - { tipo: estandar,    url: "https://www.freedesktop.org/software/systemd/man/latest/os-release.html", cobertura: "spec /etc/os-release · ID + ID_LIKE para detección distro agnóstica" }
  - { tipo: estandar,    url: "https://specifications.freedesktop.org/desktop-entry-spec/latest/", cobertura: "XDG base dirs · detección desktop_env via DISPLAY + WAYLAND_DISPLAY" }
  - { tipo: compendio,   url: "https://wiki.archlinux.org/title/Identification_strings", cobertura: "Huellas de distro y entorno en Linux" }
verificar_referencias:
  cuando: "antes de bump version_min de jq o git"
  como: "consultar changelog upstream; rechazar si interfaz JSON de jq cambia"

checks:
  - id: "ds-001"
    descripcion: "Determinar target_tipo: repo si directorio con .git o package.json; host si no hay repo markers; app-en-vivo si URL o endpoint"
    command_template: "test -d '$TARGET/.git' || test -f '$TARGET/package.json' || test -f '$TARGET/pyproject.toml' || test -f '$TARGET/Cargo.toml' || test -f '$TARGET/go.mod'"
    expected_exit: 0
    severity_default: info
    solo_modo: [dry-run, sandbox, real]
  - id: "ds-002"
    descripcion: "Detectar lenguajes presentes por extensiones de archivo en el repositorio"
    command_template: "find '$TARGET' -maxdepth 5 -not -path '*/node_modules/*' -not -path '*/.git/*' \\( -name '*.ts' -o -name '*.tsx' -o -name '*.py' -o -name '*.go' -o -name '*.rs' -o -name '*.java' \\) | head -20"
    expected_exit: 0
    severity_default: info
    solo_modo: [sandbox, real]
  - id: "ds-003"
    descripcion: "Detectar frameworks presentes via dependencias en package.json"
    command_template: "jq -r '(.dependencies // {}) + (.devDependencies // {}) | keys[]' '$TARGET/package.json' 2>/dev/null | grep -E '^(next|react|vue|svelte|astro|remix|@remix-run|vite|turbopack)' || true"
    expected_exit: 0
    severity_default: info
    solo_modo: [sandbox, real]
  - id: "ds-004"
    descripcion: "Detectar tooling: linter, formatter, tester, bundler en package.json"
    command_template: "jq -r '(.devDependencies // {}) | keys[]' '$TARGET/package.json' 2>/dev/null | grep -E '^(eslint|prettier|vitest|jest|@jest|turbopack|webpack|rollup|esbuild)' || true"
    expected_exit: 0
    severity_default: info
    solo_modo: [sandbox, real]
  - id: "ds-005"
    descripcion: "Detectar huellas de host: distro_familia via /etc/os-release, init via systemctl, desktop_env via env vars"
    command_template: "test -f /etc/os-release && grep -E '^(ID|ID_LIKE)=' /etc/os-release || echo 'os-release: not found'"
    expected_exit: 0
    severity_default: info
    solo_modo: [sandbox, real]

areas_criticas:
  permisos_user:
    - "lectura recursiva del target: node_modules excluido"
    - "escritura: $XDG_RUNTIME_DIR/xek-sandbox/XEK_detecta-stack/"
    - "lectura: /etc/os-release, /proc/version (solo para target_tipo=host)"
  fhs_tocados:
    - "<target>/** (solo lectura)"
    - "/etc/os-release (solo lectura · host mode)"
  visual_secrets:
    - "valores de .env detectados · reportar presencia pero NUNCA el contenido"
  zonas_ocultas:
    - "node_modules/, .git/, .next/, dist/, build/, __pycache__/"

modos_ejecucion:
  dry-run:
    proposito: "Verificar precondiciones y detectar target_tipo sin leer archivos internos."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · target_tipo inferido + tools disponibles · exit 0|2"
  sandbox:
    proposito: "Ejecutar deteccion completa y emitir manifiesto xek/manifest@v2 en sandbox."
    aislamiento: "directorio bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_detecta-stack/<run-id>/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_detecta-stack/"
    efectos_red: "ninguno"
    salida: "manifest.json conforme a xek/manifest@v2 · exit 0|1"
  real:
    proposito: "Ejecutar contra target real y emitir manifiesto persistido en cuaderno."
    precondicion: "sandbox del mismo target HEAD ha pasado en las ultimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_detecta-stack/<fecha>/manifest.json"
    efectos_red: "ninguno"
    salida: "manifest.json + informe.md · exit 0|1"
gate_promocion:
  regla: "modo N+1 solo si modo N exit 0|1 con plan"
  override: "--override-gate=AUTO_<timestamp ±60s>"

depende_de: []
contrato_invocacion:
  modo_subordinado: sandbox
  promocion_real: solo_operador
  consolidacion: "json · schema xek/manifest@v2"

aplicabilidad:
  cuando:
    - "siempre · skill de bootstrap sin condicion de aplicabilidad"
  prioridad: alta
  coste_relativo: 1

migracion_runtime:
  bash:   scripts/xek-detecta-stack.sh
  python: scripts/xek-detecta-stack.py
  zsh:    scripts/xek-detecta-stack.zsh

triggers:
  keywords: ["detectar stack", "manifest", "xek manifest", "stack detection", "detecta-stack", "bootstrap manifiesto", "what stack", "que frameworks"]
  contextos: ["pre-PR", "pre-deploy", "session-start", "on-demand"]
  cron: ""
---

# Objetivo

Detectar el tipo de target (repo, app-en-vivo, host) e inspeccionar sus
huellas estructurales para emitir un manifiesto JSON conforme a
`xek/manifest@v2`. Este manifiesto es el contrato de entrada para los 40 skills
del cluster: sin manifiesto, la `aplicabilidad.cuando[]` de cada skill no puede
evaluarse.

# Cuándo activar

| Si... | Entonces... |
|---|---|
| Inicio de cualquier ejecución XEK | Invocar `--mode=sandbox` primero para obtener manifiesto |
| Target no tiene `.git` ni `package.json` | Inferir `target_tipo: host` y poblar `host_huellas` |
| Target es URL | Inferir `target_tipo: app-en-vivo` · marcar endpoints |
| XEK_orquesta coordina una ejecución | Invocar XEK_detecta-stack como paso 0 obligatorio |

# Uso · comentario encabezado

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_detecta-stack · v0.7.0 · 2026-05-22                      ║
# ║  Función: detectar stack/host y emitir xek/manifest@v2         ║
# ║                                                                ║
# ║  Variables entorno:                                            ║
# ║    XEK_SUDO           no aplica (skill sin escalada)           ║
# ║    XDG_RUNTIME_DIR    base sandbox                             ║
# ║    XEK_TARGET         path absoluto al target (repo o host)    ║
# ║    XEK_CUADERNO       path al cuaderno de artefactos           ║
# ║                                                                ║
# ║  Uso:                                                          ║
# ║    xek-detecta-stack.sh --mode=dry-run                         ║
# ║    xek-detecta-stack.sh --mode=sandbox --target /ruta/repo     ║
# ║    xek-detecta-stack.sh --mode=real    --target /ruta/repo     ║
# ║    xek-detecta-stack.sh --mode=sandbox --target-tipo host      ║
# ║                                                                ║
# ║  Exit codes:                                                   ║
# ║    0 = manifiesto emitido OK                                   ║
# ║    1 = manifiesto parcial (huellas con skipped)                ║
# ║    2 = config error (tool ausente, path inválido)              ║
# ║    3 = --mode ausente                                          ║
# ║    4 = invocación ilegal                                       ║
# ╚══════════════════════════════════════════════════════════════╝
```

# Implementación referencia (bash · fuente de verdad)

```bash
#!/usr/bin/env bash
set -euo pipefail

SLUG="XEK_detecta-stack"
VERSION="0.7.0"
MODE=""
TARGET="${XEK_TARGET:-}"
TARGET_TIPO_OVERRIDE=""
OVERRIDE_GATE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode=*)           MODE="${1#*=}"; shift ;;
    --target)           TARGET="$2"; shift 2 ;;
    --target-tipo)      TARGET_TIPO_OVERRIDE="$2"; shift 2 ;;
    --override-gate=*)  OVERRIDE_GATE="${1#*=}"; shift ;;
    *)                  echo "ill-call: $1" >&2; exit 4 ;;
  esac
done

[[ -z "$MODE" ]] && { echo "missing --mode" >&2; exit 3; }

SANDBOX_BASE="${XDG_RUNTIME_DIR:-/tmp}/xek-sandbox/${SLUG}"
RUN_ID="$(date +%s)-$$"
SANDBOX="$SANDBOX_BASE/$RUN_ID"

# ── Preflight ──────────────────────────────────────────────────────
preflight() {
  local fail=0
  for bin in bash jq git find grep; do
    command -v "$bin" >/dev/null 2>&1 || { echo "PREFLIGHT FAIL: $bin absent" >&2; fail=1; }
  done
  return $fail
}

# ── Detectar target_tipo ───────────────────────────────────────────
detect_tipo() {
  local t="${1:-}"
  [[ -n "$TARGET_TIPO_OVERRIDE" ]] && { echo "$TARGET_TIPO_OVERRIDE"; return; }
  if [[ "$t" =~ ^https?:// ]]; then echo "app-en-vivo"; return; fi
  if [[ -d "$t/.git" ]] || [[ -f "$t/package.json" ]] || [[ -f "$t/pyproject.toml" ]] \
     || [[ -f "$t/Cargo.toml" ]] || [[ -f "$t/go.mod" ]]; then echo "repo"; return; fi
  echo "host"
}

# ── Detectar lenguajes ─────────────────────────────────────────────
detect_langs() {
  local t="$1"
  local langs=()
  find "$t" -maxdepth 6 \
    -not -path '*/node_modules/*' -not -path '*/.git/*' \
    -not -path '*/dist/*' -not -path '*/.next/*' \
    \( -name '*.ts' -o -name '*.tsx' -o -name '*.py' -o -name '*.go' \
       -o -name '*.rs' -o -name '*.java' -o -name '*.rb' -o -name '*.php' \) \
    -print -quit 2>/dev/null | head -50 > /tmp/xek-langs-$$ || true
  grep -q '\.ts\|\.tsx' /tmp/xek-langs-$$ && langs+=("typescript")
  grep -q '\.py'        /tmp/xek-langs-$$ && langs+=("python")
  grep -q '\.go'        /tmp/xek-langs-$$ && langs+=("go")
  grep -q '\.rs'        /tmp/xek-langs-$$ && langs+=("rust")
  grep -q '\.java'      /tmp/xek-langs-$$ && langs+=("java")
  grep -q '\.rb'        /tmp/xek-langs-$$ && langs+=("ruby")
  grep -q '\.php'       /tmp/xek-langs-$$ && langs+=("php")
  rm -f /tmp/xek-langs-$$
  # siempre incluir JS/TS si hay package.json
  [[ -f "$t/package.json" ]] && { [[ " ${langs[*]:-} " != *" typescript "* ]] && langs+=("javascript"); }
  printf '%s\n' "${langs[@]:-}" | jq -R . | jq -s .
}

# ── Detectar gestor de paquetes ────────────────────────────────────
detect_pm() {
  local t="$1"
  [[ -f "$t/pnpm-lock.yaml" ]] && { echo '"pnpm"'; return; }
  [[ -f "$t/yarn.lock" ]]      && { echo '"yarn"'; return; }
  [[ -f "$t/bun.lockb" ]]      && { echo '"bun"'; return; }
  [[ -f "$t/package-lock.json" ]] && { echo '"npm"'; return; }
  [[ -f "$t/Cargo.lock" ]]     && { echo '"cargo"'; return; }
  [[ -f "$t/go.sum" ]]         && { echo '"go"'; return; }
  [[ -f "$t/pyproject.toml" || -f "$t/requirements.txt" ]] && { echo '"pip"'; return; }
  echo '"none"'
}

# ── Detectar frameworks ────────────────────────────────────────────
detect_frameworks() {
  local t="$1"
  [[ ! -f "$t/package.json" ]] && { echo '[]'; return; }
  jq -r '
    (.dependencies // {}) + (.devDependencies // {})
    | to_entries[]
    | select(.key | test("^(next|react|vue|svelte|astro|remix|@remix-run|angular|solid-js|qwik)$"))
    | {nombre: .key, version_min: (.value | ltrimstr("^") | ltrimstr("~"))}
  ' "$t/package.json" 2>/dev/null | jq -s . || echo '[]'
}

# ── Detectar tooling ───────────────────────────────────────────────
detect_tooling() {
  local t="$1"
  [[ ! -f "$t/package.json" ]] && { echo '{"linter":[],"formatter":[],"tester":[],"bundler":null}'; return; }
  local dev_deps
  dev_deps=$(jq -r '(.devDependencies // {}) | keys[]' "$t/package.json" 2>/dev/null || true)
  local linter=() formatter=() tester=() bundler="null"
  echo "$dev_deps" | grep -q 'eslint'    && linter+=("eslint")
  echo "$dev_deps" | grep -q 'biome'     && linter+=("biome")
  echo "$dev_deps" | grep -q 'oxlint'    && linter+=("oxlint")
  echo "$dev_deps" | grep -q 'prettier'  && formatter+=("prettier")
  echo "$dev_deps" | grep -q 'biome'     && formatter+=("biome")
  echo "$dev_deps" | grep -q 'vitest'    && tester+=("vitest")
  echo "$dev_deps" | grep -q 'jest'      && tester+=("jest")
  echo "$dev_deps" | grep -q 'playwright' && tester+=("playwright")
  echo "$dev_deps" | grep -qE '^turbopack' && bundler='"turbopack"'
  echo "$dev_deps" | grep -qE '^vite'    && [[ $bundler == "null" ]] && bundler='"vite"'
  echo "$dev_deps" | grep -qE '^webpack' && [[ $bundler == "null" ]] && bundler='"webpack"'
  jq -n \
    --argjson l "$(printf '%s\n' "${linter[@]:-}" | jq -R . | jq -s .)" \
    --argjson f "$(printf '%s\n' "${formatter[@]:-}" | jq -R . | jq -s .)" \
    --argjson t "$(printf '%s\n' "${tester[@]:-}" | jq -R . | jq -s .)" \
    --argjson b "$bundler" \
    '{linter:$l, formatter:$f, tester:$t, bundler:$b}'
}

# ── Detectar huellas infra en repo ─────────────────────────────────
detect_infra() {
  local t="$1"
  jq -n \
    --argjson docker       "$([[ -f "$t/Dockerfile" ]] && echo true || echo false)" \
    --argjson docker_c     "$([[ -f "$t/docker-compose.yml" || -f "$t/docker-compose.yaml" ]] && echo true || echo false)" \
    --argjson dokploy      "$([[ -f "$t/dokploy.yaml" || -f "$t/.dokploy" ]] && echo true || echo false)" \
    --argjson vercel       "$([[ -f "$t/vercel.json" || -d "$t/.vercel" ]] && echo true || echo false)" \
    --argjson gh_actions   "$([[ -d "$t/.github/workflows" ]] && echo true || echo false)" \
    '{docker:$docker, docker_compose:$docker_c, dokploy:$dokploy, vercel:$vercel, github_actions:$gh_actions}'
}

# ── Detectar huellas de host ───────────────────────────────────────
detect_host() {
  local distro="unknown" init_sys="unknown" desktop="none" display="tty"
  local gpu="none" audio="none" bluetooth="none"

  if [[ -f /etc/os-release ]]; then
    local id id_like
    id=$(grep -E '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"' || echo "")
    id_like=$(grep -E '^ID_LIKE=' /etc/os-release | cut -d= -f2 | tr -d '"' || echo "")
    case "${id_like:-$id}" in
      *arch*)   distro="arch" ;;
      *debian*|*ubuntu*) distro="debian" ;;
      *fedora*|*rhel*|*centos*) distro="fedora" ;;
      *nixos*)  distro="nixos" ;;
      *alpine*) distro="alpine" ;;
      *gentoo*) distro="gentoo" ;;
    esac
  fi

  command -v systemctl >/dev/null 2>&1 && init_sys="systemd"
  command -v rc-update >/dev/null 2>&1 && init_sys="openrc"
  command -v runit >/dev/null 2>&1     && init_sys="runit"

  [[ "${WAYLAND_DISPLAY:-}" != "" || "${XDG_SESSION_TYPE:-}" == "wayland" ]] && display="wayland"
  [[ "${DISPLAY:-}" != "" && "$display" == "tty" ]] && display="x11"

  [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]] && desktop="gnome"
  [[ "${XDG_CURRENT_DESKTOP:-}" == *KDE*   ]] && desktop="kde"
  [[ "${XDG_CURRENT_DESKTOP:-}" == *sway*  ]] && desktop="sway"
  [[ "${XDG_CURRENT_DESKTOP:-}" == *Hyprland* ]] && desktop="hyprland"

  command -v lspci >/dev/null 2>&1 && {
    lspci 2>/dev/null | grep -qi nvidia && gpu="nvidia"
    lspci 2>/dev/null | grep -qi 'amd\|advanced micro devices.*vga' && gpu="amd"
    lspci 2>/dev/null | grep -qi 'intel.*graphics' && [[ "$gpu" == "none" ]] && gpu="intel"
  }

  command -v pactl >/dev/null 2>&1 && audio="pipewire"
  [[ "$audio" == "none" ]] && command -v pulseaudio >/dev/null 2>&1 && audio="pulseaudio"
  [[ "$audio" == "none" ]] && command -v alsamixer >/dev/null 2>&1 && audio="alsa"

  command -v bluetoothctl >/dev/null 2>&1 && bluetooth="bluez"

  jq -n \
    --arg df "$distro" --arg in "$init_sys" --arg de "$desktop" \
    --arg ds "$display" --arg gp "$gpu" --arg au "$audio" --arg bt "$bluetooth" \
    '{distro_familia:$df, init:$in, desktop_env:$de, display_server:$ds, gpu_vendor:$gp, audio_server:$au, bluetooth:$bt}'
}

# ── dry-run ────────────────────────────────────────────────────────
if [[ "$MODE" == "dry-run" ]]; then
  echo "## ${SLUG} v${VERSION} · plan dry-run"
  if preflight; then echo "preflight: PASS"; else exit 2; fi
  TIPO=$(detect_tipo "${TARGET:-$(pwd)}")
  echo "target: ${TARGET:-(cwd)}"
  echo "target_tipo inferido: $TIPO"
  echo "tools: bash=$(command -v bash) jq=$(command -v jq) git=$(command -v git)"
  exit 0
fi

# ── sandbox + real ────────────────────────────────────────────────
preflight || exit 2
T="${TARGET:-$(pwd)}"
[[ "$TARGET_TIPO_OVERRIDE" == "host" ]] || { [[ -e "$T" ]] || { echo "target inexistente: $T" >&2; exit 2; }; }

mkdir -p "$SANDBOX"
TIPO=$(detect_tipo "$T")

# Construir manifiesto según tipo
case "$TIPO" in
  repo)
    LANGS=$(detect_langs "$T")
    PM=$(detect_pm "$T")
    FW=$(detect_frameworks "$T")
    TL=$(detect_tooling "$T")
    INF=$(detect_infra "$T")
    MANIFEST=$(jq -n \
      --arg schema "xek/manifest@v2" \
      --arg target "$T" \
      --arg tipo "$TIPO" \
      --argjson langs "$LANGS" \
      --argjson pm "$PM" \
      --argjson fw "$FW" \
      --argjson tl "$TL" \
      --argjson inf "$INF" \
      '{
        schema: $schema,
        target: $target,
        target_tipo: $tipo,
        repo: {
          gestor_paquetes: $pm,
          frameworks: $fw,
          lenguajes: $langs,
          tooling: $tl,
          infra_huellas: $inf
        }
      }')
    ;;
  host)
    HH=$(detect_host)
    MANIFEST=$(jq -n \
      --arg schema "xek/manifest@v2" \
      --arg target "${T:-$(hostname)}" \
      --arg tipo "$TIPO" \
      --argjson hh "$HH" \
      '{schema: $schema, target: $target, target_tipo: $tipo, host_huellas: $hh}')
    ;;
  app-en-vivo)
    MANIFEST=$(jq -n \
      --arg schema "xek/manifest@v2" \
      --arg target "$T" \
      --arg tipo "$TIPO" \
      '{schema: $schema, target: $target, target_tipo: $tipo}')
    ;;
esac

echo "$MANIFEST" > "$SANDBOX/manifest.json"

if [[ "$MODE" == "sandbox" ]]; then
  echo "manifest: $SANDBOX/manifest.json"
  echo "$MANIFEST" | jq .
  exit 0
fi

if [[ "$MODE" == "real" ]]; then
  LAST=$(find "$SANDBOX_BASE" -maxdepth 1 -mindepth 1 -mmin -1440 -type d 2>/dev/null | head -1 || true)
  if [[ -z "$LAST" && -z "$OVERRIDE_GATE" ]]; then
    echo "gate: sandbox previo no encontrado en 24h · usar --override-gate=AUTO_<ts>" >&2; exit 2
  fi
  OUT_DIR="${XEK_CUADERNO:-$HOME/.claude/cuadernos/xek-cluster}/artefactos/XEK_detecta-stack/$(date +%Y-%m-%d)"
  mkdir -p "$OUT_DIR"
  echo "$MANIFEST" > "$OUT_DIR/manifest.json"
  {
    echo "# Informe XEK_detecta-stack · $(date -Iseconds)"
    echo "target: $T"
    echo "target_tipo: $TIPO"
    echo ""
    echo "## Manifiesto emitido"
    echo '```json'
    echo "$MANIFEST" | jq .
    echo '```'
  } > "$OUT_DIR/informe.md"
  echo "manifest: $OUT_DIR/manifest.json"
  echo "informe: $OUT_DIR/informe.md"
  exit 0
fi
```

# Adaptador Python

```python
#!/usr/bin/env python3
"""XEK_detecta-stack · adapter Python para pipelines orquestados."""
import subprocess, sys, pathlib, os
script = pathlib.Path(__file__).with_name("xek-detecta-stack.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
setopt EXTENDED_GLOB
exec bash "${0:A:h}/xek-detecta-stack.sh" "$@"
```

# Verificación end-to-end

```bash
# Caso happy · repo con Next.js
TMPDIR=$(mktemp -d) && cd "$TMPDIR" && git init -q
cat > package.json <<'EOF'
{
  "dependencies": {"next": "^14.0.0", "react": "^18.0.0"},
  "devDependencies": {"eslint": "^8.0.0", "prettier": "^3.0.0", "vitest": "^1.0.0"}
}
EOF
git add . && git commit -qm bootstrap

./scripts/xek-detecta-stack.sh --mode=dry-run && echo "PASS dry-run"
./scripts/xek-detecta-stack.sh --mode=sandbox --target "$TMPDIR"
echo "exit=$?"  # esperado: 0
# Verificar que el manifest contiene next en frameworks
./scripts/xek-detecta-stack.sh --mode=sandbox --target "$TMPDIR" | jq '.repo.frameworks[].nombre' | grep -q 'next' && echo "PASS frameworks"

# Caso host
./scripts/xek-detecta-stack.sh --mode=sandbox --target-tipo host
echo "exit=$?"  # esperado: 0

cd - && rm -rf "$TMPDIR"
```

# Riesgos y mitigación

| Riesgo | Mitigación |
|---|---|
| package.json malformado (JSON inválido) | `jq` falla con exit ≠0 · skill reporta `borrador` parcial · no aborta |
| Directorio target gigante (monorepo) | `find -maxdepth 6` limita la búsqueda; node_modules excluido |
| Huellas de host inaccesibles sin sudo | `detect_host` usa solo variables de entorno y `/etc/os-release` (world-readable) |
| Manifiesto emitido sin validar contra schema | Gate de beta exige `jq -e` validación contra `manifest.schema.json` · no implementado hasta linter |
| Framework con nombre en `devDependencies` pero no usado realmente | Falso positivo posible; skill opera sobre huellas estáticas, no runtime |

# Bitácora evolución

- **v0.0.1** (2026-05-20) — bootstrap stub. Frontmatter mínimo · sin implementación.
- **v0.6.1** (2026-05-22) — bump de borrador per degradación masiva Ronda 002.
- **v0.7.0** (2026-05-22) — SKILL.md completo: frontmatter R4+R7+R14 + precondiciones_runtime + 5 checks[] tipados + bash ejecutable completo (3 modos) · estado borrador · beta gateado a linter ejecutable disponible.

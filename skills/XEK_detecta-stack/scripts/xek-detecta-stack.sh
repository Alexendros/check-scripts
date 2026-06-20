#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_detecta-stack · v0.7.2                                    ║
# ║  Función: detectar stack/host y emitir xek/manifest@v2         ║
# ║                                                                ║
# ║  Variables entorno:                                            ║
# ║    XEK_SUDO           adapter de escalada (def: sudo -A)       ║
# ║    XDG_RUNTIME_DIR    base sandbox                             ║
# ║    XEK_TARGET         path absoluto al target (repo o host)    ║
# ║    XEK_CUADERNO       path al cuaderno de artefactos           ║
# ║                                                                ║
# ║  Uso:                                                          ║
# ║    xek-detecta-stack.sh --mode dry-run                         ║
# ║    xek-detecta-stack.sh --mode=dry-run                         ║
# ║    xek-detecta-stack.sh --mode sandbox --target /ruta/repo     ║
# ║    xek-detecta-stack.sh --mode real    --target /ruta/repo     ║
# ║    xek-detecta-stack.sh --mode sandbox --target-tipo host      ║
# ║                                                                ║
# ║  Exit codes:                                                   ║
# ║    0 = manifiesto emitido OK                                   ║
# ║    1 = manifiesto parcial (huellas con skipped)                ║
# ║    2 = config error (tool ausente, path inválido)             ║
# ║    3 = --mode ausente                                          ║
# ║    4 = invocación ilegal                                       ║
# ╚══════════════════════════════════════════════════════════════╝
set -euo pipefail

SLUG="XEK_detecta-stack"
VERSION="0.7.2"
MODE=""
TARGET="${XEK_TARGET:-}"
TARGET_TIPO_OVERRIDE=""
OVERRIDE_GATE=""

# ── Parseo de argumentos (acepta --flag valor y --flag=valor) ──────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)             MODE="${2:-}"; shift 2 ;;
    --mode=*)           MODE="${1#*=}"; shift ;;
    --target)           TARGET="${2:-}"; shift 2 ;;
    --target=*)         TARGET="${1#*=}"; shift ;;
    --target-tipo)      TARGET_TIPO_OVERRIDE="${2:-}"; shift 2 ;;
    --target-tipo=*)    TARGET_TIPO_OVERRIDE="${1#*=}"; shift ;;
    --override-gate=*)  OVERRIDE_GATE="${1#*=}"; shift ;;
    --override-gate)    OVERRIDE_GATE="${2:-}"; shift 2 ;;
    -h|--help)          sed -n '2,30p' "$0"; exit 0 ;;
    *)                  echo "ill-call: $1" >&2; exit 4 ;;
  esac
done

[[ -z "$MODE" ]] && { echo "missing --mode" >&2; exit 3; }
case "$MODE" in
  dry-run|sandbox|real) ;;
  *) echo "ill-call: --mode '$MODE' (use dry-run|sandbox|real)" >&2; exit 4 ;;
esac

SANDBOX_BASE="${XDG_RUNTIME_DIR:-/tmp}/xek-sandbox/${SLUG}"
RUN_ID="$(date +%s)-$$"
SANDBOX="$SANDBOX_BASE/$RUN_ID"

# Estado de degradación: 1 si alguna huella se marcó skipped → exit 1.
PARCIAL=0

# ── Preflight · binarios requeridos (precondiciones_runtime) ───────
preflight() {
  local fail=0 bin
  for bin in bash jq git find grep; do
    if ! command -v "$bin" >/dev/null 2>&1; then
      echo "PREFLIGHT FAIL: $bin absent" >&2
      fail=1
    fi
  done
  return "$fail"
}

# ── ds-001 · Determinar target_tipo ───────────────────────────────
detect_tipo() {
  local t="${1:-}"
  if [[ -n "$TARGET_TIPO_OVERRIDE" ]]; then
    printf '%s' "$TARGET_TIPO_OVERRIDE"
    return
  fi
  if [[ "$t" =~ ^https?:// ]]; then
    printf '%s' "app-en-vivo"
    return
  fi
  # .git puede ser dir (repo normal) o fichero (worktree/submódulo) → -e cubre ambos.
  # Incluye markers de monorepo/otros ecosistemas: un workspace-root sin package.json
  # raíz seguía clasificándose como host por error.
  if [[ -e "$t/.git" ]] || [[ -f "$t/package.json" ]] || [[ -f "$t/pyproject.toml" ]] \
     || [[ -f "$t/Cargo.toml" ]] || [[ -f "$t/go.mod" ]] \
     || [[ -f "$t/pnpm-workspace.yaml" ]] || [[ -f "$t/composer.json" ]] \
     || [[ -f "$t/Gemfile" ]] || [[ -f "$t/requirements.txt" ]]; then
    printf '%s' "repo"
    return
  fi
  printf '%s' "host"
}

# ── repo · tipo de repo (monorepo/repo-simple/library) ────────────
detect_repo_shape() {
  local t="$1"
  if [[ -f "$t/pnpm-workspace.yaml" ]] || [[ -d "$t/packages" ]] || [[ -d "$t/apps" ]]; then
    printf '%s' "monorepo"
    return
  fi
  if [[ -f "$t/package.json" ]] && jq -e '.private != true and (.main != null or .exports != null or .module != null)' \
       "$t/package.json" >/dev/null 2>&1; then
    printf '%s' "library"
    return
  fi
  printf '%s' "repo-simple"
}

# ── ds-002 · Detectar lenguajes por extensiones ───────────────────
detect_langs() {
  local t="$1"
  local tmp langs=()
  tmp="$(mktemp)"
  # Exclusiones alineadas con github-linguist/vendor.yml: no contar vendored/generated.
  find "$t" -maxdepth 6 \
    -not -path '*/node_modules/*' -not -path '*/.git/*' \
    -not -path '*/dist/*' -not -path '*/.next/*' -not -path '*/__pycache__/*' \
    -not -path '*/vendor/*' -not -path '*/build/*' -not -path '*/coverage/*' \
    -not -path '*/target/*' -not -path '*/.venv/*' -not -path '*/.yarn/*' \
    -not -path '*/bower_components/*' \
    \( -name '*.ts' -o -name '*.tsx' -o -name '*.py' -o -name '*.go' \
       -o -name '*.rs' -o -name '*.java' -o -name '*.rb' -o -name '*.php' \) \
    2>/dev/null | head -200 > "$tmp" || true
  grep -q '\.tsx\?$' "$tmp" && langs+=("typescript")
  grep -q '\.py$'    "$tmp" && langs+=("python")
  grep -q '\.go$'    "$tmp" && langs+=("go")
  grep -q '\.rs$'    "$tmp" && langs+=("rust")
  grep -q '\.java$'  "$tmp" && langs+=("java")
  grep -q '\.rb$'    "$tmp" && langs+=("ruby")
  grep -q '\.php$'   "$tmp" && langs+=("php")
  rm -f "$tmp"
  # JS si hay package.json y no se detectó TS
  if [[ -f "$t/package.json" ]]; then
    local has_ts=0 l
    for l in "${langs[@]:-}"; do [[ "$l" == "typescript" ]] && has_ts=1; done
    [[ "$has_ts" -eq 0 ]] && langs+=("javascript")
  fi
  if [[ "${#langs[@]}" -eq 0 ]]; then
    printf '%s' '[]'
  else
    printf '%s\n' "${langs[@]}" | jq -R . | jq -s .
  fi
}

# ── repo · gestor de paquetes (enum del schema) ───────────────────
detect_pm() {
  local t="$1"
  # Corepack: el campo packageManager declara el PM canónico (prioridad).
  if [[ -f "$t/package.json" ]]; then
    local pmfield
    pmfield="$(jq -r '.packageManager // empty' "$t/package.json" 2>/dev/null | cut -d@ -f1 || true)"
    case "$pmfield" in
      pnpm|yarn|npm|bun) printf '%s' "$pmfield"; return ;;
    esac
  fi
  [[ -f "$t/pnpm-lock.yaml" ]]    && { printf '%s' "pnpm";   return; }
  [[ -f "$t/yarn.lock" ]]         && { printf '%s' "yarn";   return; }
  # P3: Bun >=1.2 usa bun.lock (texto) por defecto, no bun.lockb.
  { [[ -f "$t/bun.lockb" ]] || [[ -f "$t/bun.lock" ]]; } && { printf '%s' "bun"; return; }
  [[ -f "$t/package-lock.json" ]] && { printf '%s' "npm";    return; }
  [[ -f "$t/deno.lock" ]]         && { printf '%s' "deno";   return; }
  [[ -f "$t/Cargo.lock" ]]        && { printf '%s' "cargo";  return; }
  { [[ -f "$t/go.sum" ]] || [[ -f "$t/go.mod" ]]; } && { printf '%s' "go"; return; }
  [[ -f "$t/uv.lock" ]]           && { printf '%s' "uv";     return; }
  [[ -f "$t/poetry.lock" ]]       && { printf '%s' "poetry"; return; }
  { [[ -f "$t/pyproject.toml" ]] || [[ -f "$t/requirements.txt" ]]; } && { printf '%s' "pip"; return; }
  [[ -f "$t/Gemfile.lock" ]] || [[ -f "$t/Gemfile" ]]         && { printf '%s' "bundler";  return; }
  [[ -f "$t/composer.lock" ]] || [[ -f "$t/composer.json" ]]  && { printf '%s' "composer"; return; }
  [[ -f "$t/package.json" ]]      && { printf '%s' "npm";     return; }
  printf '%s' "none"
}

# ── ds-003 · Detectar frameworks via package.json ─────────────────
detect_frameworks() {
  local t="$1"
  [[ ! -f "$t/package.json" ]] && { printf '%s' '[]'; return; }
  jq '
    [ (.dependencies // {}) + (.devDependencies // {})
      | to_entries[]
      | select(.key | test("^(next|react|vue|svelte|@sveltejs/kit|astro|remix|@remix-run/.*|nuxt|@nuxt/.*|gatsby|expo|@angular/core|solid-js|qwik)$"))
      | { nombre: .key,
          version_min: (.value | tostring | ltrimstr("^") | ltrimstr("~") | ltrimstr(">=")) }
    ]
  ' "$t/package.json" 2>/dev/null || printf '%s' '[]'
}

# ── ds-004 · Detectar tooling (linter/formatter/tester/bundler) ──
detect_tooling() {
  local t="$1"
  if [[ ! -f "$t/package.json" ]]; then
    printf '%s' '{"linter":[],"formatter":[],"tester":[],"bundler":null}'
    return
  fi
  local dev_deps linter=() formatter=() tester=() bundler="null"
  dev_deps="$(jq -r '((.devDependencies // {}) + (.dependencies // {})) | keys[]' "$t/package.json" 2>/dev/null || true)"

  grep -q 'eslint'     <<<"$dev_deps" && linter+=("eslint")
  grep -q 'biome'      <<<"$dev_deps" && linter+=("biome")
  grep -q 'oxlint'     <<<"$dev_deps" && linter+=("oxlint")
  grep -q 'prettier'   <<<"$dev_deps" && formatter+=("prettier")
  grep -q 'biome'      <<<"$dev_deps" && formatter+=("biome")
  grep -q 'vitest'     <<<"$dev_deps" && tester+=("vitest")
  grep -q 'jest'       <<<"$dev_deps" && tester+=("jest")
  grep -q 'playwright' <<<"$dev_deps" && tester+=("playwright")
  grep -qE '(^|/)turbopack' <<<"$dev_deps" && bundler='"turbopack"'
  [[ "$bundler" == "null" ]] && grep -qE '(^|/)vite$'    <<<"$dev_deps" && bundler='"vite"'
  [[ "$bundler" == "null" ]] && grep -qE '(^|/)webpack$' <<<"$dev_deps" && bundler='"webpack"'
  [[ "$bundler" == "null" ]] && grep -qE '(^|/)rollup$'  <<<"$dev_deps" && bundler='"rollup"'
  [[ "$bundler" == "null" ]] && grep -qE '(^|/)esbuild$' <<<"$dev_deps" && bundler='"esbuild"'

  local l_json f_json t_json
  if [[ "${#linter[@]}" -eq 0 ]];    then l_json='[]'; else l_json="$(printf '%s\n' "${linter[@]}"    | jq -R . | jq -s .)"; fi
  if [[ "${#formatter[@]}" -eq 0 ]]; then f_json='[]'; else f_json="$(printf '%s\n' "${formatter[@]}" | jq -R . | jq -s .)"; fi
  if [[ "${#tester[@]}" -eq 0 ]];    then t_json='[]'; else t_json="$(printf '%s\n' "${tester[@]}"    | jq -R . | jq -s .)"; fi

  jq -n \
    --argjson l "$l_json" \
    --argjson f "$f_json" \
    --argjson tt "$t_json" \
    --argjson b "$bundler" \
    '{linter:$l, formatter:$f, tester:$tt, bundler:$b}'
}

# ── repo · huellas infra ──────────────────────────────────────────
detect_infra() {
  local t="$1"
  jq -n \
    --argjson docker     "$([[ -f "$t/Dockerfile" ]] && echo true || echo false)" \
    --argjson docker_c   "$({ [[ -f "$t/docker-compose.yml" ]] || [[ -f "$t/docker-compose.yaml" ]] || [[ -f "$t/compose.yaml" ]]; } && echo true || echo false)" \
    --argjson dokploy    "$({ [[ -f "$t/dokploy.yaml" ]] || [[ -f "$t/.dokploy" ]]; } && echo true || echo false)" \
    --argjson vercel     "$({ [[ -f "$t/vercel.json" ]] || [[ -d "$t/.vercel" ]]; } && echo true || echo false)" \
    --argjson gh_actions "$([[ -d "$t/.github/workflows" ]] && echo true || echo false)" \
    '{docker:$docker, docker_compose:$docker_c, dokploy:$dokploy, vercel:$vercel, github_actions:$gh_actions}'
}

# Mapea un string de os-release (ID o ID_LIKE) a una familia del enum del schema.
_map_distro_familia() {
  case "$1" in
    *arch*)                                   printf 'arch' ;;
    *debian*|*ubuntu*)                        printf 'debian' ;;
    *fedora*|*rhel*|*centos*|*rocky*|*alma*)  printf 'fedora' ;;
    *nixos*)                                  printf 'nixos' ;;
    *alpine*)                                 printf 'alpine' ;;
    *gentoo*)                                 printf 'gentoo' ;;
    *)                                        printf 'unknown' ;;
  esac
}

# ── ds-005 · Detectar huellas de host (env + world-readable) ──────
# Honra escalada.fallback_sin_escalada: huellas que requieran privilegio
# y no estén disponibles → se marcan "skipped" en _skipped[] (no fallan).
detect_host() {
  local distro="unknown" distro_id="unknown" init_sys="unknown" desktop="none" display="tty"
  local gpu="none" audio="none" bluetooth="none"
  local skipped=()

  if [[ -r /etc/os-release ]]; then
    local id id_like
    id="$(grep -E '^ID=' /etc/os-release | head -1 | cut -d= -f2 | tr -d '"' || true)"
    id_like="$(grep -E '^ID_LIKE=' /etc/os-release | head -1 | cut -d= -f2 | tr -d '"' || true)"
    [[ -n "$id" ]] && distro_id="$id"
    # Spec os-release: clasificar por ID; ID_LIKE solo si ID no se reconoce.
    distro="$(_map_distro_familia "$id")"
    [[ "$distro" == "unknown" && -n "$id_like" ]] && distro="$(_map_distro_familia "$id_like")"
  else
    skipped+=("os-release: no legible")
  fi

  # init: /proc/1/comm es la señal primaria (qué corre como PID 1).
  case "$(cat /proc/1/comm 2>/dev/null || true)" in
    systemd)        init_sys="systemd" ;;
    runit|runsvdir) init_sys="runit" ;;
    openrc-init)    init_sys="openrc" ;;
  esac
  if [[ "$init_sys" == "unknown" ]]; then
    command -v systemctl >/dev/null 2>&1 && init_sys="systemd"
    command -v rc-update >/dev/null 2>&1 && init_sys="openrc"
    command -v runit     >/dev/null 2>&1 && init_sys="runit"
  fi

  # P4: display server · loginctl cubre casos headless/startx donde las env vars faltan.
  if [[ -n "${WAYLAND_DISPLAY:-}" ]] || [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]]; then
    display="wayland"
  elif [[ "${XDG_SESSION_TYPE:-}" == "x11" ]]; then
    display="x11"
  elif command -v loginctl >/dev/null 2>&1 && [[ -n "${XDG_SESSION_ID:-}" ]]; then
    case "$(loginctl show-session "${XDG_SESSION_ID}" -p Type --value 2>/dev/null || true)" in
      wayland) display="wayland" ;;
      x11)     display="x11" ;;
    esac
  elif [[ -n "${DISPLAY:-}" ]]; then
    display="x11"
  fi

  local cur="${XDG_CURRENT_DESKTOP:-}"
  case "$cur" in
    *GNOME*)    desktop="gnome" ;;
    *KDE*)      desktop="kde" ;;
    *Hyprland*) desktop="hyprland" ;;
    *XFCE*)     desktop="xfce" ;;
    *sway*)     desktop="sway" ;;
  esac

  # P5: gpu_vendor · sysfs primero (sin binarios, funciona headless), lspci fallback.
  local vfile vid
  for vfile in /sys/class/drm/card[0-9]*/device/vendor; do
    [[ -r "$vfile" ]] || continue
    vid="$(cat "$vfile" 2>/dev/null || true)"
    case "$vid" in
      0x10de) gpu="nvidia"; break ;;
      0x1002) gpu="amd";    break ;;
      0x8086) [[ "$gpu" == "none" ]] && gpu="intel" ;;
    esac
  done
  if [[ "$gpu" == "none" ]]; then
    if command -v lspci >/dev/null 2>&1; then
      local pci
      pci="$(lspci 2>/dev/null || true)"
      grep -qi 'nvidia' <<<"$pci" && gpu="nvidia"
      [[ "$gpu" == "none" ]] && grep -qiE 'amd|advanced micro devices.*(vga|display|3d)' <<<"$pci" && gpu="amd"
      [[ "$gpu" == "none" ]] && grep -qiE 'intel.*(graphics|vga)' <<<"$pci" && gpu="intel"
    else
      skipped+=("gpu_vendor: sin /sys/class/drm legible ni lspci · huella omitida")
    fi
  fi

  # P1: audio · pactl existe igual con PulseAudio puro y con pipewire-pulse, así que
  # NO distingue por sí solo. Preferir señales de "corriendo": socket → Server Name → PID.
  if [[ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/pipewire-0" ]]; then
    audio="pipewire"
  elif command -v pactl >/dev/null 2>&1 && pactl info >/dev/null 2>&1; then
    if pactl info 2>/dev/null | grep -qiE 'Server Name:.*PipeWire'; then
      audio="pipewire"
    else
      audio="pulseaudio"
    fi
  elif command -v pipewire >/dev/null 2>&1; then
    audio="pipewire"
  elif command -v pulseaudio >/dev/null 2>&1; then
    audio="pulseaudio"
  elif command -v alsamixer >/dev/null 2>&1 || [[ -d /proc/asound ]]; then
    audio="alsa"
  fi

  command -v bluetoothctl >/dev/null 2>&1 && bluetooth="bluez"

  # container_engines: detección por binario (sin escalada).
  local engines=() ce
  for ce in docker podman nerdctl lxc; do
    command -v "$ce" >/dev/null 2>&1 && engines+=("$ce")
  done
  local engines_json
  if [[ "${#engines[@]}" -eq 0 ]]; then engines_json='[]'; else engines_json="$(printf '%s\n' "${engines[@]}" | jq -R . | jq -s .)"; fi

  # Nota: detect_host corre en una subshell de sustitución de comandos, así que
  # no fijamos PARCIAL aquí (se perdería). El estado parcial se deriva en el
  # shell padre a partir de la presencia de _skipped en el manifiesto final.
  local skipped_json
  if [[ "${#skipped[@]}" -eq 0 ]]; then
    skipped_json='[]'
  else
    skipped_json="$(printf '%s\n' "${skipped[@]}" | jq -R . | jq -s .)"
  fi

  jq -n \
    --arg df "$distro" --arg di "$distro_id" --arg in "$init_sys" --arg de "$desktop" \
    --arg ds "$display" --arg gp "$gpu" --arg au "$audio" --arg bt "$bluetooth" \
    --argjson ce "$engines_json" \
    --argjson sk "$skipped_json" \
    '{distro_familia:$df, distro_id:$di, init:$in, desktop_env:$de, display_server:$ds,
      gpu_vendor:$gp, audio_server:$au, bluetooth:$bt, container_engines:$ce}
     + ( if ($sk | length) > 0 then {_skipped:$sk} else {} end )'
}

# ── dry-run · solo checks con solo_modo incluyendo dry-run (ds-001)
# Nunca toca paths privilegiados; emite manifiesto mínimo conforme.
if [[ "$MODE" == "dry-run" ]]; then
  preflight || exit 2
  T="${TARGET:-$(pwd)}"
  TIPO="$(detect_tipo "$T")"
  jq -n \
    --arg schema "xek/manifest@v2" \
    --arg target "$T" \
    --arg tipo "$TIPO" \
    --arg slug "$SLUG" \
    --arg ver "$VERSION" \
    '{schema:$schema, target:$target, target_tipo:$tipo,
      _meta:{skill:$slug, version:$ver, mode:"dry-run",
             nota:"solo ds-001 ejecutado · sin lectura de archivos internos ni huellas privilegiadas"}}'
  exit 0
fi

# ── sandbox + real ────────────────────────────────────────────────
preflight || exit 2
T="${TARGET:-$(pwd)}"
if [[ "$TARGET_TIPO_OVERRIDE" != "host" ]]; then
  if [[ ! "$T" =~ ^https?:// ]] && [[ ! -e "$T" ]]; then
    echo "target inexistente: $T" >&2
    exit 2
  fi
fi

mkdir -p "$SANDBOX"
TIPO="$(detect_tipo "$T")"

case "$TIPO" in
  repo)
    SHAPE="$(detect_repo_shape "$T")"
    LANGS="$(detect_langs "$T")"
    PM="$(detect_pm "$T")"
    FW="$(detect_frameworks "$T")"
    TL="$(detect_tooling "$T")"
    INF="$(detect_infra "$T")"
    MANIFEST="$(jq -n \
      --arg schema "xek/manifest@v2" \
      --arg target "$T" \
      --arg tipo "$TIPO" \
      --arg shape "$SHAPE" \
      --arg pm "$PM" \
      --argjson langs "$LANGS" \
      --argjson fw "$FW" \
      --argjson tl "$TL" \
      --argjson inf "$INF" \
      '{
        schema: $schema,
        target: $target,
        target_tipo: $tipo,
        repo: {
          tipo: $shape,
          gestor_paquetes: $pm,
          frameworks: $fw,
          lenguajes: $langs,
          tooling: $tl,
          infra_huellas: $inf
        }
      }')"
    ;;
  host)
    HH="$(detect_host)"
    MANIFEST="$(jq -n \
      --arg schema "xek/manifest@v2" \
      --arg target "${T:-$(hostname)}" \
      --arg tipo "$TIPO" \
      --argjson hh "$HH" \
      '{schema:$schema, target:$target, target_tipo:$tipo, host_huellas:$hh}')"
    ;;
  app-en-vivo)
    MANIFEST="$(jq -n \
      --arg schema "xek/manifest@v2" \
      --arg target "$T" \
      --arg tipo "$TIPO" \
      '{schema:$schema, target:$target, target_tipo:$tipo}')"
    ;;
  *)
    echo "target_tipo desconocido: $TIPO" >&2
    exit 2
    ;;
esac

printf '%s\n' "$MANIFEST" > "$SANDBOX/manifest.json"

# Estado parcial: alguna huella se marcó skipped (escalada.fallback_sin_escalada).
if printf '%s' "$MANIFEST" | jq -e '.. | objects | select(has("_skipped")) | ._skipped | length > 0' >/dev/null 2>&1; then
  PARCIAL=1
fi

if [[ "$MODE" == "sandbox" ]]; then
  printf '%s\n' "$MANIFEST" | jq .
  echo "manifest: $SANDBOX/manifest.json" >&2
  [[ "$PARCIAL" -eq 1 ]] && exit 1
  exit 0
fi

if [[ "$MODE" == "real" ]]; then
  # Excluir el run-id actual: 'mkdir -p $SANDBOX' (arriba) crea el dir antes de
  # este gate, así que sin -not -name el find encontraría su propio directorio y
  # el gate siempre pasaría. Solo cuenta un sandbox PREVIO.
  LAST="$(find "$SANDBOX_BASE" -maxdepth 1 -mindepth 1 -type d -not -name "$RUN_ID" -mmin -1440 2>/dev/null | head -1 || true)"
  if [[ -z "$LAST" && -z "$OVERRIDE_GATE" ]]; then
    echo "gate: sandbox previo no encontrado en 24h · usar --override-gate=AUTO_<ts>" >&2
    exit 2
  fi
  OUT_DIR="${XEK_CUADERNO:-$HOME/.claude/cuadernos/xek-cluster}/artefactos/XEK_detecta-stack/$(date +%Y-%m-%d)"
  mkdir -p "$OUT_DIR"
  printf '%s\n' "$MANIFEST" > "$OUT_DIR/manifest.json"
  {
    echo "# Informe XEK_detecta-stack · $(date -Iseconds)"
    echo "target: $T"
    echo "target_tipo: $TIPO"
    echo ""
    echo "## Manifiesto emitido"
    echo '```json'
    printf '%s\n' "$MANIFEST" | jq .
    echo '```'
  } > "$OUT_DIR/informe.md"
  printf '%s\n' "$MANIFEST" | jq .
  echo "manifest: $OUT_DIR/manifest.json" >&2
  echo "informe: $OUT_DIR/informe.md" >&2
  [[ "$PARCIAL" -eq 1 ]] && exit 1
  exit 0
fi

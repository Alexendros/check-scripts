---
slug: XEK_detecta-stack
ambito: Meta
maestria_funcional: revisor
estado: borrador
version: 0.7.2
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "bump de estado stub a borrador per degradacion masiva ronda-002" }
  - { v: 0.7.0, fecha: 2026-05-22, cambio: "SKILL.md completo: frontmatter R4+R7+R14 + precondiciones_runtime + checks[] tipado + bash ejecutable · estado borrador (beta gateado a linter ejecutable)" }
  - { v: 0.7.1, fecha: 2026-06-20, cambio: "runner real scripts/xek-detecta-stack.sh: emite xek/manifest@v2 validado contra schema (jsonschema PASS en repo/host/app-en-vivo), shellcheck-clean, escalada fallback→skipped · estado sigue borrador (linter no gatea beta a runner)" }
  - { v: 0.7.2, fecha: 2026-06-20, cambio: "testera pytest + fixes de heurística validados online: gate real (excluir run-id propio), audio pipewire≠pulseaudio (pactl no distingue), distro_id crudo + precedencia ID/ID_LIKE, bun.lock, gpu vía /sys/class/drm, frameworks @sveltejs/kit·nuxt·gatsby·expo, exclusiones Linguist · SKILL.md deja de duplicar el bash (single source of truth)" }

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

La implementación ejecutable y **única fuente de verdad** es
[`scripts/xek-detecta-stack.sh`](scripts/xek-detecta-stack.sh) (v0.7.2,
shellcheck-clean, cubierto por `tests/test_detecta_stack.py`). El cuerpo del
script no se duplica aquí para evitar drift: el frontmatter `checks[]` y el
comentario-encabezado de arriba son la especificación declarativa.

Firma y contrato:

```bash
xek-detecta-stack.sh --mode {dry-run|sandbox|real} \
  [--target <path|url>] [--target-tipo {repo|host|app-en-vivo}] \
  [--override-gate=AUTO_<ts>]
# exit: 0 OK · 1 parcial (_skipped) · 2 config error · 3 falta --mode · 4 ill-call
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

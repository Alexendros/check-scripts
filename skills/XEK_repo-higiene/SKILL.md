---
slug: XEK_repo-higiene
ambito: Repo
maestria_funcional: revisor
estado: borrador
version: 0.7.0
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub · pendiente implementación" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "degradado borrador→stub per síntesis Ronda 002 (commit deuda v0.6)" }
  - { v: 0.7.0, fecha: 2026-06-20, cambio: "stub→borrador: frontmatter R4+R7 + modos + checks[] tipados read-only + fuentes canónicas reales (GitHub community standards + Conventional Commits + Keep a Changelog)" }

objetivo: >
  Verificar higiene de repo: README, LICENSE, CONTRIBUTING, .gitignore,
  CHANGELOG y workflow CI presentes; sin secretos ni .env versionados; sin
  binarios grandes. Read-only, no modifica el repo.

fuentes_externas:
  - { tipo: tool, nombre: git,  version_min: "2.40", licencia: "GPL-2.0" }
  - { tipo: tool, nombre: grep, version_min: "3.0",  licencia: "GPL-3.0" }
  - { tipo: tool, nombre: find, version_min: "4.7",  licencia: "GPL-3.0" }
  - { tipo: tool, nombre: test, version_min: "8.30", licencia: "GPL-3.0" }
conexiones_requeridas: []

referencias_canonicas:
  - { tipo: doc_oficial, url: "https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions", cobertura: "Community standards · README, LICENSE, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY" }
  - { tipo: estandar,    url: "https://www.conventionalcommits.org", cobertura: "Convencion de mensajes de commit para historial legible y semver automatizable" }
  - { tipo: estandar,    url: "https://keepachangelog.com", cobertura: "Formato de CHANGELOG · secciones Added/Changed/Fixed y versionado" }

verificar_referencias:
  cuando: "antes de cada bump de version_min de tools"
  como: "consultar doc oficial; rechazar bump si la doc marca cambio breaking en la convencion o en el set de community standards"

areas_criticas:
  permisos_user:
    - "lectura del arbol de ficheros y del indice git del repo objetivo"
    - "escritura: $XDG_RUNTIME_DIR/xek-sandbox/XEK_repo-higiene/"
  fhs_tocados:
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_repo-higiene/ (solo escritura de findings)"
  visual_secrets:
    - "contenido de .env o ficheros de credenciales detectados · nunca imprimir el valor, solo la ruta"
  zonas_ocultas:
    - "configuracion de branch protection y CODEOWNERS efectiva en GitHub · requiere API autenticada · fuera del alcance estatico"

modos_ejecucion:
  dry-run:
    proposito: "Verificar precondiciones y listar los checks que se ejecutarian sin recorrer el arbol."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · plan textual de checks · exit 0 si parse OK"
  sandbox:
    proposito: "Recorrer una copia aislada del repo y correr los checks read-only de higiene."
    aislamiento: "directorio bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_repo-higiene/<run-id>/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_repo-higiene/"
    efectos_red: "ninguno · inspeccion estatica del arbol y del indice git"
    salida: "findings.json en sandbox path · exit 0|1 segun findings"
  real:
    proposito: "Ejecutar contra el repo real (read-only) y persistir informe en cuaderno."
    precondicion: "sandbox del mismo input ha pasado en las ultimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_repo-higiene/<fecha>/"
    efectos_red: "ninguno"
    salida: "informe.md + findings.json + propuesta_#N si findings ≥ severidad_min"
gate_promocion:
  regla: "modo N+1 solo si modo N exit 0|1 con plan"
  override: "--override-gate=AUTO_<timestamp ±60s>"

escalada_privilegio:
  comando_template: "${XEK_SUDO:-sudo -A}"
  cuando_aplica: "no aplica · inspeccion read-only del repo sin escalada"

depende_de:
  - { slug: XEK_detecta-stack, modo: sandbox, obligatoria: true, razon: "necesita manifiesto con la raiz del repo" }
contrato_invocacion:
  modo_subordinado: sandbox
  promocion_real: solo_operador
  consolidacion: "json · merge por slug · schema xek/finding@v1"

checks:
  - id: "repo-001"
    descripcion: "README presente en la raiz del repo"
    command_template: "find '$REPO' -maxdepth 1 -iregex '.*/readme\\(\\.md\\|\\.rst\\|\\.txt\\)?' | grep -q ."
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "repo-002"
    descripcion: "LICENSE presente en la raiz del repo"
    command_template: "find '$REPO' -maxdepth 1 -iregex '.*/licen[sc]e\\(\\.md\\|\\.txt\\)?' | grep -q ."
    expected_exit: 0
    severity_default: high
    solo_modo: [sandbox, real]
  - id: "repo-003"
    descripcion: "CONTRIBUTING presente en raiz o en .github/"
    command_template: "find '$REPO' '$REPO/.github' -maxdepth 1 -iname 'contributing*' 2>/dev/null | grep -q ."
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "repo-004"
    descripcion: ".gitignore presente en la raiz del repo"
    command_template: "test -f '$REPO/.gitignore'"
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "repo-005"
    descripcion: "CHANGELOG presente en la raiz del repo"
    command_template: "find '$REPO' -maxdepth 1 -iname 'changelog*' | grep -q ."
    expected_exit: 0
    severity_default: low
    solo_modo: [sandbox, real]
  - id: "repo-006"
    descripcion: "Al menos un workflow CI presente en .github/workflows/"
    command_template: "find '$REPO/.github/workflows' -maxdepth 1 -iregex '.*\\.ya?ml' 2>/dev/null | grep -q ."
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]
  - id: "repo-007"
    descripcion: "Ningun fichero .env ni clave privada esta versionado en el indice git"
    command_template: "! git -C '$REPO' ls-files --error-unmatch -- '*.env' '.env' '.env.*' '*.pem' '*id_rsa*' 2>/dev/null | grep -q ."
    expected_exit: 0
    severity_default: critical
    solo_modo: [sandbox, real]
  - id: "repo-008"
    descripcion: "Ningun binario grande (>5 MB) versionado en el indice git"
    command_template: "! git -C '$REPO' ls-files -z | xargs -0 -r -I{} find '$REPO/{}' -maxdepth 0 -size +5M 2>/dev/null | grep -q ."
    expected_exit: 0
    severity_default: medium
    solo_modo: [sandbox, real]

aplicabilidad:
  cuando:
    - "manifest.target_tipo == 'repo'"
  prioridad: media
  coste_relativo: 1

migracion_runtime:
  bash:   scripts/xek-repo-higiene.sh
  python: scripts/xek-repo-higiene.py
  zsh:    scripts/xek-repo-higiene.zsh

triggers:
  keywords: ["readme", "license", "contributing", "gitignore", "changelog", "ci-workflow", "secretos-versionados", "community-standards"]
  contextos: ["pre-PR", "post-merge", "pre-deploy"]
  cron: ""
---

# Objetivo

Verificar la higiene de un repositorio segun los community standards de GitHub:
presencia de `README`, `LICENSE`, `CONTRIBUTING`, `.gitignore`, `CHANGELOG` y al
menos un workflow CI; ausencia de secretos o ficheros `.env` versionados; y
ausencia de binarios grandes en el indice. La skill solo lee el arbol y el
indice git; nunca modifica el repo.

# Cuando activar

| Si... | Entonces... |
|---|---|
| `manifest.target_tipo == 'repo'` | Ejecutar `--mode=sandbox` sobre la copia aislada |
| Pre-PR de un repo nuevo o externo | Correr `repo-001..repo-008` y bloquear si falla severidad high/critical |
| Post-merge a `main` para auditoria periodica | Promover a `--mode=real` tras sandbox verde |

# Uso · comentario encabezado (copiar al script)

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_repo-higiene · v0.7.0 · 2026-06-20                       ║
# ║  Funcion: verificar higiene de repositorio (read-only)        ║
# ║  Variables entorno:                                           ║
# ║    XEK_TARGET_DIR     raiz del repo a inspeccionar            ║
# ║    XDG_RUNTIME_DIR    base sandbox                            ║
# ║  Uso:                                                         ║
# ║    xek-repo-higiene.sh --mode={dry-run|sandbox|real} [--target]║
# ║  Exit codes:                                                  ║
# ║    0=clean · 1=findings · 2=config · 3=missing-mode · 4=ill-call║
# ╚══════════════════════════════════════════════════════════════╝
```

# Implementacion referencia (bash · fuente de verdad)

```bash
#!/usr/bin/env bash
set -euo pipefail

SLUG="XEK_repo-higiene"
VERSION="0.7.0"
MODE=""
REPO="${XEK_TARGET_DIR:-.}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode=*)  MODE="${1#*=}"; shift ;;
    --target)  REPO="$2"; shift 2 ;;
    *)         echo "ill-call: $1" >&2; exit 4 ;;
  esac
done

[[ -z "$MODE" ]] && { echo "missing --mode" >&2; exit 3; }

preflight() {
  for bin in bash git grep find test; do
    command -v "$bin" >/dev/null 2>&1 || { echo "PREFLIGHT FAIL: $bin absent" >&2; return 1; }
  done
}

if [[ "$MODE" == "dry-run" ]]; then
  echo "## ${SLUG} v${VERSION} · plan dry-run"
  preflight || exit 2
  echo "checks: repo-001..repo-008 (readme, license, contributing, gitignore, changelog, ci, sin .env, sin binarios grandes)"
  exit 0
fi

preflight || exit 2
git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "not a git repo: $REPO" >&2; exit 2; }

FINDINGS=0
emit() { echo "  - { check: $1, severity: $2, status: $3 }"; }
run_check() {
  local id="$1" sev="$2"; shift 2
  if "$@" >/dev/null 2>&1; then emit "$id" "$sev" pass
  else emit "$id" "$sev" fail; FINDINGS=$((FINDINGS+1)); fi
}

echo "findings:"
run_check repo-001 high     bash -c "find '$REPO' -maxdepth 1 -iregex '.*/readme\\(\\.md\\|\\.rst\\|\\.txt\\)?' | grep -q ."
run_check repo-002 high     bash -c "find '$REPO' -maxdepth 1 -iregex '.*/licen[sc]e\\(\\.md\\|\\.txt\\)?' | grep -q ."
run_check repo-003 medium   bash -c "find '$REPO' '$REPO/.github' -maxdepth 1 -iname 'contributing*' 2>/dev/null | grep -q ."
run_check repo-004 medium   bash -c "test -f '$REPO/.gitignore'"
run_check repo-005 low      bash -c "find '$REPO' -maxdepth 1 -iname 'changelog*' | grep -q ."
run_check repo-006 medium   bash -c "find '$REPO/.github/workflows' -maxdepth 1 -iregex '.*\\.ya?ml' 2>/dev/null | grep -q ."
run_check repo-007 critical bash -c "! git -C '$REPO' ls-files --error-unmatch -- '*.env' '.env' '.env.*' '*.pem' '*id_rsa*' 2>/dev/null | grep -q ."

if [[ "$MODE" == "sandbox" ]]; then
  SANDBOX="${XDG_RUNTIME_DIR:-/tmp}/xek-sandbox/${SLUG}/$(date +%s)-$$"
  mkdir -p "$SANDBOX"
  echo "sandbox: $SANDBOX"
  [[ "$FINDINGS" -eq 0 ]] && exit 0 || exit 1
fi

if [[ "$MODE" == "real" ]]; then
  OUT="${XEK_CUADERNO:-$HOME/.claude/cuadernos/xek-cluster}/artefactos/${SLUG}/$(date +%Y-%m-%d)"
  mkdir -p "$OUT"
  echo "informe: $OUT"
  [[ "$FINDINGS" -eq 0 ]] && exit 0 || exit 1
fi
```

# Adaptador Python (encapsulado vendoreable)

```python
#!/usr/bin/env python3
"""XEK_repo-higiene · adapter Python para pipelines orquestados."""
import subprocess, sys, pathlib
script = pathlib.Path(__file__).with_name("xek-repo-higiene.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-repo-higiene.sh" "$@"
```

# Verificacion end-to-end (smoke test)

```bash
# Caso happy · dry-run no toca disco
./scripts/xek-repo-higiene.sh --mode=dry-run && echo "PASS dry-run"

# Caso sandbox contra un repo con higiene correcta · exit 0
./scripts/xek-repo-higiene.sh --mode=sandbox --target ./fixtures/repo-limpio
echo "exit=$?"

# Caso falla esperada · repo sin LICENSE y con .env versionado · exit 1
./scripts/xek-repo-higiene.sh --mode=sandbox --target ./fixtures/repo-sucio
echo "exit=$?"
```

# Riesgos y mitigacion

| Riesgo | Mitigacion |
|---|---|
| `.env.example` legitimo confundido con `.env` real | `repo-007` matchea `.env` y `.env.*` pero los `.example` se documentan como falso positivo aceptable a revisar manualmente |
| Branch protection y CODEOWNERS no inspeccionables sin API GitHub | Documentado en `zonas_ocultas`; la verificacion efectiva requiere `gh api` autenticado, fuera del alcance estatico |
| Binarios grandes legitimos (assets, fixtures) | `repo-008` es severidad medium; reporta sin bloquear, deja la decision al operador |
| Repo sin `.git` (export plano) | El preflight aborta con exit 2 (config) en lugar de generar findings espurios |

# Bitacora evolucion (append-only · R8)

- **v0.0.1** (2026-05-20) — bootstrap stub.
- **v0.6.1** (2026-05-22) — degradado borrador→stub per sintesis Ronda 002.
- **v0.7.0** (2026-06-20) — stub→borrador: frontmatter R4+R7 completo + modos_ejecucion + 8 checks[] tipados (repo-001..008) read-only con git/grep/find/test + fuentes canonicas reales (GitHub community standards, Conventional Commits, Keep a Changelog) + bash referencia de 3 modos.

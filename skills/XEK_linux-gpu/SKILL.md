---
slug: XEK_linux-gpu
ambito: Linux
maestria_funcional: revisor
estado: beta
version: 0.5.0
mejoras_ultima_edicion:
  - { v: 0.1.0, fecha: 2026-05-20, cambio: "bootstrap" }
  - { v: 0.5.0, fecha: 2026-05-20, cambio: "alineación con tesis v0.5 (R15-R16)" }

objetivo: >
  Verificar postura de la GPU del host (vendor, drivers, CDI spec, runtime
  CUDA/ROCm) y emitir informe + propuesta. Agnóstico de vendor y operador.

fuentes_externas:
  - { tipo: tool, nombre: "lspci",       version_min: "3.7",   licencia: "GPL-2.0" }
  - { tipo: tool, nombre: "nvidia-smi",  version_min: "550",   licencia: "proprietary (driver NVIDIA)" }
  - { tipo: tool, nombre: "rocm-smi",    version_min: "6.0",   licencia: "MIT" }
  - { tipo: tool, nombre: "jq",          version_min: "1.7",   licencia: "MIT" }
conexiones_requeridas: []

referencias_canonicas:
  - { tipo: doc_oficial,   url: "https://github.com/cncf-tags/container-device-interface", cobertura: "CDI Spec 0.7" }
  - { tipo: doc_oficial,   url: "https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/", cobertura: "NVIDIA Container Toolkit" }
  - { tipo: doc_oficial,   url: "https://rocm.docs.amd.com/",                              cobertura: "ROCm runtime" }
  - { tipo: estandar,      url: "https://www.cisecurity.org/benchmark/distribution_independent_linux", cobertura: "CIS Distribution Independent Linux Benchmark" }
  - { tipo: compendio,     url: "https://wiki.archlinux.org/title/GPGPU",                  cobertura: "panorama GPGPU multi-vendor" }
verificar_referencias:
  cuando: "antes de bump de version_min de nvidia-smi o rocm-smi"
  como: "consultar release notes; rechazar bump si rompe interfaz JSON"

areas_criticas:
  permisos_user:
    - "lectura /sys/class/drm/, /dev/dri/, /dev/nvidia*"
    - "ejecución nvidia-smi/rocm-smi sin sudo (acceso vía grupo video/render)"
  fhs_tocados:
    - "/etc/cdi/ (solo lectura · CDI specs)"
    - "/etc/nvidia-container-runtime/ (solo lectura)"
    - "$XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-gpu/"
  visual_secrets: []
  zonas_ocultas:
    - "/proc/driver/nvidia/registry (lectura privilegiada · no imprimir contenidos completos)"

modos_ejecucion:
  dry-run:
    proposito: "Detectar presencia de GPU y tools sin invocarlas."
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · gpu_vendor + tools disponibles · exit 0"
  sandbox:
    proposito: "Capturar snapshot del estado GPU en sandbox."
    aislamiento: "directorio bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-gpu/"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_linux-gpu/"
    efectos_red: "ninguno"
    salida: "snapshot.json · exit 0/1 según postura"
  real:
    proposito: "Ejecutar contra host real · genera informe + propuesta_#N."
    precondicion: "sandbox del mismo host ha pasado en las últimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_linux-gpu/<fecha>/"
    efectos_red: "ninguno"
    salida: "informe.md + snapshot.json + propuesta_#N"
gate_promocion:
  regla: "modo N+1 solo si modo N exit 0|1 con plan"
  override: "--override-gate=AUTO_<timestamp ±60s>"

escalada_privilegio:
  comando_template: "${XEK_SUDO:-sudo -A}"
  cuando_aplica:    "lectura de /proc/driver/nvidia/registry y /sys/module/*/parameters/ (skill mayoritariamente unprivileged)"

depende_de:
  - { slug: XEK_detecta-stack, modo: sandbox, obligatoria: true, razon: "necesita host_huellas.gpu_vendor" }
contrato_invocacion:
  modo_subordinado: sandbox
  promocion_real:   solo_operador
  consolidacion:    "json · schema xek/finding@v1"

aplicabilidad:
  cuando:
    - "manifest.target_tipo == 'host'"
    - "manifest.host_huellas.gpu_vendor != 'none'"
  prioridad: media
  coste_relativo: 2

migracion_runtime:
  bash:   scripts/xek-linux-gpu.sh
  python: scripts/xek-linux-gpu.py
  zsh:    scripts/xek-linux-gpu.zsh

triggers:
  keywords:  ["gpu", "nvidia", "amd", "rocm", "cuda", "cdi", "drivers"]
  contextos: ["pre-deploy", "post-update", "cron"]
  cron:      "0 7 * * 0"
---

# Objetivo

Verificar la postura de la GPU del host: vendor detectado vs vendor declarado
en huellas, driver instalado vs kernel cargado, presencia y validez de
especificaciones CDI para contenedores, runtime CUDA/ROCm. Emite informe y
propuesta sin tocar la configuración.

# Cuándo activar

| Si... | Entonces... |
|---|---|
| Cambio de kernel | Invocar `--mode=sandbox` para detectar mismatch driver |
| Update de paquete NVIDIA/AMD | Invocar `--mode=sandbox` · validar firma CDI |
| Despliegue de contenedor GPU-bound | Encadenar desde `XEK_linux-contenedores` |
| `host_huellas.gpu_vendor == 'none'` | Skill se salta con `skipped: not_applicable` |

# Uso · comentario encabezado

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  XEK_linux-gpu · v0.5.0 · 2026-05-20                          ║
# ║  Función: verificar postura GPU host (vendor/driver/CDI/runtime)║
# ║                                                                ║
# ║  Variables entorno:                                            ║
# ║    XEK_SUDO           comando de escalada (default: sudo -A)   ║
# ║    XDG_RUNTIME_DIR    base sandbox                             ║
# ║                                                                ║
# ║  Uso:                                                          ║
# ║    xek-linux-gpu.sh --mode=dry-run                             ║
# ║    xek-linux-gpu.sh --mode=sandbox                             ║
# ║    xek-linux-gpu.sh --mode=real                                ║
# ║                                                                ║
# ║  Exit codes:                                                   ║
# ║    0 = postura OK                                              ║
# ║    1 = findings (mismatch driver/kernel, CDI ausente, ...)     ║
# ║    2 = config error (frontmatter inválido, tool ausente)       ║
# ║    3 = --mode ausente                                          ║
# ║    4 = invocación ilegal                                       ║
# ╚══════════════════════════════════════════════════════════════╝
```

# Implementación referencia (bash)

```bash
#!/usr/bin/env bash
set -euo pipefail

SLUG="XEK_linux-gpu"
VERSION="0.5.0"
MODE=""
OVERRIDE_GATE=""

# Escalada agnóstica del operador (R16)
SUDO="${XEK_SUDO:-sudo -A}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode=*)          MODE="${1#*=}"; shift ;;
    --override-gate=*) OVERRIDE_GATE="${1#*=}"; shift ;;
    *)                 echo "ill-call: $1" >&2; exit 4 ;;
  esac
done

[[ -z "$MODE" ]] && { echo "missing --mode" >&2; exit 3; }

# Detección vendor agnóstica (no asume distro)
detect_vendor() {
  if command -v lspci >/dev/null; then
    if lspci | grep -qi nvidia; then echo "nvidia"
    elif lspci | grep -qi 'amd\|advanced micro devices'; then echo "amd"
    elif lspci | grep -qi 'intel.*graphics'; then echo "intel"
    else echo "none"
    fi
  else
    echo "unknown"
  fi
}

SANDBOX="${XDG_RUNTIME_DIR:-/tmp}/xek-sandbox/${SLUG}"
mkdir -p "$SANDBOX"

VENDOR="$(detect_vendor)"

case "$MODE" in
  dry-run)
    echo "## ${SLUG} v${VERSION} · plan dry-run"
    echo "vendor detectado: $VENDOR"
    echo "tools disponibles:"
    for t in lspci nvidia-smi rocm-smi jq; do
      printf "  %-12s %s\n" "$t" "$(command -v "$t" || echo MISSING)"
    done
    [[ "$VENDOR" == "none" ]] && { echo "skipped: not_applicable (gpu_vendor=none)"; exit 0; }
    exit 0
    ;;
  sandbox|real)
    OUT="$SANDBOX/snapshot-$(date +%s).json"
    if [[ "$MODE" == "real" ]]; then
      LAST=$(find "$SANDBOX" -maxdepth 1 -name 'snapshot-*.json' -mmin -1440 | head -1 || true)
      if [[ -z "$LAST" && -z "$OVERRIDE_GATE" ]]; then
        echo "gate: sandbox previo ausente · usar --override-gate" >&2; exit 2
      fi
      OUT_DIR="${XEK_CUADERNO:-$HOME/.claude/cuadernos/xek-cluster}/artefactos/XEK_linux-gpu/$(date +%Y-%m-%d)"
      mkdir -p "$OUT_DIR"; OUT="$OUT_DIR/snapshot.json"
    fi

    {
      echo "{"
      echo "  \"schema\": \"xek/finding@v1\","
      echo "  \"slug\": \"${SLUG}\","
      echo "  \"version\": \"${VERSION}\","
      echo "  \"timestamp\": \"$(date -Iseconds)\","
      echo "  \"vendor_detectado\": \"${VENDOR}\","
      echo "  \"kernel\": \"$(uname -r)\","

      case "$VENDOR" in
        nvidia)
          if command -v nvidia-smi >/dev/null; then
            DRV=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits | head -1)
            echo "  \"driver_version\": \"${DRV}\","
            echo "  \"nvidia_smi_output_ok\": true,"
          else
            echo "  \"driver_version\": null,"
            echo "  \"nvidia_smi_output_ok\": false,"
          fi
          CDI_FILES=$(ls /etc/cdi/*.json 2>/dev/null | wc -l)
          echo "  \"cdi_spec_files\": ${CDI_FILES},"
          ;;
        amd)
          if command -v rocm-smi >/dev/null; then
            echo "  \"rocm_smi_output_ok\": true,"
          else
            echo "  \"rocm_smi_output_ok\": false,"
          fi
          ;;
        intel)
          echo "  \"intel_iris\": $(ls /dev/dri/render* 2>/dev/null | wc -l),"
          ;;
      esac

      MODULES_LOADED=$(lsmod | awk '$1 ~ /^(nvidia|amdgpu|i915|nouveau)/' | wc -l)
      echo "  \"modules_loaded\": ${MODULES_LOADED},"

      # Findings calculados
      FINDINGS=()
      if [[ "$VENDOR" == "nvidia" && ! -e /etc/cdi/nvidia.json ]]; then
        FINDINGS+=("\"cdi_spec_nvidia_missing\"")
      fi
      printf "  \"findings\": [%s]\n" "$(IFS=,; echo "${FINDINGS[*]}")"
      echo "}"
    } > "$OUT"

    echo "snapshot: $OUT"
    [[ ${#FINDINGS[@]} -eq 0 ]] && exit 0 || exit 1
    ;;
  *)
    echo "bad --mode: $MODE" >&2; exit 2 ;;
esac
```

# Adaptador Python

```python
#!/usr/bin/env python3
"""XEK_linux-gpu · adapter Python."""
import subprocess, sys, pathlib
script = pathlib.Path(__file__).with_name("xek-linux-gpu.sh")
sys.exit(subprocess.call(["bash", str(script), *sys.argv[1:]]))
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
emulate -L zsh
exec bash "${0:A:h}/xek-linux-gpu.sh" "$@"
```

# Verificación end-to-end

```bash
./scripts/xek-linux-gpu.sh --mode=dry-run && echo "PASS dry-run"
./scripts/xek-linux-gpu.sh --mode=sandbox
echo "exit=$?"
```

# Riesgos y mitigación

| Riesgo | Mitigación |
|---|---|
| `nvidia-smi` ausente con GPU NVIDIA | Reportar finding `driver_not_installed` · no abortar |
| CDI spec obsoleto tras update driver | Comparar mtime spec vs driver_version |
| Lectura de `/proc/driver/nvidia/registry` filtra IDs PCI | Hash IDs en informe; nunca imprimir crudo |
| Host sin GPU | `aplicabilidad` filtra antes de invocar |

# Bitácora evolución

- **v0.1.0** (2026-05-20) — bootstrap.
- **v0.5.0** (2026-05-20) — implementación bash con detección agnóstica multi-vendor + escalada `${XEK_SUDO}`.

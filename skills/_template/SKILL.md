---
# ── Identidad ─────────────────────────────────────────
slug: XEK_<capa>-<herramienta>
ambito: SAST|DAST|SCA|IaC|Integridad|Despliegue|Marca|DatosCriticos|SEO|A11y|Performance|Cookies|Framework|Compliance|Data|Repo|Linux|Meta|Orquesta
maestria_funcional: revisor                          # rol, no producto
estado: borrador
version: 0.0.1
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap" }

# ── Objetivo (≤ 200 caracteres · R6) ─────────────────
objetivo: >
  <una línea descriptiva del fin operativo de esta skill>

# ── Fuentes externas (su update altera comportamiento)
fuentes_externas:
  - { tipo: tool,   nombre: <tool>,            version_min: "<x.y>", licencia: "<SPDX>" }
  - { tipo: action, nombre: actions/checkout,  version: "v4",         licencia: MIT }
conexiones_requeridas:
  - { destino: "<url o servicio>", proto: https, auth: none }

# ── Fuentes canónicas (R4) ───────────────────────────
referencias_canonicas:
  - { tipo: doc_oficial,   url: "<doc oficial upstream>",  cobertura: "uso y configuración" }
  - { tipo: estandar,      url: "<OWASP|NIST|CWE|WCAG|CIS|RFC|ISO>", cobertura: "categorías cubiertas" }
verificar_referencias:
  cuando: "antes de cada bump version_min"
  como: "consultar doc oficial; rechazar bump si la doc marca breaking"

# ── Áreas críticas ───────────────────────────────────
areas_criticas:
  permisos_user:  []
  fhs_tocados:    []
  visual_secrets: []                                   # qué nunca imprimir
  zonas_ocultas:  []                                   # evaluar pero no tocar

# ── Modos de ejecución (orden inviolable · R5) ───────
modos_ejecucion:
  dry-run:
    proposito: "Listar acciones que ejecutaría sin tocar nada."
    efectos_disco: "ninguno"
    efectos_red: "ninguno · prohibido egress salvo doc_oficial cacheada"
    salida: "stdout · plan textual · exit 0 si parse OK"
  sandbox:
    proposito: "Ejecutar contra una copia aislada del objetivo."
    aislamiento: "bwrap | toolbox | git worktree | tmpfs"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/<slug>/"
    efectos_red: "permitido a fuentes_externas declaradas"
    salida: "informe SARIF/JSON en sandbox path · exit 0/1/2 según finding"
  real:
    proposito: "Ejecutar contra el objetivo real (read-only sobre él)."
    precondicion: "sandbox del mismo input ha pasado en las últimas 24h"
    efectos_disco: "solo escribe en cuaderno/artefactos/"
    efectos_red: "permitido a fuentes_externas + target read endpoints"
    salida: "informe final + propuesta_#N si findings ≥ severidad_min"
gate_promocion:
  regla: "Ejecutar modo N+1 solo cuando modo N reportó exit 0 o exit 1 con plan."
  override: "Operador puede forzar real con --override-gate=AUTO_<timestamp ±60s>."

# ── Escalada privilegio (R16 · agnóstica del operador)
escalada_privilegio:
  comando_template: "${XEK_SUDO:-sudo -A}"
  cuando_aplica:    "<solo si la skill requiere lectura privilegiada>"

# ── Composición (R10-R11) ────────────────────────────
depende_de:
  - { slug: XEK_detecta-stack, modo: sandbox, obligatoria: true, razon: "necesita manifiesto" }
contrato_invocacion:
  modo_subordinado: sandbox
  promocion_real:   solo_operador
  consolidacion:    "json · merge por slug · schema xek/finding@v1"

# ── Aplicabilidad declarativa (R14) ──────────────────
aplicabilidad:
  cuando:
    - "manifest.target_tipo == '<repo|app-en-vivo|host>'"
  prioridad: media                                     # alta | media | baja
  coste_relativo: 2                                    # 1..5

# ── Migración runtime ────────────────────────────────
migracion_runtime:
  bash:   scripts/<slug>.sh
  python: scripts/<slug>.py
  zsh:    scripts/<slug>.zsh

# ── Disparadores (R7) ────────────────────────────────
triggers:
  keywords:  ["<keyword1>", "<keyword2>", "<keyword3>"]
  contextos: ["pre-PR", "post-merge", "pre-deploy"]
  cron:      ""
---

# Objetivo

<repite y expande lo del frontmatter para humanos>

# Cuándo activar

| Si... | Entonces... |
|---|---|
| <condición> | <acción esperada> |

# Uso · comentario encabezado (copiar al script)

```bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  <slug> · v<version> · <fecha>                                ║
# ║  Función: <una línea>                                          ║
# ║  Variables entorno:                                            ║
# ║    XEK_SUDO            comando de escalada (default: sudo -A)  ║
# ║    XDG_RUNTIME_DIR     base sandbox                            ║
# ║  Uso:                                                          ║
# ║    <slug>.sh --mode={dry-run|sandbox|real} [--target <path>]   ║
# ║  Exit codes:                                                   ║
# ║    0=clean · 1=findings · 2=config · 3=missing-mode · 4=ill-call║
# ╚══════════════════════════════════════════════════════════════╝
```

# Implementación referencia (bash · fuente de verdad)

```bash
#!/usr/bin/env bash
set -euo pipefail
# TODO: implementar los 3 modos siguiendo el contrato del frontmatter.
```

# Adaptador Python (encapsulado vendoreable)

```python
#!/usr/bin/env python3
"""<slug> · adapter Python"""
# TODO: implementar
```

# Adaptador zsh

```zsh
#!/usr/bin/env zsh
# TODO: source bash + ajustes zsh-nativos
```

# Verificación end-to-end (smoke test)

```bash
# Caso happy
./scripts/<slug>.sh --mode=dry-run && echo "PASS dry-run"

# Caso falla esperada
# TODO: añadir caso que produzca exit 1 con plan
```

# Riesgos y mitigación

| Riesgo | Mitigación |
|---|---|
| <riesgo concreto> | <mitigación con referencia> |

# Bitácora evolución (append-only · R8)

- **v0.0.1** (2026-05-20) — bootstrap. Frontmatter mínimo · sin implementación.

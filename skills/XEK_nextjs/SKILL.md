---
slug: XEK_nextjs
ambito: Framework
maestria_funcional: revisor
estado: stub
version: 0.6.1
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub · pendiente implementación" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "degradado borrador→stub per síntesis Ronda 002 (commit deuda v0.6)" }

objetivo: >
  App Router · RSC vs client · next/image · middleware · ISR.

fuentes_externas: []          # TODO: declarar tools concretas con version_min + licencia SPDX
conexiones_requeridas: []

referencias_canonicas:        # TODO: ≥1 doc_oficial + ≥1 estandar (R4)
  - { tipo: doc_oficial, url: "TODO", cobertura: "TODO" }
  - { tipo: estandar,    url: "TODO", cobertura: "TODO" }

areas_criticas:
  permisos_user:  []
  fhs_tocados:    []
  visual_secrets: []
  zonas_ocultas:  []

modos_ejecucion:
  dry-run:
    proposito: "TODO"
    efectos_disco: "ninguno"
    efectos_red: "ninguno"
    salida: "stdout · plan textual"
  sandbox:
    proposito: "TODO"
    aislamiento: "bwrap | tmpfs | worktree"
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_nextjs/"
    efectos_red: "TODO"
    salida: "findings.json en sandbox"
  real:
    proposito: "TODO"
    precondicion: "sandbox del mismo input ha pasado en las últimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_nextjs/<fecha>/"
    efectos_red: "TODO"
    salida: "informe.md + findings.json + propuesta_#N"
gate_promocion:
  regla: "modo N+1 solo si modo N exit 0|1 con plan"
  override: "--override-gate=AUTO_<timestamp ±60s>"

escalada_privilegio:
  comando_template: "${XEK_SUDO:-sudo -A}"
  cuando_aplica: "TODO"

depende_de:
  - { slug: XEK_detecta-stack, modo: sandbox, obligatoria: true, razon: "necesita manifiesto" }
contrato_invocacion:
  modo_subordinado: sandbox
  promocion_real: solo_operador
  consolidacion: "json · schema xek/finding@v1"

aplicabilidad:
  cuando:
    - "manifest.target_tipo == 'repo'"
  prioridad: media
  coste_relativo: 2

migracion_runtime:
  bash:   scripts/xek-nextjs.sh
  python: scripts/xek-nextjs.py
  zsh:    scripts/xek-nextjs.zsh

triggers:
  keywords: ["TODO1", "TODO2", "TODO3"]
  contextos: ["pre-PR"]
  cron: ""
---

# Objetivo

App Router · RSC vs client · next/image · middleware · ISR.

# Estado

**Stub bootstrap v0.0.1** — frontmatter declarativo presente, implementación pendiente. Se completa en Ronda 3 del ciclo dialéctico tras validación de la antítesis sobre la tesis v0.5.

# Pendiente para implementación

- [ ] Rellenar `fuentes_externas` con tools concretas + version_min + licencia SPDX
- [ ] Rellenar `referencias_canonicas` con ≥1 doc_oficial + ≥1 estandar (R4)
- [ ] Rellenar `triggers.keywords` (≥3 · R7)
- [ ] Implementar `scripts/xek-nextjs.sh` con los 3 modos
- [ ] Implementar adaptadores Python y zsh
- [ ] Añadir caso happy + caso falla en sección Verificación
- [ ] Bitácora evolución con entrada por bump

# Bitácora evolución

- **v0.0.1** (2026-05-20) — bootstrap stub.

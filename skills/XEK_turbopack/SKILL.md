---
slug: XEK_turbopack
ambito: Framework
maestria_funcional: revisor
estado: stub
version: 0.6.2
mejoras_ultima_edicion:
  - { v: 0.0.1, fecha: 2026-05-20, cambio: "bootstrap stub · pendiente implementación" }
  - { v: 0.6.1, fecha: 2026-05-22, cambio: "degradado borrador→stub per síntesis Ronda 002 (commit deuda v0.6)" }
  - { v: 0.6.2, fecha: 2026-06-06, cambio: "acotada aplicabilidad: de target_tipo==repo genérico a bundler==turbopack OR Next.js>=15. Opciones evaluadas: A=independiente acotado (elegida) · B=fusión en XEK_nextjs · C=fusión en bundler genérico" }

objetivo: >
  config bundler · cache · trace · módulos no soportados.

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
    efectos_disco: "solo bajo $XDG_RUNTIME_DIR/xek-sandbox/XEK_turbopack/"
    efectos_red: "TODO"
    salida: "findings.json en sandbox"
  real:
    proposito: "TODO"
    precondicion: "sandbox del mismo input ha pasado en las últimas 24h"
    efectos_disco: "cuaderno/artefactos/XEK_turbopack/<fecha>/"
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
    - "manifest.tooling.bundler == 'turbopack' || manifest.frameworks.nombre includes 'nextjs' (version_min >= 15)"
  prioridad: media
  coste_relativo: 2

migracion_runtime:
  bash:   scripts/xek-turbopack.sh
  python: scripts/xek-turbopack.py
  zsh:    scripts/xek-turbopack.zsh

triggers:
  keywords: ["TODO1", "TODO2", "TODO3"]
  contextos: ["pre-PR"]
  cron: ""
---

# Objetivo

config bundler · cache · trace · módulos no soportados.

# Scope · aplicabilidad acotada

Turbopack es el bundler por defecto de Next.js ≥ 15; ya no se configura como bundler
independiente en la mayoría de proyectos. Para evitar solape con `XEK_nextjs` y `XEK_vite`,
esta skill **solo aplica** cuando el manifiesto declara `tooling.bundler == 'turbopack'` o un
framework Next.js ≥ 15. No es un check genérico de repo.

Opciones evaluadas (síntesis del mantenedor, 2026-06-06):
- **A · independiente acotado (elegida)** — mantener la skill, restringir `aplicabilidad.cuando`.
  No destructiva; preserva el caso Turbopack standalone real.
- **B · fusión en `XEK_nextjs`** — descartada: pierde granularidad y reutilización fuera de Next.
- **C · fusión en bundler genérico con `XEK_vite`** — descartada: Turbopack no es Vite; el solape
  es de propósito, no de implementación.

# Estado

**Stub bootstrap v0.0.1** — frontmatter declarativo presente, implementación pendiente. Se completa en Ronda 3 del ciclo dialéctico tras validación de la antítesis sobre la tesis v0.5.

# Pendiente para implementación

- [ ] Rellenar `fuentes_externas` con tools concretas + version_min + licencia SPDX
- [ ] Rellenar `referencias_canonicas` con ≥1 doc_oficial + ≥1 estandar (R4)
- [ ] Rellenar `triggers.keywords` (≥3 · R7)
- [ ] Implementar `scripts/xek-turbopack.sh` con los 3 modos
- [ ] Implementar adaptadores Python y zsh
- [ ] Añadir caso happy + caso falla en sección Verificación
- [ ] Bitácora evolución con entrada por bump

# Bitácora evolución

- **v0.0.1** (2026-05-20) — bootstrap stub.

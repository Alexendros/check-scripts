# Contribuir a XEK

Toda contribución pasa por el **protocolo dialéctico tesis → antítesis →
síntesis** descrito en [`METHODOLOGY.md`](METHODOLOGY.md). Este documento
resume los pasos operativos.

## Antes de empezar

1. Lee [`README.md`](README.md), [`METHODOLOGY.md`](METHODOLOGY.md) y
   [`docs/tesis-v0.5.html`](docs/tesis-v0.5.html).
2. Copia `ROSTER.example.yaml` → `ROSTER.yaml` (este último gitignored) y
   declara las IAs/personas que ocuparán cada rol.
3. Comprueba que el linter pasa: `./skills/XEK_meta-forge/scripts/xek-meta-forge.sh --audit-all --mode=dry-run`.

## Tipos de contribución

### A · Nueva skill XEK

1. Abre un issue con plantilla `new-skill` describiendo: ámbito, cobertura,
   tools, referencias canónicas mínimas.
2. **Rol IA-tesis** crea borrador en `cycles/ronda-<NNN>/tesis-vN.md`:
   - Frontmatter completo (R1).
   - 3 modos `dry-run` / `sandbox` / `real` declarados (R5).
   - `referencias_canonicas` ≥ 1 doc oficial + ≥ 1 estándar (R4).
   - `aplicabilidad` con predicado contra manifiesto (R14).
3. **Rol IA-antítesis** entrega `cycles/ronda-<NNN>/antitesis-vN.md`:
   - Crítica numerada (3-5 puntos) con cita, argumento, alternativa.
   - Plantilla alternativa diferenciada en ≥ 2 ejes.
   - Ejemplo de skill en su plantilla.
4. **Rol IA-síntesis** ejecuta la skill propia `/SINTESIS` y entrega
   `cycles/ronda-<NNN>/sintesis-v(N+1).md` + `diff.md`.
5. **Operador** firma `cycles/ronda-<NNN>/rendicion.md`. La skill se
   promueve a `skills/<slug>/SKILL.md`.

### B · Modificación a skill existente

Misma ruta, partiendo de la versión actual de `skills/<slug>/SKILL.md`.
Bump `version` en el frontmatter y append a `mejoras_ultima_edicion`.

### C · Nueva regla del linter (R17+)

1. Justifica con caso real (skill que la regla habría detectado).
2. Implementa en `skills/XEK_meta-forge/scripts/xek-meta-forge.sh` (bash) y
   adaptadores Python/zsh.
3. Añade test en `tests/linter/rNN.bats` con casos PASS y FAIL.
4. Sigue el ciclo dialéctico A para validar.

## Reglas duras

- Nunca commits directos a `main`. PR + ciclo dialéctico cerrado.
- Nunca menciones nombres de productos AI en el cuerpo de una skill
  (whitelist solo en `referencias_canonicas` y `ROSTER.yaml`).
- Nunca uses verbos condicionales ("debería", "podría", "convendría") en
  cuerpo. Imperativo afirmativo siempre.
- Nunca hardcodees `sudo` en skills `XEK_linux-*` — usa `${XEK_SUDO:-sudo -A}`.
- Nunca añadas dependencias sin actualizar `fuentes_externas` del
  frontmatter.

## CI gates

El workflow `.github/workflows/linter.yml` ejecuta R1-R16 sobre cada PR.
Si falla cualquier regla:

- El PR no se mergea.
- Comentario automático señala la regla, el slug afectado y la línea.

## Estilo

- Markdown: máx 100 columnas en prosa; tablas y código libres.
- Bash: `set -euo pipefail` obligatorio; `shellcheck` clean.
- Python: `ruff` clean (preset `default`); type hints en funciones públicas.
- YAML: indent 2 espacios; sin tabs.
- SemVer estricto. Bump minor por skill nueva o regla nueva; major por
  cambio de invariante doctrinal o sustitución de IA en `ROSTER.yaml`.

## Pregunta · respuesta

¿La idea de mi skill ya existe en otra? — busca en `README.md#skills` y
`docs/tesis-v*.html#matriz`. Si encaja, extiende la existente con bump
minor. Si no, abre un nuevo issue.

¿Puedo proponer una skill que **modifique** el objetivo? — no en este
cluster. XEK es check-only por doctrina. Propón en el cluster `ACT_*` o
`APP_*` (fuera del alcance de este repositorio).

¿Puedo usar mi propia IA fuera de `ROSTER.example.yaml`? — sí. Crea
`ROSTER.yaml` localmente con tu asignación. El cuerpo del repo permanece
agnóstico.

# Brief · Ronda 003a · IA-antítesis

| Campo | Valor |
|---|---|
| Rol asignado | **IA-antítesis (rol 02)** del protocolo dialéctico |
| Cap | USD 5 / mensaje |
| Branch destino | `dialectica/ronda-003a` (esta rama) |
| Convención de entrega | commits a esta rama · NUNCA a `main` |
| Tesis a contrastar | diseño del linter ejecutable `xek-meta-forge.sh` que materializa R1-R18 |

## Cómo entregar (importante · leer antes de empezar)

1. **Operas sobre esta rama (`dialectica/ronda-003a`)**, jamás sobre `main`.
2. **Commitea tu antítesis como archivos nuevos** bajo `cycles/ronda-003a/`:
   - `cycles/ronda-003a/antitesis.md` — cuerpo de la crítica + diseño alternativo
   - `cycles/ronda-003a/r17-implementation.sh` — implementación bash ejecutable de R17
   - `cycles/ronda-003a/r17-helper.py` — helper Python si tu diseño lo requiere
   - `cycles/ronda-003a/workflow-ci-proposed.yml` — propuesta de
     `.github/workflows/linter.yml` v0.6
   - `cycles/ronda-003a/diff-table.md` — tabla diff 6-8 filas
   - `cycles/ronda-003a/pregunta-ronda-3b.md` — una sola pregunta
3. **NO modifiques** archivos fuera de `cycles/ronda-003a/`.
   No toques `skills/`, `docs/`, `README.md`, `.github/workflows/`
   ni nada de `main`.
4. **NO abras PR a main** desde esta rama. El draft PR ya existe
   (#3 cuando esté abierto) y lo gestiona la síntesis.
5. **NO hagas merge ni rebase contra main** desde esta rama.

Cuando hayas commiteado todos los archivos arriba, simplemente **detente**.
La síntesis (rol 03) lee los commits, los procesa, genera
`cycles/ronda-003a/sintesis-v0.7.md` + `diff.md` en otra rama y cierra el
draft PR sin merge.


## Doctrina inviolable (12 invariantes)

check-only · trifásica · agnóstica IA · agnóstica operador (`${XEK_SUDO:-sudo -A}`) ·
agnóstica distro · imperativa · canónica · migrable · append-only ·
componible · aplicable · dialéctica.

Tu output debe respetarlos en su cuerpo. No menciones productos AI fuera de
`referencias_canonicas` o `ROSTER.yaml`.

## Diseño tentativo a contrastar (mi tesis)

1. Un solo script `skills/XEK_meta-forge/scripts/xek-meta-forge.sh`
   en bash que itera todos los `SKILL.md` del repo.
2. Cada regla R1-R18 implementada como función bash `r1()`...`r18()` con exit `0|1`.
3. Output JSON consolidado conforme a
   [`skills/XEK_orquesta/schemas/finding.schema.json`](../../skills/XEK_orquesta/schemas/finding.schema.json).
4. Modos: `dry-run` lista reglas · `sandbox` audita SKILL.md
   aislados en tmpfs · `real` audita árbol entero.
5. R17/R18 (validación de schemas YAML/JSON) en Python invocado desde bash · resto bash puro.
6. Sin instalaciones globales — solo
   `pip install --user pyyaml jsonschema` documentado en preflight.

## Contexto de lectura obligatoria

- [`docs/tesis-v0.5.html`](../../docs/tesis-v0.5.html) — dossier visual canónico
- [`cycles/ronda-001/sintesis-v0.6.md`](../ronda-001/sintesis-v0.6.md) — síntesis previa
- [`cycles/ronda-001/diff.md`](../ronda-001/diff.md) — 16 decisiones trazables
- [`skills/_template/SKILL.md`](../../skills/_template/SKILL.md) — plantilla canónica
- [`skills/XEK_react/SKILL.md`](../../skills/XEK_react/SKILL.md) — ejemplo beta v0.6.0
- [`skills/XEK_sast/SKILL.md`](../../skills/XEK_sast/SKILL.md) — ejemplo beta v0.5.0
- [`skills/XEK_orquesta/schemas/manifest.schema.json`](../../skills/XEK_orquesta/schemas/manifest.schema.json) — `xek/manifest@v2`
- [`skills/XEK_orquesta/schemas/finding.schema.json`](../../skills/XEK_orquesta/schemas/finding.schema.json) — `xek/finding@v1`
- [`ROSTER.example.yaml`](../../ROSTER.example.yaml) — `xek/roster@v2`
- [`METHODOLOGY.md`](../../METHODOLOGY.md) — protocolo dialéctico

## Estructura mínima de `antitesis.md`

```markdown
# Antítesis · Ronda 003a

## 1 · Crítica (3-5 puntos)
<por cada punto: cita literal de la tesis, argumento técnico, alternativa>

## 2 · Diseño alternativo (≥ 2 ejes diferenciados)
<arquitectura propuesta · justificación>

## 3 · Workflow CI propuesto
<referencia a workflow-ci-proposed.yml + razones>

## 4 · Trade-offs
<costes de tu alternativa · qué pierdes>

## 5 · Una pregunta clave para Ronda 3b
<referencia a pregunta-ronda-3b.md>
```

## DoD (autoverificable)

- [ ] Todos los archivos commiteados están bajo `cycles/ronda-003a/`
- [ ] Ningún archivo de `main` modificado
- [ ] R17 ejemplar ejecutable (puede correr con `bash r17-implementation.sh` sin args)
- [ ] Workflow CI propuesto añade yamllint + grep TODO gated por estado + JSON Schema validation
- [ ] grep `"debería\|podría\|convendría"` → 0 hits en tu output
- [ ] Sin nombres de productos AI fuera de `referencias_canonicas` o `ROSTER.yaml`
- [ ] `pip install --user pyyaml jsonschema` documentado · sin instalaciones globales
- [ ] Coste total del trabajo ≤ USD 5

## No ejecutar

NO modificar `main` · NO modificar archivos fuera de `cycles/ronda-003a/` ·
NO abrir PR a `main` · NO merge · NO rebase contra `main` ·
NO instalar globalmente · NO inventar paths/flags · NO SSE legacy.

## Perspectiva

Ingeniero senior de plataforma con sesgo contrarian saludable. El valor del
rol es disentir con argumento técnico. Si todo del diseño tentativo parece
razonable, profundizar en: paralelización, cacheabilidad del linter, ergonomía
del exit code, schema completo del finding emitido, modularidad del script.

# Diff trazable · v0.6 → v0.7

**Generado por**: rol IA-síntesis (rol 03) · skill `/SINTESIS`
**Fecha**: 2026-05-22
**Bump**: v0.6 → v0.7 (semver minor · ronda dialéctica en modo degradado · sin substitución de actor)
**Entrada**: `tesis-v0.6.md` + `antitesis-v0.6.md`

## Tabla campo a campo

| # | Campo / decisión | Valor en tesis v0.6 | Valor en antítesis | **Decisión v0.7** | Razón |
|---|---|---|---|---|---|
| 1 | Estado XEK_detecta-stack | Promover a `beta` con SKILL.md completo + bash ejecutable | Promover solo a `borrador` · linter no existe para verificar gate beta | **MERGE** · `borrador` con SKILL.md completo + bash ejecutable | Antítesis correcta: gate de `beta` exige R1-R14 verificables por linter; promover a beta sin linter es certificación nominal |
| 2 | METHODOLOGY.md self-dialectical | Añadir sección "Modo degradado" en METHODOLOGY.md | Separar en ronda con doble-síntesis o propuesta_#X; no tocar METHODOLOGY.md ahora | **RECHAZADO** · documentar como propuesta_#X en rendicion.md; frontmatter de artefactos usa campo `modo_dialectico` explícito | Modificar METHODOLOGY.md exige doble-síntesis per regla §"Skill que afecta metodología". Usar el mecanismo deficiente para validarlo sería circularidad normativa |
| 3 | Drift 36 borrador→stub | Diferir a Ronda 3b delegada | Aplicar en este commit (operación YAML atómica, coste 0) | **ACEPTADO** · aplicar degradación en commit v0.7 | El compromiso lleva dos rondas sin ejecutarse sin argumento técnico. Diferirlo de nuevo sin penalidad debilita confianza en diff.md |
| 4 | Orden de rondas (linter vs skills) | Implícito: XEK_detecta-stack beta antes de Ronda 3a | Restaurar orden acordado: Ronda 3a linter → XEK_detecta-stack beta → Ronda 3b skills | **ACEPTADO** · el camino a `beta` de XEK_detecta-stack pasa por Ronda 3a | Consistente con §2 de síntesis v0.6 que ya había establecido este orden |
| 5 | Versión XEK_detecta-stack | nueva skill a 0.7.0 | igual | **0.7.0** · primer SKILL.md real (antes era bootstrap stub 0.0.1) | Bump minor: primer contenido real |
| 6 | Versión cluster | v0.6 | v0.7 | **v0.7** · semver minor | `bump-por-ronda` |
| 7 | Número de betas | 3 (sast, react, linux-gpu) | igual | **3** · XEK_detecta-stack queda en `borrador` | Sin nueva beta hasta que linter exista |
| 8 | Número de stubs explícitos | 1 (linux-peripherals) | 37 (1 existente + 36 degradados) | **37** | Degradación de 36 borrador→stub aplicada |
| 9 | Número de borrador | 36 | 1 (solo XEK_detecta-stack nueva) | **2** · XEK_detecta-stack + los que ya eran borrador real (XEK_meta-forge, XEK_orquesta, XEK_sca, etc. que tenían contenido parcial) → en realidad todos pasan a stub salvo los que tienen implementación parcial significativa | Ver nota † |
| 10 | propuesta_#X pendiente | no declarada | propuesta_#1: self-dialectical en METHODOLOGY | **propuesta_#ronda-002-P1** · documentada en rendicion.md | Preserva el insight sin aplicar el cambio prematuramente |

† Nota sobre campo 9: los 36 skills degradados a `stub` son aquellos con
`estado: borrador` y cuerpo TODO. XEK_detecta-stack pasa de `stub/borrador
bootstrap` a `borrador` real con implementación. El resultado neto de
`borrador` es: de 36 → los que ya tenían algún contenido real (no solo TODO).
Inspeccionando el árbol: XEK_meta-forge, XEK_orquesta y XEK_sca tienen
`estado: borrador` con algo de frontmatter parcial pero sin bash completo;
la síntesis los degrada a `stub` igualmente — los que llegan a `borrador`
solo con SKILL.md completo + al menos dry-run funcional.

## Resumen de impacto v0.7

- **+1** SKILL.md borrador real con bash ejecutable completo (XEK_detecta-stack)
- **−36** borrador implícitos → `stub` explícito (deuda de v0.6 saldada)
- **+0** betas (sin linter disponible, no se certifica ninguna nueva beta)
- **+0** cambios en METHODOLOGY.md (propuesta_#P1 separada para ronda futura)
- **Orden de rondas restaurado**: Ronda 3a linter primero; XEK_detecta-stack beta después

## Conflictos no resueltos en esta ronda

Ninguno irreconciliable. C1 y C3 de antítesis aceptadas con argumento. C2
de antítesis aceptada — el cambio de METHODOLOGY queda como propuesta_#P1.

## Cambios en árbol (lista técnica)

1. `skills/XEK_detecta-stack/SKILL.md` — bump 0.0.1 → 0.7.0 · `estado: borrador` · SKILL.md completo
2. 36 skills: campo `estado: borrador` → `estado: stub` + bump version 0.0.1 → 0.6.1
3. `cycles/ronda-002/` — 5 artefactos nuevos (tesis, antítesis, síntesis, diff, rendicion)

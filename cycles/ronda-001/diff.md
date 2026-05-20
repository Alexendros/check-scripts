# Diff trazable · v0.5 → v0.6

**Generado por**: rol IA-síntesis (rol 03) · skill `/SINTESIS`
**Fecha**: 2026-05-21
**Bump**: v0.5 → v0.6 (semver minor · ronda dialéctica cerrada · sin substitución de actor)
**Entrada**: `tesis-v0.5.md` + `antitesis-v0.5.md`

## Tabla campo a campo

| # | Campo / decisión | Valor en tesis v0.5 | Valor en antítesis | **Decisión v0.6** | Razón |
|---|---|---|---|---|---|
| 1 | Catálogo Linux | 15 skills | 11 skills (fusiones audio+bt, gpu+energia) | **14 skills** · fusionar solo `audio+bluetooth` → `linux-peripherals`; mantener `gpu` y `energia` separadas; degradar `linux-escritorio` a `prioridad: baja` | Argumento D-Bus para audio+bt es sólido; gpu (drm, CDI, drivers) y energia (power_supply, thermal, TLP) tocan subsystems distintos pese a solape menor |
| 2 | Total skills | 41 (+ SINTESIS) | 37 implícitos | **40 skills** (+ SINTESIS) | Pérdida neta de 1 slot por fusión Linux audio+bt; resto preservado |
| 3 | Mapeo invariantes-reglas | ausente | `regla_linter` por invariante en `xek/roster@v1` | **ACEPTADO** · schema bumped a `xek/roster@v2` | Desincronía silenciosa entre vocabularios es riesgo verificable; mapeo elimina ambigüedad |
| 4 | Escalada privilegio | `${XEK_SUDO:-sudo -A}` como string | bloque `escalada` con `adapter`, `capabilities_requeridas[]`, `fallback_sin_escalada`, `registrar_en_finding` | **ACEPTADO** · adopta bloque completo; preserva env var como adapter por compatibilidad | Auditable, fallback declarado, traza en JSON; el adapter como env var sigue siendo el default |
| 5 | Niveles de `estado` | `borrador|beta|produccion|descatalogado` | `stub|borrador|beta|estable` con gates por nivel | **MERGE** · 5 niveles: `stub|borrador|beta|produccion|descatalogado` + tabla de gates del linter | Acepta granularidad nueva (`stub` separado de `borrador`); mantiene terminología `produccion` por consistencia con resto del harness |
| 6 | Stubs con `TODO` | 39 archivos | violan R4/R5/R7 | **DEGRADAR** 39 stubs a `estado: stub` (no `borrador`) · linter R4/R7 no aplican a stub | Promoción a `borrador` exige referencias_canonicas reales y triggers reales; ciclos futuros graduales |
| 7 | Linter ejecutable | declarado, no implementado | C5 reclama ausencia · claim factual sobre workflow.yml es erróneo | **PARCIAL ACEPTADO** · `workflow.yml` ya existe (rechazo claim factual); `scripts/xek-meta-forge.sh` ejecutable se escribe en **Ronda 3a antes de Ronda 3b skills** | Distinguir entre documentación (workflow declarado) e implementación (script bash); responde directo a la pregunta final de Devin |
| 8 | Plantilla canónica | bash monolítico libre + 3 secciones dispersas para precondiciones | `checks[]` tipado + `precondiciones_runtime` unificado | **ACEPTADO FULL** · plantilla v0.6 incorpora ambos bloques | Machine-parseable; runner genérico itera checks sin parsear bash por skill |
| 9 | `depende_de` | `razon` libre | añade `campos_esperados[]` que lista campos del manifest consumidos | **ACEPTADO** · `campos_esperados[]` obligatorio en v0.6 | Contrato explícito entre skills del DAG; detecta drift cuando schema del manifest cambia |
| 10 | Consolidación findings | merge por `slug` | merge por `check_id` | **MERGE** · `check_id` primario, `slug` secundario para skills sin checks[] declarados (ej. detecta-stack) | Granularidad por check para skills nuevas; compat hacia atrás para foundation |
| 11 | XEK_react SKILL.md | stub TODO | beta · 5 checks · 5 refs · bash ejecutable | **ACEPTADO FULL** · promueve a `estado: beta` · entra al repo en v0.6 | Implementación de calidad; ahorra 1 skill del lote pendiente Ronda 3b |
| 12 | Rol IA-revisor (rol 02b) | ausente | rol intermedio mecánico antes de síntesis | **ACEPTADO OPT-IN** · sin bump major · activable vía ROSTER `revisor:` · default `skip` | Mejora separación validación/decisión; opt-in preserva compat con rondas presupuesto ajustado; no es substitución de actor existente |
| 13 | Esquemas schemas/ | manifest@v2 + finding@v1 | sin cambios | **MERGE** · bump `roster@v1` → `roster@v2` (campo regla_linter); finding y manifest sin cambios | Solo el roster necesita schema bump; otros estables |
| 14 | Reglas linter activas | R1-R16 | propone gates por nivel `estado` | **AÑADIR R17-R18** en v0.6: R17 valida `aplicabilidad` evaluable contra schema manifest; R18 valida `depende_de.campos_esperados` existen en schema | Materializa formalmente el contrato del DAG y la filtración por aplicabilidad |
| 15 | Workflow CI | R1, R2, R3, R5, R6, R7, R15, R16 + shellcheck | sugerido `yamllint` + grep TODO gateado por estado | **AÑADIR** en Ronda 3a: yamllint, grep TODO gated por estado, validación schema JSON | Implementable sin bloquear merge actual; añade en Ronda 3a junto con `xek-meta-forge.sh` ejecutable |
| 16 | Linux-audio + Linux-bluetooth | 2 skills separadas | 1 skill `linux-peripherals` | **FUSIÓN** · nueva slug `XEK_linux-peripherals` cubre PipeWire/PulseAudio/ALSA + BlueZ via bus D-Bus único | Argumento técnico de Devin correcto: ambas leen `org.freedesktop.*` paths; un solo binding D-Bus reduce mantenimiento |

## Resumen de impacto v0.6

- **−2** skills Linux por fusión `audio+bluetooth` (15 → 14); **+0** otros ámbitos
- **+2** reglas linter (R17, R18)
- **+1** rol opcional (`IA-revisor`)
- **+1** versión schema (`xek/roster@v2`)
- **−39** stubs en estado `borrador` (degradados a `stub`)
- **+1** SKILL.md `beta` (XEK_react absorbido de antítesis)
- Cluster final: **40 skills** (+ SINTESIS) · **8 ámbitos** · **18 reglas linter** · **3-4 roles** (revisor opt-in)

## Conflictos no resueltos en esta ronda

Ninguno irreconciliable. Cuatro propuestas aceptadas full, dos parciales con
argumento, dos en merge intermedio. Sin disenso que requiera subronda ni
doble síntesis.

## Próximos pasos (Ronda 2 → Ronda 3)

1. **Ronda 2** (síntesis local, coste 0): actualizar plantilla canónica
   `_template/SKILL.md` con checks[] + precondiciones_runtime; promover
   XEK_react a beta; bump roster schema; degradar 39 stubs a estado `stub`;
   actualizar dossier visual a v0.6.

2. **Ronda 3a** (delegada · cap USD 10): escribir `xek-meta-forge.sh`
   ejecutable con R1-R18; expandir workflow CI (yamllint + grep TODO gated +
   schema validation).

3. **Ronda 3b** (delegada · cap USD 5/msg · 5-8 msg): promover 38 stubs
   restantes a estado `borrador` (referencias reales + triggers reales +
   dry-run funcional). Sin escribir sandbox/real aún.

4. **Ronda 4** (auditoría local, coste 0): ejecutar linter sobre 40 skills;
   firmar rendiciones.

5. **Ronda 5** (delegada): escribir sandbox + real para 8-10 skills críticas
   (sast, sca, integridad, datos-criticos, repo-higiene, despliegue, react,
   linux-peripherals).

# Síntesis v0.6 · Ronda 001

**Rol**: IA-síntesis (rol 03)
**Skill ejecutada**: `/SINTESIS`
**Fecha**: 2026-05-21
**Bump**: v0.5 → v0.6 · semver minor · ronda cerrada · sin substitución de actor
**Entrada**: `tesis-v0.5.md` + `antitesis-v0.5.md`
**Salida hermana**: [`diff.md`](./diff.md) (tabla campo a campo)

---

## 1 · Decisiones aplicadas a v0.6

### 1.1 · Catálogo · 40 skills (−1 por fusión)

| Cambio | Detalle |
|---|---|
| **Fusión** | `XEK_linux-audio` + `XEK_linux-bluetooth` → `XEK_linux-peripherals` (un solo recorrido bus D-Bus) |
| **Degradación** | `XEK_linux-escritorio` baja `prioridad: alta` → `baja` (solo se ejecuta si target_tipo == host AND desktop_env != none) |
| **Mantenido** | `XEK_linux-gpu` y `XEK_linux-energia` se mantienen separadas — subsystems `/sys/class/drm` vs `/sys/class/power_supply` son distintos pese a solape menor en thermal_zone |
| **Promoción** | `XEK_react` pasa de `stub` a `beta` con SKILL.md aportado por antítesis (5 checks declarativos, 5 refs canónicas, bash ejecutable) |
| **Degradación** | Los 38 stubs restantes pasan de `borrador` aparente a `estado: stub` explícito (no aplican R4/R7 hasta promoción) |

**Total v0.6**: 40 skills + SINTESIS · 8 ámbitos.

### 1.2 · Estados con gates incrementales (5 niveles)

| Estado | Requisitos del frontmatter | Reglas linter activas |
|---|---|---|
| `stub` | slug + ambito + objetivo (≤200) + version + estado declarado | R1 (parse YAML), R6 (objetivo length) |
| `borrador` | + `referencias_canonicas` (≥1 doc_oficial + ≥1 estandar) + `triggers.keywords` (≥3) + `modos_ejecucion.dry-run` funcional | R1-R7, R14 |
| `beta` | + `modos_ejecucion.sandbox` funcional + smoke test que pase + `checks[]` declarados | R1-R14 |
| `produccion` | + `modos_ejecucion.real` funcional + uso en ≥ 1 perfil en producción del operador | R1-R18 |
| `descatalogado` | + fecha de descatalogación + razón + skill sustituta si aplica | R1, R6 |

### 1.3 · Reglas linter R17-R18 nuevas

| ID | Regla |
|---|---|
| **R17** | `aplicabilidad.cuando[]` es evaluable contra `xek/manifest@v2.schema.json` — cada predicado parsea como expresión sobre paths del schema |
| **R18** | `depende_de[].campos_esperados[]` existen en `xek/manifest@v2.schema.json` — detecta drift cuando el schema del manifest evoluciona |

Total reglas v0.6: **18** (R1-R18).

### 1.4 · Manifiesto v2 sin cambios · roster bump v1 → v2

```yaml
# xek/roster@v2 · cambios respecto a v1
roles:
  tesis:
    invariantes_obligatorios:
      - { nombre: check_only, regla_linter: R1 }       # NUEVO · mapeo verificable
      - { nombre: imperativa, regla_linter: R2 }
      - { nombre: canonica,   regla_linter: R4 }
  antitesis:
    invariantes_obligatorios:
      - { nombre: rol_unico_por_ronda, regla_linter: null }   # no implementable como regla del linter por SKILL
  sintesis:
    invariantes_obligatorios:
      - { nombre: diff_trazable, regla_linter: null }

# NUEVO · rol opt-in
revisor:                          # opcional · activar solo si se declara
  agente_id: ""                   # vacío == skip
  capacidades:
    - linter_execution
    - factual_conflict_detection
  coste_max_por_msg: USD 2
  contexto_pre:
    - "cycles/ronda-<NNN>/tesis-vN.md"
    - "cycles/ronda-<NNN>/antitesis-vN.md"
    - "skills/XEK_meta-forge/SKILL.md"
```

### 1.5 · Bloque `escalada` reemplaza `escalada_privilegio` simple

```yaml
escalada:
  adapter: "${XEK_SUDO:-sudo -A}"                 # compat hacia atrás
  capabilities_requeridas:
    - { cap: "CAP_DAC_READ_SEARCH", razon: "find / -perm 4000" }
  fallback_sin_escalada: "skip checks privilegiados · reportar como skipped"
  registrar_en_finding: true                       # inyecta campo escalada_usada en finding JSON
```

### 1.6 · Plantilla v0.6 incorpora dos cambios estructurales

1. **`checks[]` tipado en frontmatter** — array de objetos con `id`, `descripcion`, `command_template`, `expected_exit`, `severity_default`, `cwe`, `owasp`, `solo_modo`.
2. **`precondiciones_runtime` unificado** — bloque con `binarios`, `capabilities`, `paths_lectura`, `paths_escritura`, `conexiones`. Sustituye 3 secciones dispersas previas (`fuentes_externas` + `escalada_privilegio` + `areas_criticas.permisos_user`).

Estructura cuerpo markdown sin cambios (8 secciones + nueva sección "Preflight" auto-generable desde `precondiciones_runtime`).

---

## 2 · Pregunta de Ronda 3 respondida

> *¿El linter `xek-meta-forge.sh` ejecutable y el CI expandido se implementan ANTES de las 39 skills (Ronda 3a infra · Ronda 3b skills) o DESPUÉS?*

**Decisión**: **Ronda 3a antes de Ronda 3b.** Razones:

1. Escribir 39 skills sin gate automatizado significa que las primeras N
   skills probablemente violan reglas que descubriremos cuando exista el
   linter. Costoso de auditar a posteriori.
2. El workflow CI ya existe declarativamente (rechazo claim factual de
   antítesis); solo falta el ejecutable `xek-meta-forge.sh` que el workflow
   invoca. Producirlo es 1 mensaje delegado contenido.
3. Permite que cada skill nueva pase R1-R18 al merge, evitando el efecto
   "deuda monolítica" que correctamente señala la antítesis en C4.

---

## 3 · Pendientes para promover v0.6 a producción

### Ronda 2 (síntesis local · coste 0)

- [ ] Actualizar `skills/_template/SKILL.md` con plantilla v0.6 (checks[] + precondiciones_runtime)
- [ ] Aplicar SKILL.md de XEK_react aportado por antítesis a `skills/XEK_react/SKILL.md` con estado `beta`
- [ ] Fusionar `XEK_linux-audio` + `XEK_linux-bluetooth` en nueva `XEK_linux-peripherals`
- [ ] Bumpear `ROSTER.example.yaml` a `xek/roster@v2` con `regla_linter` y rol `revisor` opt-in
- [ ] Bumpear todos los SKILL.md a `version: 0.6.0` + entrada en `mejoras_ultima_edicion`
- [ ] Degradar 38 stubs a `estado: stub` explícito (eran `borrador` implícito)
- [ ] Actualizar dossier visual a `docs/tesis-v0.6.html`
- [ ] Actualizar `README.md` con 40 skills

### Ronda 3a (delegada · cap USD 10 · 1-2 mensajes)

- [ ] Escribir `skills/XEK_meta-forge/scripts/xek-meta-forge.sh` con R1-R18
- [ ] Expandir `.github/workflows/linter.yml` con yamllint + grep TODO gated por estado + schema validation
- [ ] Probar el linter contra los 40 SKILL.md actuales · esperado: 38 stubs PASS R1+R6, 2 betas PASS R1-R14

### Ronda 3b (delegada · cap USD 5/msg · 5-8 mensajes)

- [ ] Promover los 38 stubs a `estado: borrador` con referencias canónicas reales + triggers reales + dry-run funcional
- [ ] Verificación end-to-end (sin sandbox/real aún)

### Ronda 4 (auditoría local · coste 0)

- [ ] Ejecutar linter completo sobre 40 skills
- [ ] Operador firma `rendicion.md` de la Ronda 001 (ESTA ronda) y de las subsiguientes que cierren

### Ronda 5 (delegada)

- [ ] Implementar sandbox + real para 8-10 skills críticas

---

## 4 · Verificación doctrinal (auto-check)

| Invariante | Estado en v0.6 |
|---|---|
| check-only | ✓ ningún cambio modifica el target |
| trifásica | ✓ 3 modos preservados |
| agnóstica IA | ✓ síntesis no nombra productos en cuerpo (este documento) |
| agnóstica operador | ✓ `escalada.adapter: ${XEK_SUDO:-sudo -A}` preservado |
| agnóstica distro | ✓ `host_huellas` preservado |
| imperativa | ✓ verbos afirmativos · 0 hits de condicionales en este doc |
| canónica | n/a · doc síntesis (no es SKILL.md) |
| migrable | ✓ pendiente de aplicar en SKILL.md actualizados |
| append-only | ✓ `mejoras_ultima_edicion` se actualizará en Ronda 2 |
| componible | ✓ `depende_de.campos_esperados[]` refuerza esta invariante |
| aplicable | ✓ R17 nueva la materializa |
| dialéctica | ✓ esta ronda ES la dialéctica funcionando |

## 5 · Firma de la síntesis

**Cierre**: Ronda 001 lista para `rendicion.md` del operador. Sin disenso
irreconciliable detectado. Una propuesta opt-in (rol IA-revisor), seis
aceptadas full o en merge, una rechazada parcialmente con argumento.

Promoción a v0.6 requiere firma del operador en
[`rendicion.md`](./rendicion.md).

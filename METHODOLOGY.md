# Metodología dialéctica IA · XEK

Protocolo normativo para colaboración multi-IA en el repositorio. La parte
normativa **nunca** nombra productos concretos: usa los **roles**
`IA-tesis` · `IA-antítesis` · `IA-síntesis`. La asignación a IAs reales vive
en [`ROSTER.yaml`](ROSTER.example.yaml) (no versionado).

## Premisa

Una sola IA acumula sesgos: confirma sus propias premisas, evita autocrítica
estructural, converge a soluciones promedio. El protocolo dialéctico fuerza
**desacuerdo argumentado** entre actores independientes y produce trazas que
un revisor humano puede auditar.

## Ciclo

```
    [IA-tesis] ──artefacto + bitácora──▶ [IA-antítesis] ──crítica + alternativa──▶ [IA-síntesis] ──v(N+1) + diff──▶ [operador]
                                                                                                                          │
                                                                              ┌───── ciclo se repite ◀─────────────────────┘
                                                                              │
                                                                              ▼
                                                                       convergencia o abort
```

## Roles · contrato

### IA-tesis · rol 01

- **Optimiza por**: coherencia interna, respeto a doctrina, completitud.
- **Entrega**: artefacto v(N) en `cycles/ronda-<NNN>/tesis-vN.md` con
  frontmatter completo + bitácora de decisiones de diseño.
- **Prohibido**: auto-crítica que paralice publicación. La crítica corresponde
  a IA-antítesis.

### IA-antítesis · rol 02

- **Optimiza por**: hallar fallos, diferenciarse argumentadamente.
- **Entrega**: `cycles/ronda-<NNN>/antitesis-vN.md` con:
  1. Crítica numerada (3-5 puntos) — cita corta, argumento técnico,
     alternativa propuesta.
  2. Plantilla alternativa diferenciada en ≥ 2 ejes estructurales.
  3. Diff razonado contra la tesis.
- **Prohibido**: complacer · clonar la tesis · cambios cosméticos · cambiar
  de rol durante la ronda.

### IA-síntesis · rol 03

- **Optimiza por**: convergencia trazable.
- **Entrega**: `cycles/ronda-<NNN>/sintesis-v(N+1).md` + `diff.md` con tabla
  "campo / valor en tesis / valor en antítesis / decisión final / razón".
- **Ejecuta**: skill propia [`skills/SINTESIS/SKILL.md`](skills/SINTESIS/SKILL.md)
  que define el procedimiento exacto de merge.
- **Prohibido**: elegir lado entero sin justificar conflictos.

### Operador · rol humano

- **Optimiza por**: aprobación con criterio humano final.
- **Entrega**: firma en `cycles/ronda-<NNN>/rendicion.md` con
  - decisión (`accept` / `request-changes` / `abort`),
  - notas para futuras rondas,
  - timestamp ISO-8601.
- **Prohibido**: delegar la aprobación a una IA.

## Reglas del protocolo

| Regla | Significado |
|---|---|
| **rol-único-por-ronda** | Misma IA no repite rol consecutivo. Evita auto-confirmación. |
| **bump-por-ronda** | Cada ciclo cerrado incrementa semver minor. Trazabilidad obligatoria. |
| **cap-coste-declarado** | Cada rol declara `coste_max_por_msg` en `ROSTER.yaml`. Presupuesto auditable. |
| **abort-tres-rondas** | 3 rondas sin convergencia ⇒ operador decide o se aborta. Evita deriva. |
| **substitución-bump-major** | Cambiar la IA asignada a un rol exige bump major. Cambio de actor cambia resultado. |
| **roster-separado** | `ROSTER.yaml` vive separado del cuerpo. El cuerpo permanece agnóstico. |
| **diff-trazable** | Toda síntesis adjunta tabla "qué cambió y por qué". Sin esto no se promueve. |

## Estructura por ronda

```
cycles/
└── ronda-<NNN>/
    ├── tesis-vN.md
    ├── antitesis-vN.md
    ├── sintesis-v(N+1).md
    ├── diff.md
    ├── rendicion.md             ← operador firma aquí
    └── coste.csv                ← USD por mensaje y total · auditable
```

## Casos especiales

### Empate IA-tesis e IA-antítesis

Si la antítesis converge en ≥ 80 % con la tesis (poco diferencial), la
síntesis abre una **subronda** y exige a una segunda IA-antítesis (rol único
por ronda no aplica entre subrondas) que arranque desde la antítesis previa.

### Disenso irreconciliable

Si la síntesis no puede integrar dos opciones que son mutuamente
excluyentes:

1. La síntesis emite **dos** propuestas `sintesis-A.md` y `sintesis-B.md`.
2. El operador decide o abre una nueva ronda con instrucciones específicas.

### Skill que afecta a la metodología misma

Cambios en `METHODOLOGY.md` o en `skills/SINTESIS/` exigen **doble síntesis**:
una IA-síntesis distinta valida la propuesta de la primera antes de
promover. Bumpea major.

## Anexo · ejemplo de asignación

Ver [`ROSTER.example.yaml`](ROSTER.example.yaml). Copia a `ROSTER.yaml` y
ajusta.

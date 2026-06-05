# `cycles/` · artefactos de rondas dialécticas

Cada ronda del protocolo dialéctico (tesis → antítesis → síntesis → rendición) deja sus
artefactos bajo `cycles/ronda-<NNN>[sufijo]/`. Es el **registro auditable** de cómo evolucionó
el cluster, no un log de trabajo desechable. Protocolo normativo en
[`../METHODOLOGY.md`](../METHODOLOGY.md).

## Estado actual

| Ronda | Bump | Estado | Notas |
|---|---|---|---|
| `ronda-001` | v0.5 → v0.6 | **cerrada** | operador firmó `rendicion.md` (accept) |
| `ronda-002` | v0.6 → v0.7 | **cerrada** | accept con nota de modo auto-dialéctico degradado |
| `ronda-003a` | v0.7 → v0.8 (en curso) | **abierta** | `.waiting-for-antitesis` · brief en `BRIEF.md` |

La versión vigente del árbol es **v0.7.0**. El tag git `v0.7.0` se creará al cerrar `ronda-003a`.

## Convención de nombres

- `ronda-<NNN>` — ronda completa y numerada (`001`, `002`, …).
- Sufijo de letra (`003a`) — subronda o variante del mismo número cuando una ronda se reabre
  o se bifurca (p. ej. disenso irreconciliable, segunda antítesis).
- Marcador `.waiting-for-<rol>` — ronda abierta esperando la entrega de ese rol.

## Artefactos esperados por ronda

```
ronda-<NNN>/
├── tesis-vN.md          ← propuesta (IA-tesis)
├── antitesis-vN.md      ← crítica + alternativa (IA-antítesis)
├── sintesis-v(N+1).md   ← integración + bump (IA-síntesis)
├── diff.md              ← tabla "qué cambió y por qué" (obligatoria para promover)
├── rendicion.md         ← firma del operador (accept / request-changes / abort)
└── coste.csv            ← USD por mensaje y total (cuando aplica)
```

No todas las rondas materializan todos los artefactos (p. ej. rondas locales sin coste omiten
`coste.csv`). El mínimo para cerrar es `sintesis` + `diff` + `rendicion`.

## Política de retención

- **Rondas cerradas = histórico inmutable, append-only** (coherente con la invariante #9). No
  se editan ni se borran; quedan como traza auditable permanente en `main`.
- **Rondas abiertas** llevan su marcador `.waiting-for-*` hasta cerrarse.
- El crecimiento es lineal y acotado (≈ 5 artefactos de texto por ronda); no requiere archivado
  externo. Si el volumen lo exigiera, se comprimirían las rondas más antiguas en un adjunto de
  release, conservando en `main` solo las N rondas recientes — decisión a tomar por el operador,
  no automática.

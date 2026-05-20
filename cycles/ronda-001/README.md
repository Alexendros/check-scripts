# Ronda 001 · primera iteración dialéctica

**Estado**: pendiente disparo a rol IA-antítesis.

## Cronología prevista

| Fase | Rol | Artefacto | Estado |
|---|---|---|---|
| 1 | IA-tesis | `tesis-v0.5.md` ↔ `docs/tesis-v0.5.html` | ✓ disponible en `docs/` |
| 2 | IA-antítesis | `antitesis-v0.5.md` | pendiente |
| 3 | IA-síntesis | `sintesis-v0.6.md` + `diff.md` | pendiente |
| 4 | Operador | `rendicion.md` | pendiente |

## Cómo lanzar

1. Copia `ROSTER.example.yaml` → `ROSTER.yaml` y declara las IAs.
2. Pasa el brief del rol IA-antítesis (ver `docs/tesis-v0.5.html` § 12).
3. Cuando la antítesis devuelva, ejecuta `skills/SINTESIS/SKILL.md` con
   la IA-síntesis declarada.
4. Operador firma `rendicion.md`.

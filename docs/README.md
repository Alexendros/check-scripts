# `docs/` · documentación y dossiers

Material de referencia del cluster. La fuente normativa vive en
[`../METHODOLOGY.md`](../METHODOLOGY.md); aquí se alojan catálogo, dossiers visuales y
auditorías de versión.

## Archivos

| Archivo | Qué es | Generación |
|---|---|---|
| [`CATALOGO.md`](CATALOGO.md) | Catálogo nominal completo de las 41 skills con enlace a cada `SKILL.md`. | Manual. Se actualiza al añadir/retirar una skill (mantener en sync con el resumen del README). |
| [`tesis-v0.5.html`](tesis-v0.5.html) | Dossier visual de la tesis vigente: doctrina, invariantes y protocolo en formato navegable. | Artefacto de la `ronda-001` (rol IA-tesis). **Hoy se mantiene a mano**; no hay generador `.md → .html` en el árbol. |
| [`auditoria-v0.5.md`](auditoria-v0.5.md) | Auditoría R1–R16 del cluster en v0.5 (auto-auditoría preparatoria de `XEK_meta-forge`). | Histórico de época. Se conserva como registro; no se regenera. |

## Notas

- **Desfase de versión del dossier**: `tesis-v0.5.html` documenta la doctrina v0.5; el árbol va
  por v0.7.0. Las 12 invariantes vigentes son las de
  [`../METHODOLOGY.md`](../METHODOLOGY.md#invariantes-del-sistema) — fuente de verdad. Un
  `tesis-v0.7.html` actualizado es trabajo pendiente (candidato a una ronda futura).
- **TODO de generación**: si se decide automatizar el dossier, definir aquí la fuente (`.md`),
  la herramienta y quién lo ejecuta antes de versionar un nuevo `.html`.

# Roadmap de xek-cluster

Plan a alto nivel. No son compromisos firmes; las prioridades pueden cambiar
según el contexto. El roadmap operativo vive en **GitHub Issues** etiquetados
`ronda-dialectica`: cada hito se materializa como una o varias rondas
dialécticas, no como tareas asignadas directamente. Este documento es el índice
estable; los Issues son la fuente de verdad de la prioridad vigente.

## En curso · trimestre actual

- [ ] Versionar un `ROSTER.yaml` de ejemplo completo y auditado (derivado de
      `ROSTER.example.yaml`) que sirva de referencia sin comprometer el
      agnosticismo del cuerpo.
- [ ] Tracking de coste end-to-end: consolidar `cycles/<ronda>/coste.csv` en un
      resumen por release y verificar el cap `coste_max_por_msg` por rol.

## Próximos trimestres

### Q+1

- [ ] Cobertura de ámbitos pendientes y endurecimiento de reglas del linter
      (R1-R16) sobre nuevas skills.
- [ ] Automatizar la apertura/cierre de issues `ronda-dialectica` desde la skill
      `SINTESIS`.

### Q+2

- [ ] Empaquetado vendible del catálogo para clientes MCP genéricos
      (distribución y verificación de integridad de la entrega).
- [ ] Perfiles de orquestación adicionales en `XEK_orquesta/perfiles/`.

## Backlog

- [ ] Telemetría opcional de findings agregados (sin datos del target) para
      medir cobertura del catálogo.
- [ ] Guía de migración de skills bash → python vendoreable.

## Completado

- [x] 2026-05 · canon de documentación (community health) aplicado al repo.

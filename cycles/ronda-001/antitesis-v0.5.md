# Antítesis v0.5 · Ronda 001

**Rol**: IA-antítesis (rol 02)
**Fecha**: 2026-05-20
**Tesis evaluada**: `docs/tesis-v0.5.html` + corpus del repo @ commit b8e6965
**Coste reportado**: ≤ USD 5

## Resumen ejecutivo

Crítica argumentada en 5 puntos + plantilla alternativa diferenciada en 2 ejes
(checks[] tipado + precondiciones_runtime unificado) + SKILL.md alternativo
para `XEK_react` con 5 checks declarativos y bash ejecutable + propuesta de
rol 4º (`IA-revisor`) opcional + tabla diff 10 filas + pregunta de Ronda 3.

## 5 críticas

1. **C1** · 15 skills Linux es saturación con acoplamiento oculto entre
   `linux-audio`, `linux-bluetooth` (D-Bus compartido), `linux-energia`,
   `linux-gpu` (/sys overlap thermal). Propuesta: fusionar a 11 skills.

2. **C2** · `ROSTER.yaml` separado vs reglas R1-R16 genera desincronía
   silenciosa. Propuesta: añadir `regla_linter` por invariante.

3. **C3** · `${XEK_SUDO}` env var es inauditable. Propuesta: bloque `escalada`
   con `capabilities_requeridas[]` + `registrar_en_finding: true`.

4. **C4** · 39 stubs con TODO violan R4/R5/R7 de facto. Propuesta: 4 niveles
   `stub|borrador|beta|estable` con gates incrementales del linter.

5. **C5** · Workflow CI inexistente (claim factualmente erróneo: `linter.yml`
   sí existe). Punto sustantivo válido: `xek-meta-forge.sh` ejecutable no
   existe, debe escribirse antes de Ronda 3b.

## Plantilla alternativa

Diferenciada en 2 ejes:

- **Eje 1**: `checks[]` tipado en frontmatter (id, command_template, severity,
  cwe, owasp, solo_modo) en lugar de bash monolítico libre.
- **Eje 2**: `precondiciones_runtime` unificado (binarios, capabilities,
  paths_lectura, paths_escritura, conexiones) en lugar de 3 secciones dispersas.

## SKILL.md alternativo entregado

`XEK_react` v0.5.0 · estado: beta · 5 checks declarativos · 5 referencias
canónicas (≥1 OWASP A03 + ≥1 CWE-79 + ≥1 WCAG 2.2 + react.dev oficial) ·
bash ejecutable con preflight + 3 modos + emisión JSON conforme a
`xek/finding@v1`.

## Diseño alternativo metodología

Propuesta de **rol 4º `IA-revisor`** entre antítesis y síntesis. Ejecuta
linter mecánico sobre ambos documentos; emite gate PASS/FAIL por regla;
no decide merges. Coste +USD 1-3 por ronda. Compatible con `revisor: skip`
en ROSTER para presupuesto ajustado.

## Pregunta · clave para Ronda 3

> ¿El linter `xek-meta-forge.sh` ejecutable y el CI expandido se implementan
> ANTES de las 39 skills (Ronda 3a infra · Ronda 3b skills) o DESPUÉS
> (aceptando validación manual durante escritura)?

## Coste y forma

Cap respetado · sin clonar disco · sin instalar tools · sin nombres AI fuera
de referencias canónicas o ROSTER · imperativa afirmativa · 8/8 condicionales
auditados (0 hits en grep `debería|podría|convendría`).

## Documento completo

El cuerpo completo de la antítesis (con SKILL.md XEK_react inline + tabla
diff de 10 filas) vive en el mensaje original que la IA-antítesis devolvió.
Esta versión es resumen para indexación. Para reconstrucción exacta consultar
[chat-log de Ronda 001 archivado en el cuaderno del operador].

# Auditoría `XEK_meta-forge` · cluster v0.5

**Fecha**: 2026-05-20T22:40+02:00 (Europe/Madrid)
**Versión auditada**: tesis v0.5 (41 skills · 8 ámbitos · 12 perfiles)
**Auditor**: rol `IA-tesis` (auto-auditoría preparatoria antes de ronda dialéctica · trazable y substituible)
**Reglas aplicadas**: R1-R16

---

## Resumen ejecutivo

- **PASS conceptual**: 41 / 41 slugs cumplen la doctrina declarativa (frontmatter requerido + invariantes).
- **WARN**: 3 skills tienen aplicabilidad muy permisiva que puede colisionar con perfiles host (`fs`, `secretos`, `seguridad`).
- **HOLD**: el linter ejecutable aún no existe físicamente — esta auditoría es conceptual, basada en la especificación.
- **Pendiente repo**: artefactos de skill (`SKILL.md` por cada slug) deben generarse antes de push. Se delega bootstrap a Ronda 3.

---

## Matriz PASS/FAIL · 41 slugs × 16 reglas

Convención: ✓ PASS conceptual · ⚠ requiere aclaración en la skill concreta · — no aplica.

### Foundation (3)

| slug | R1 | R2 | R3 | R4 | R5 | R6 | R7 | R8 | R9 | R10 | R11 | R12 | R13 | R14 | R15 | R16 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `XEK_meta-forge` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | — | ✓ | ✓ | ✓ | — | — |
| `XEK_detecta-stack` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | — | ✓ | — | ✓ | ✓ | ✓ | — | — |
| `XEK_orquesta` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | — | ✓ | — | ✓ | ✓ | ✓ | — | — |

### Seguridad código (6)

| slug | doctrina | composición | aplicabilidad | notas |
|---|---|---|---|---|
| `XEK_sast` | ✓ | depende_de: detecta-stack | repo + app-en-vivo | tools agnósticas (semgrep/codeql) |
| `XEK_sca` | ✓ | depende_de: detecta-stack | repo | lockfile presente |
| `XEK_dast` | ✓ | depende_de: detecta-stack | app-en-vivo | exige URL viva |
| `XEK_iac` | ✓ | depende_de: detecta-stack | repo con docker/compose/tf | compose explícito |
| `XEK_integridad` | ✓ | — | repo + host | SLSA cobertura |
| `XEK_datos-criticos` | ✓ | — | repo + host | allowlist YAML requerido |

### Web genérico (4) · Framework (6) · Compliance (3) · Data (2) · Repo/Deploy (2)

Todas cumplen R1-R14. R11 (depende_de XEK_detecta-stack) aplicado a Web/Framework/Compliance. Atención específica:

- ⚠ **`XEK_marca`** colisiona con `XEK_compliance-licencias` en cobertura SPDX. Resolver en Ronda 1: ¿`marca` solo branding visible (NOTICE, watermark) y `compliance-licencias` solo backing legal de deps?
- ⚠ **`XEK_db-sql` y `XEK_db-nosql`** comparten predicado de aplicabilidad débil. Reforzar: aplicabilidad debe leer `manifest.data_layer.sql != []` (o `.nosql`).

### Linux/Host (15)

| slug | R15 (`target_tipo=='host'`) | R16 (`${XEK_SUDO}`) | aplicabilidad refinada |
|---|---|---|---|
| `XEK_linux-fs` | ✓ | ✓ (lectura privilegiada para `find /`) | siempre |
| `XEK_linux-secretos` | ✓ | parcial (solo lecturas user, no privilegiadas) | siempre |
| `XEK_linux-paquetes` | ✓ | parcial | `host_huellas.paquete_sys != []` |
| `XEK_linux-actualizaciones` | ✓ | parcial | `host_huellas.paquete_sys != []` |
| `XEK_linux-systemd` | ✓ | ✓ | `host_huellas.init == "systemd"` |
| `XEK_linux-seguridad` | ✓ | ✓ | siempre |
| `XEK_linux-red` | ✓ | ✓ (firewall lectura) | siempre |
| `XEK_linux-vpn` | ✓ | ✓ | `host_huellas.vpn_runtime != []` |
| `XEK_linux-gpu` | ✓ | parcial (nvidia-smi sin root) | `host_huellas.gpu_vendor != "none"` |
| `XEK_linux-audio` | ✓ | — (no escalada) | `host_huellas.audio_server != "none"` |
| `XEK_linux-bluetooth` | ✓ | parcial | `host_huellas.bluetooth == "bluez"` |
| `XEK_linux-energia` | ✓ | parcial | `host_huellas.rol contains "workstation"` |
| `XEK_linux-contenedores` | ✓ | parcial (rootless preferido) | `host_huellas.container_engines != []` |
| `XEK_linux-escritorio` | ✓ | — | `host_huellas.desktop_env != "none"` |
| `XEK_linux-backup` | ✓ | parcial (restic cache user) | siempre |

---

## Reglas con findings

### R3 · vocabulario agnóstico
- **PASS** cuerpo principal de la tesis (`xek-tesis-v0.5.html`): grep de "claude/devin/anthropic/cognition" devuelve 0 hits en `<main>` salvo bloque <code>referencias_canonicas</code> de ejemplo.
- **WARN** brief Ronda 1 menciona "ROSTER.yaml" sin nombrar IAs — correcto.

### R2 · tono imperativo
- **PASS** corpus revisado; 0 hits de "debería|podría|convendría".

### R4 · referencias canónicas
- **PASS conceptual** · cada slug debe declarar ≥1 doc_oficial + ≥1 estandar. En SKILL.md por escribir en Ronda 3. Ejemplos canónicos asignados:
  - `XEK_sast` → semgrep.dev/docs (doc_oficial) + OWASP ASVS 4.0 (estandar)
  - `XEK_a11y-web` → axe-core docs + WCAG 2.2 W3C
  - `XEK_compliance-rgpd` → AEPD guías + RGPD EUR-Lex 2016/679
  - `XEK_linux-fs` → util-linux man + CIS Benchmarks Linux
  - `XEK_linux-gpu` → CDI Spec 0.7 + NVIDIA Container Toolkit docs
  - ... (resto se asignará 1-a-1 en bootstrap)

### R12 · output JSON
- **PASS conceptual** · todas las skills declaran emit `xek/finding@v1`. Schema concreto vive en `XEK_orquesta/schemas/finding.schema.json`.

### R13 · DAG sin ciclos
- **PASS** · perfiles topológicos verificados a mano. `web-nextjs-prod` y `host-workstation` son los más largos (16 y 15 nodos) — ningún ciclo.

### R14 · aplicabilidad declarada
- **PASS conceptual** — predicate concreto por slug pendiente de SKILL.md.

---

## Pendientes para Ronda 3 (bootstrap implementación)

1. Escribir `skills/<slug>/SKILL.md` × 41 con frontmatter completo + secciones contractuales (objetivo · cuándo activar · uso · referencia bash · referencias_canonicas).
2. Crear `XEK_meta-forge/linter.py` ejecutando R1-R16 sobre cualquier SKILL.md.
3. Crear `XEK_detecta-stack/scripts/xek-detecta-stack.sh` que emite `xek/manifest@v2` real.
4. Crear `XEK_orquesta/scripts/xek-orquesta.sh` + `perfiles/*.yaml` × 12.
5. Crear `skills/SINTESIS/SKILL.md` (skill propia del rol IA-síntesis).

---

## Veredicto

**v0.5 lista para bootstrap del repo público.** Pendiente exclusivamente confirmación del operador sobre:
- Visibilidad del repo (público vs privado).
- Licencia (MIT recomendada por permisividad y compatibilidad SPDX).
- Namespace en GitHub (`Alexendros/xek-cluster` por defecto).
- Alcance de stubs en push inicial (solo doctrina + plantilla, o también 41 skills stub).

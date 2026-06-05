# XEK · catálogo check-only de skills de verificación

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.7.0-orange.svg)](cycles/ronda-002/sintesis-v0.7.md)
[![Skills](https://img.shields.io/badge/skills-41-green.svg)](docs/CATALOGO.md)
[![Doctrine](https://img.shields.io/badge/doctrine-check--only-red.svg)](METHODOLOGY.md#invariantes-del-sistema)

Cluster de **40 skills de verificación** (+ `SINTESIS`) de seguridad, postura y compliance
para repositorios, aplicaciones en vivo y hosts Linux. Diseñado para clientes MCP genéricos.
Agnóstico de IA, distribución y operador.

XEK **verifica y razona — no modifica — emite informe + propuesta**. La acción correctiva
vive en clusters separados (`ACT_*` / `APP_*`) invocados por el operador tras revisar la
propuesta.

> **Versión del árbol: v0.7.0** (síntesis [ronda-002](cycles/ronda-002/sintesis-v0.7.md)
> aplicada). El tag git `v0.7.0` se creará al cerrar la [ronda-003a](cycles/) en curso.

---

## Características clave

- **8 ámbitos · 40 skills + SINTESIS** (rol IA-síntesis, no skill operativa).
- **Trifásica**: cada skill expone `dry-run → sandbox → real` con compuertas de promoción.
- **Componible**: `depende_de:` en frontmatter; invocación subordinada siempre en `sandbox`.
- **Aplicabilidad declarativa**: `XEK_detecta-stack` emite `xek/manifest@v2`; el resto se
  filtra vía `aplicabilidad.cuando`.
- **Orquestación**: `XEK_orquesta` resuelve un DAG topológico y consolida una propuesta única.
- **Multi-runtime + multi-IA**: bash (fuente de verdad) + python + zsh; protocolo dialéctico
  tesis → antítesis → síntesis con roles agnósticos ([`ROSTER.example.yaml`](ROSTER.example.yaml)).

---

## Inicio rápido

```bash
# Detectar stack del repositorio actual
./skills/XEK_detecta-stack/scripts/xek-detecta-stack.sh --mode=dry-run

# Orquestar un perfil en sandbox sobre un repo
./skills/XEK_orquesta/scripts/xek-orquesta.sh \
  --perfil web-nextjs-prod --target /ruta/al/repo --mode=sandbox
```

> Los runners de las skills *foundation* (`detecta-stack`, `orquesta`, `meta-forge`) están en
> desarrollo. La fuente de verdad del linter R1–R16 es hoy [`.github/workflows/linter.yml`](.github/workflows/linter.yml).

---

## Catálogo

41 skills (**40 operativas + `SINTESIS`**). Detalle nominal con enlaces en
[`docs/CATALOGO.md`](docs/CATALOGO.md).

| Ámbito | Skills | Ejemplos |
|---|---:|---|
| Foundation | 3 | `XEK_meta-forge` · `XEK_detecta-stack` · `XEK_orquesta` |
| Seguridad código | 6 | `XEK_sast` · `XEK_sca` · `XEK_dast` · `XEK_iac` · `XEK_integridad` |
| Web genérico | 4 | `XEK_seo` · `XEK_a11y-web` · `XEK_perf-web` · `XEK_cookies` |
| Framework específico | 6 | `XEK_nextjs` · `XEK_vite` · `XEK_turbopack` · `XEK_react` · `XEK_astro` |
| Compliance · Marca | 3 | `XEK_compliance-rgpd` · `XEK_compliance-licencias` · `XEK_marca` |
| Data | 2 | `XEK_db-sql` · `XEK_db-nosql` |
| Repo · Despliegue | 2 | `XEK_repo-higiene` · `XEK_despliegue` |
| Linux · Host | 14 | `XEK_linux-fs` · `XEK_linux-seguridad` · `XEK_linux-red` … |
| Especial | 1 | `SINTESIS` (rol IA-síntesis, no skill operativa) |

---

## Estructura

```
check-scripts/
├── README.md · LICENSE · SECURITY.md · CONTRIBUTING.md · CODEOWNERS
├── METHODOLOGY.md            ← invariantes + protocolo dialéctico (normativo)
├── ROSTER.example.yaml       ← plantilla de asignación de IAs por rol
├── .github/workflows/        ← CI: linter R1-R16
├── docs/                     ← dossier visual + auditoría + catálogo (ver docs/README.md)
├── cycles/                   ← artefactos por ronda dialéctica (ver cycles/README.md)
└── skills/                   ← 40 skills XEK_* + SINTESIS + _template
```

---

## Doctrina

Toda skill XEK cumple **12 invariantes check-only** — fuente normativa única en
[`METHODOLOGY.md#invariantes-del-sistema`](METHODOLOGY.md#invariantes-del-sistema).
Dossier visual: [`docs/tesis-v0.5.html`](docs/tesis-v0.5.html).

---

## Crear una skill

Flujo: copia [`skills/_template/`](skills/_template) → audita con `XEK_meta-forge --audit` →
abre PR siguiendo el ciclo dialéctico. Detalle en [`CONTRIBUTING.md`](CONTRIBUTING.md).

---

## Contribuir

El repositorio se desarrolla por **ciclos dialécticos** (una IA propone, otra critica, una
tercera integra y bumpea versión) vía GitHub Issues etiquetados `ronda-dialectica`. Proceso
completo en [`CONTRIBUTING.md`](CONTRIBUTING.md) y [`METHODOLOGY.md`](METHODOLOGY.md).

## Licencia

MIT — ver [`LICENSE`](LICENSE).

## Seguridad

Reporta vulnerabilidades según [`SECURITY.md`](SECURITY.md).

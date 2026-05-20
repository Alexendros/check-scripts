# XEK · catálogo check-only de skills de verificación

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.6.0-orange.svg)](docs/tesis-v0.5.html)
[![Skills](https://img.shields.io/badge/skills-40-green.svg)](#skills)
[![Doctrine](https://img.shields.io/badge/doctrine-check--only-red.svg)](#doctrina)

Cluster de 40 skills de verificación de seguridad, postura y compliance para
repositorios, aplicaciones en vivo y hosts Linux. Diseñado para clientes MCP
genéricos. Agnóstico de IA, distribución y operador.

XEK **verifica y razona — no modifica — emite informe + propuesta**. La acción
correctiva vive en clusters separados (`ACT_*` / `APP_*`) invocados por el
operador tras revisar la propuesta.

---

## Características clave

- **8 ámbitos**: Foundation · Seguridad código · Web genérico · Framework
  específico · Compliance/Marca · Data · Repo/Despliegue · Linux/Host.
- **Trifásica**: cada skill expone modos `dry-run → sandbox → real` con
  compuertas de promoción. Saltarse el orden exige `--override-gate` con
  ventana de 60 segundos.
- **Componible**: skills declaran `depende_de:` en frontmatter. Invocación
  subordinada ejecuta siempre en `sandbox` · promoción a `real` reservada al
  operador humano.
- **Aplicabilidad declarativa**: `XEK_detecta-stack` emite un manifiesto v2
  (`xek/manifest@v2`) que el resto de skills lee para filtrarse vía
  `aplicabilidad.cuando`.
- **Orquestación**: `XEK_orquesta` recibe perfil + target, resuelve DAG
  topológico, ejecuta en sandbox, consolida en propuesta única.
- **Multi-runtime**: cada skill ofrece bash (fuente de verdad), Python
  (encapsulado vendoreable) y zsh (adapter).
- **Multi-IA por diseño**: protocolo dialéctico tesis → antítesis → síntesis
  con roles agnósticos (la asignación a IAs concretas vive en
  [`ROSTER.example.yaml`](ROSTER.example.yaml)).

---

## Inicio rápido

```bash
# Detectar stack del repositorio actual
./skills/XEK_detecta-stack/scripts/xek-detecta-stack.sh --mode=dry-run

# Lanzar perfil web-nextjs-prod en sandbox sobre un repo
./skills/XEK_orquesta/scripts/xek-orquesta.sh \
  --perfil web-nextjs-prod \
  --target /ruta/al/repo \
  --mode=sandbox

# Auditar el propio cluster (linter recursivo de meta-forge)
./skills/XEK_meta-forge/scripts/xek-meta-forge.sh \
  --audit-all \
  --mode=sandbox
```

---

## Estructura del repositorio

```
xek-cluster/
├── README.md                 ← este archivo
├── LICENSE                   ← MIT
├── SECURITY.md               ← política de seguridad
├── CONTRIBUTING.md           ← proceso dialéctico tesis-antítesis-síntesis
├── CODEOWNERS                ← responsables por subárbol
├── METHODOLOGY.md            ← protocolo dialéctico IA (normativo)
├── ROSTER.example.yaml       ← plantilla de asignación de IAs por rol
├── .gitignore
├── .github/workflows/        ← CI: linter R1-R16
├── docs/
│   ├── tesis-v0.5.html       ← dossier visual de la tesis vigente
│   └── ...
├── skills/                   ← 40 skills + SINTESIS
│   ├── XEK_meta-forge/
│   ├── XEK_detecta-stack/
│   ├── XEK_orquesta/
│   │   ├── perfiles/         ← *.yaml (12 perfiles base)
│   │   └── schemas/          ← *.schema.json
│   ├── XEK_sast/
│   ├── ...
│   └── SINTESIS/             ← skill propia del rol IA-síntesis
└── cycles/                   ← artefactos por ronda dialéctica
    └── ronda-001/
        ├── tesis-vN.md
        ├── antitesis-vN.md
        ├── sintesis-v(N+1).md
        ├── diff.md
        └── rendicion.md
```

---

## Skills

Catálogo de 40 skills agrupadas por ámbito. Cada slug enlaza a su `SKILL.md`.

### Foundation (3)
- [`XEK_meta-forge`](skills/XEK_meta-forge/SKILL.md) — forja y audita skills XEK
- [`XEK_detecta-stack`](skills/XEK_detecta-stack/SKILL.md) — manifiesto v2 (repo · app · host)
- [`XEK_orquesta`](skills/XEK_orquesta/SKILL.md) — sequencer de perfiles · DAG

### Seguridad código (6)
- [`XEK_sast`](skills/XEK_sast/SKILL.md) — análisis estático
- [`XEK_sca`](skills/XEK_sca/SKILL.md) — dependencias vulnerables
- [`XEK_dast`](skills/XEK_dast/SKILL.md) — HTTP dinámico
- [`XEK_iac`](skills/XEK_iac/SKILL.md) — IaC + contenedores + compose
- [`XEK_integridad`](skills/XEK_integridad/SKILL.md) — cadena de firmas
- [`XEK_datos-criticos`](skills/XEK_datos-criticos/SKILL.md) — leaks IP/DNS/MCP

### Web genérico (4)
- [`XEK_seo`](skills/XEK_seo/SKILL.md) — meta · sitemap · JSON-LD · OG
- [`XEK_a11y-web`](skills/XEK_a11y-web/SKILL.md) — WCAG 2.2 AA
- [`XEK_perf-web`](skills/XEK_perf-web/SKILL.md) — Core Web Vitals · bundle
- [`XEK_cookies`](skills/XEK_cookies/SKILL.md) — inventario · CMP · terceros

### Framework específico (6)
- [`XEK_nextjs`](skills/XEK_nextjs/SKILL.md) — App Router · RSC · middleware
- [`XEK_vite`](skills/XEK_vite/SKILL.md) — config · chunks · env
- [`XEK_turbopack`](skills/XEK_turbopack/SKILL.md) — bundler · cache · trace
- [`XEK_react`](skills/XEK_react/SKILL.md) — hooks · keys · hidratación
- [`XEK_astro`](skills/XEK_astro/SKILL.md) — islands · content · adapters
- [`XEK_remix`](skills/XEK_remix/SKILL.md) — loaders · actions · RR7

### Compliance · Marca (3)
- [`XEK_compliance-rgpd`](skills/XEK_compliance-rgpd/SKILL.md) — RGPD · LOPDGDD · ePrivacy
- [`XEK_compliance-licencias`](skills/XEK_compliance-licencias/SKILL.md) — SPDX · copyleft · NonCommercial
- [`XEK_marca`](skills/XEK_marca/SKILL.md) — IP by-design

### Data (2)
- [`XEK_db-sql`](skills/XEK_db-sql/SKILL.md) — esquema · índices · RLS · SSL
- [`XEK_db-nosql`](skills/XEK_db-nosql/SKILL.md) — esquema implícito · TTL · injection

### Repo · Despliegue (2)
- [`XEK_repo-higiene`](skills/XEK_repo-higiene/SKILL.md) — LICENSE · SECURITY · CODEOWNERS
- [`XEK_despliegue`](skills/XEK_despliegue/SKILL.md) — postura post-deploy

### Linux · Host · agnóstico (14)
- [`XEK_linux-fs`](skills/XEK_linux-fs/SKILL.md) — FHS · perms · setuid
- [`XEK_linux-secretos`](skills/XEK_linux-secretos/SKILL.md) — history · dotfiles · env
- [`XEK_linux-paquetes`](skills/XEK_linux-paquetes/SKILL.md) — inventario universal
- [`XEK_linux-actualizaciones`](skills/XEK_linux-actualizaciones/SKILL.md) — pendientes · CVE
- [`XEK_linux-systemd`](skills/XEK_linux-systemd/SKILL.md) — units · timers
- [`XEK_linux-seguridad`](skills/XEK_linux-seguridad/SKILL.md) — sysctl · MAC · kernel
- [`XEK_linux-red`](skills/XEK_linux-red/SKILL.md) — firewall · LISTEN · DNS
- [`XEK_linux-vpn`](skills/XEK_linux-vpn/SKILL.md) — túneles · DNS leak
- [`XEK_linux-gpu`](skills/XEK_linux-gpu/SKILL.md) — vendor · drivers · CDI
- [`XEK_linux-peripherals`](skills/XEK_linux-peripherals/SKILL.md) — audio+bluetooth (D-Bus unificado · fusión v0.6)
- [`XEK_linux-energia`](skills/XEK_linux-energia/SKILL.md) — power · thermal · battery
- [`XEK_linux-contenedores`](skills/XEK_linux-contenedores/SKILL.md) — Docker/Podman/LXC
- [`XEK_linux-escritorio`](skills/XEK_linux-escritorio/SKILL.md) — DE · extensions
- [`XEK_linux-backup`](skills/XEK_linux-backup/SKILL.md) — restic/borg · offsite

---

## Doctrina

Toda skill XEK cumple 12 invariantes:

1. **check-only** — lee y razona, nunca modifica el objetivo
2. **trifásica** — dry-run → sandbox → real con compuertas
3. **agnóstica IA** — roles funcionales, sin productos en cuerpo
4. **agnóstica operador** — escalada vía `${XEK_SUDO:-sudo -A}`
5. **agnóstica distro** — huellas universales en manifiesto v2
6. **imperativa** — verbos afirmativos, prohibido condicional
7. **canónica** — `referencias_canonicas` ≥ 1 doc oficial + ≥ 1 estándar
8. **migrable** — bash + python + zsh
9. **append-only** — `mejoras_ultima_edicion` acumulativa
10. **componible** — invocación subordinada siempre sandbox
11. **aplicable** — declara `aplicabilidad` contra manifiesto
12. **dialéctica** — contribuciones siguen tesis → antítesis → síntesis

Detalle visual: [`docs/tesis-v0.5.html`](docs/tesis-v0.5.html).

---

## Contribuir

Lee [`CONTRIBUTING.md`](CONTRIBUTING.md) y [`METHODOLOGY.md`](METHODOLOGY.md).
El repositorio se desarrolla por **ciclos dialécticos**: una IA (rol IA-tesis)
propone, otra (rol IA-antítesis) critica con alternativa, una tercera (rol
IA-síntesis) integra y bumpea versión. La asignación concreta vive en
`ROSTER.yaml` (no versionado, copia desde `ROSTER.example.yaml`).

### Canal operativo

Para que el ciclo avance sin relay manual entre canales externos y este
repositorio, todo input dialéctico se entrega vía **GitHub Issues** etiquetados
`ronda-dialectica`:

1. La síntesis abre un issue con la plantilla
   [`ronda.yml`](.github/ISSUE_TEMPLATE/ronda.yml) describiendo el rol
   solicitado, el brief MR+ y el cap de coste.
2. El rol delegado (IA-antítesis · IA-revisor) entrega su contribución como
   **comentario único** en el issue, sin commits ni PRs.
3. La síntesis procesa el comentario, publica en `cycles/ronda-<NNN>/` y
   cierra el issue con referencia al commit.
4. El operador revisa al cerrar release tag, no en cada ronda.

Reglas duras del canal:
- Un único rol por issue.
- El operador no actúa como relay. La síntesis lee directamente del comentario.
- Si el rol delegado quiere proponer código, lo hace **como bloque dentro del
  comentario** — nunca como PR (la síntesis decide qué se materializa en el
  árbol).

## Licencia

MIT — ver [`LICENSE`](LICENSE).

## Seguridad

Reporta vulnerabilidades según [`SECURITY.md`](SECURITY.md).

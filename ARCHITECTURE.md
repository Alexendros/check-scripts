# Arquitectura de xek-cluster

Documento estructural del catálogo. Describe la organización del cluster, los
roles dialécticos, el ciclo de trabajo y los invariantes que gobiernan cada
skill. La doctrina condensada vive en el `README.md`; el protocolo normativo en
`METHODOLOGY.md`. Este documento explica **cómo encajan las piezas**.

## Principio rector · check-only

XEK **verifica y razona — nunca modifica el objetivo**. Toda skill lee, analiza
y emite informe más propuesta. La acción correctiva vive en clusters separados
(`ACT_*` / `APP_*`) que el operador invoca tras revisar la propuesta. Este
límite es estructural: ninguna skill del catálogo escribe sobre el target.

El cluster es además **agnóstico** en tres ejes: de IA (roles funcionales, sin
productos en el cuerpo), de distribución (huellas universales en el manifiesto
v2) y de operador (escalada vía `${XEK_SUDO:-sudo -A}`). Está diseñado para
clientes MCP genéricos, no para una herramienta concreta.

## Topología del catálogo · 3 foundation + 39 por ámbito

El cluster se organiza en una capa **foundation** y siete ámbitos de
verificación.

### Foundation (3)

| Skill | Responsabilidad |
|---|---|
| `XEK_meta-forge` | Forja y audita skills XEK. Implementa el linter R1-R16 que valida cada `SKILL.md`. |
| `XEK_detecta-stack` | Emite el manifiesto `xek/manifest@v2` (repo · app · host) que el resto de skills lee para filtrarse vía `aplicabilidad.cuando`. |
| `XEK_orquesta` | Sequencer de perfiles: recibe perfil más target, resuelve el DAG topológico de dependencias, ejecuta en sandbox y consolida en una propuesta única. |

### Ámbitos de verificación (39)

| Ámbito | Nº | Foco |
|---|---|---|
| Seguridad código | 6 | SAST, SCA, DAST, IaC, integridad de firmas, datos críticos. |
| Web genérico | 4 | SEO, accesibilidad (WCAG 2.2 AA), performance (Core Web Vitals), cookies/CMP. |
| Framework específico | 6 | Next.js, Vite, Turbopack, React, Astro, Remix. |
| Compliance · Marca | 3 | RGPD/LOPDGDD/ePrivacy, licencias (SPDX/copyleft), marca/IP by-design. |
| Data | 2 | SQL (esquema, índices, RLS, SSL) y NoSQL (esquema implícito, TTL, injection). |
| Repo · Despliegue | 2 | Higiene de repositorio y postura post-deploy. |
| Linux · Host | 14 | FS, secretos, paquetes, actualizaciones, systemd, seguridad, red, VPN, GPU, periféricos, energía, contenedores, escritorio, backup. |
| `SINTESIS` | (rol) | Skill propia del rol IA-síntesis; no es de verificación, define el procedimiento de merge dialéctico. |

El catálogo declara **40 skills de verificación** (3 foundation + 37 de ámbito
en la cuenta del README) más la skill `SINTESIS`, que es metodológica. La cuenta
exacta puede variar por ronda; la fuente de verdad es el árbol `skills/`.

## Anatomía de una skill

Cada skill vive en `skills/<slug>/` y expone:

- `SKILL.md` — frontmatter YAML (objetivo, triggers, dependencias,
  aplicabilidad, modos de ejecución, referencias canónicas) más cuerpo
  imperativo. Es la fuente de verdad que el linter R1-R16 audita.
- `scripts/` — implementación multi-runtime: **bash** (fuente de verdad),
  **python** (encapsulado vendoreable) y **zsh** (adapter).

Las skills declaran `depende_de:` en el frontmatter. La invocación subordinada
ejecuta **siempre en sandbox**; la promoción a `real` queda reservada al
operador humano.

### Ejecución trifásica

Toda skill expone tres modos con compuertas de promoción:

```
dry-run  ──gate──▶  sandbox  ──gate──▶  real
```

Saltarse el orden exige `--override-gate` con una ventana de 60 segundos.

### Doce invariantes

Cada skill cumple: check-only, trifásica, agnóstica de IA, agnóstica de
operador, agnóstica de distro, imperativa, canónica (≥ 1 doc oficial más ≥ 1
estándar), migrable (bash + python + zsh), append-only, componible, aplicable y
dialéctica. El detalle vive en el `README.md` (sección Doctrina) y se verifica
en CI mediante el linter R1-R16.

## Roles dialécticos · tesis / antítesis / síntesis

El desarrollo del catálogo no lo hace una sola IA: el protocolo fuerza
desacuerdo argumentado entre actores independientes y produce trazas
auditables.

- **IA-tesis** (rol 01) — propone el artefacto v(N) más bitácora de decisiones.
- **IA-antítesis** (rol 02) — critica (3-5 puntos) y aporta una alternativa
  diferenciada en ≥ 2 ejes.
- **IA-síntesis** (rol 03) — integra, emite `diff.md` trazable y bumpea versión.
- **Operador** (rol humano) — firma la rendición (`accept` / `request-changes`
  / `abort`). La aprobación final nunca se delega a una IA.

Reglas duras: rol único por ronda, bump semver por ronda cerrada, cap de coste
declarado por rol, abort tras tres rondas sin convergencia, bump major si se
sustituye la IA asignada a un rol. La especificación completa está en
`METHODOLOGY.md`.

### ROSTER.yaml · separación de agnosticismo

El cuerpo del repositorio permanece agnóstico de IA. La asignación concreta de
IAs reales a cada rol vive en `ROSTER.yaml`, **no versionado** y derivado de
`ROSTER.example.yaml`. Allí se declara también el `coste_max_por_msg` de cada
rol, base del presupuesto auditable.

## Ciclo en GitHub Issues

Para que el ciclo avance sin relay manual, todo input dialéctico se entrega vía
**GitHub Issues** etiquetados `ronda-dialectica`:

1. La síntesis abre un issue con la plantilla `ronda.yml` describiendo el rol
   solicitado, el brief y el cap de coste.
2. El rol delegado entrega su contribución como **comentario único** en el
   issue — sin commits ni PRs.
3. La síntesis procesa el comentario, publica en `cycles/ronda-<NNN>/` y cierra
   el issue referenciando el commit.
4. El operador revisa al cerrar el release tag, no en cada ronda.

Cada ronda deja artefactos en `cycles/ronda-<NNN>/`: `tesis-vN.md`,
`antitesis-vN.md`, `sintesis-v(N+1).md`, `diff.md`, `rendicion.md` (firma del
operador) y `coste.csv` (USD por mensaje y total, auditable; no se commitea por
defecto).

## Control de coste

El protocolo trata el coste como invariante, no como apunte. Cada rol declara
`coste_max_por_msg` en `ROSTER.yaml`; cada ronda registra el gasto real en
`cycles/<ronda>/coste.csv`. El cap acotado por mensaje, combinado con la regla
`abort-tres-rondas`, mantiene el presupuesto acotado y la deriva bajo control.

## Mapa de directorios

```
xek-cluster/
├── README.md            ← visión general + doctrina
├── ARCHITECTURE.md      ← este documento
├── METHODOLOGY.md       ← protocolo dialéctico (normativo)
├── ROSTER.example.yaml  ← plantilla de asignación de IAs por rol
├── CONTRIBUTING.md      ← proceso de contribución
├── docs/                ← dossiers visuales + ADRs
├── skills/              ← 3 foundation + ámbitos + SINTESIS
│   ├── XEK_meta-forge/
│   ├── XEK_detecta-stack/
│   ├── XEK_orquesta/{perfiles,schemas}/
│   └── ...
├── cycles/              ← artefactos por ronda dialéctica
└── .github/workflows/   ← CI: linter R1-R16 + validación de estructura
```

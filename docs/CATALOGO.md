# Catálogo de skills · XEK

41 skills: **40 operativas** agrupadas por ámbito + `SINTESIS` (rol IA-síntesis, no skill
operativa directa). Cada slug enlaza a su `SKILL.md`. Resumen por ámbito en el
[`README.md`](../README.md#catálogo).

## Foundation (3)
- [`XEK_meta-forge`](../skills/XEK_meta-forge/SKILL.md) — forja y audita skills XEK
- [`XEK_detecta-stack`](../skills/XEK_detecta-stack/SKILL.md) — manifiesto v2 (repo · app · host)
- [`XEK_orquesta`](../skills/XEK_orquesta/SKILL.md) — sequencer de perfiles · DAG

## Seguridad código (6)
- [`XEK_sast`](../skills/XEK_sast/SKILL.md) — análisis estático
- [`XEK_sca`](../skills/XEK_sca/SKILL.md) — dependencias vulnerables
- [`XEK_dast`](../skills/XEK_dast/SKILL.md) — HTTP dinámico
- [`XEK_iac`](../skills/XEK_iac/SKILL.md) — IaC declarativa en repo (Dockerfile · compose · Terraform)
- [`XEK_integridad`](../skills/XEK_integridad/SKILL.md) — cadena de firmas
- [`XEK_datos-criticos`](../skills/XEK_datos-criticos/SKILL.md) — leaks IP/DNS/MCP

## Web genérico (4)
- [`XEK_seo`](../skills/XEK_seo/SKILL.md) — meta · sitemap · JSON-LD · OG
- [`XEK_a11y-web`](../skills/XEK_a11y-web/SKILL.md) — WCAG 2.2 AA
- [`XEK_perf-web`](../skills/XEK_perf-web/SKILL.md) — Core Web Vitals · bundle
- [`XEK_cookies`](../skills/XEK_cookies/SKILL.md) — inventario · CMP · terceros

## Framework específico (6)
- [`XEK_nextjs`](../skills/XEK_nextjs/SKILL.md) — App Router · RSC · middleware
- [`XEK_vite`](../skills/XEK_vite/SKILL.md) — config · chunks · env
- [`XEK_turbopack`](../skills/XEK_turbopack/SKILL.md) — bundler · cache · trace (aplicabilidad acotada a Next.js ≥ 15 / `tooling.bundler == turbopack`)
- [`XEK_react`](../skills/XEK_react/SKILL.md) — hooks · keys · hidratación
- [`XEK_astro`](../skills/XEK_astro/SKILL.md) — islands · content · adapters
- [`XEK_remix`](../skills/XEK_remix/SKILL.md) — loaders · actions · RR7

## Compliance · Marca (3)
- [`XEK_compliance-rgpd`](../skills/XEK_compliance-rgpd/SKILL.md) — RGPD · LOPDGDD · ePrivacy
- [`XEK_compliance-licencias`](../skills/XEK_compliance-licencias/SKILL.md) — SPDX · copyleft · NonCommercial
- [`XEK_marca`](../skills/XEK_marca/SKILL.md) — IP by-design

## Data (2)
- [`XEK_db-sql`](../skills/XEK_db-sql/SKILL.md) — esquema · índices · RLS · SSL
- [`XEK_db-nosql`](../skills/XEK_db-nosql/SKILL.md) — esquema implícito · TTL · injection

## Repo · Despliegue (2)
- [`XEK_repo-higiene`](../skills/XEK_repo-higiene/SKILL.md) — LICENSE · SECURITY · CODEOWNERS
- [`XEK_despliegue`](../skills/XEK_despliegue/SKILL.md) — postura post-deploy

## Linux · Host · agnóstico (14)
- [`XEK_linux-fs`](../skills/XEK_linux-fs/SKILL.md) — FHS · perms · setuid
- [`XEK_linux-secretos`](../skills/XEK_linux-secretos/SKILL.md) — history · dotfiles · env
- [`XEK_linux-paquetes`](../skills/XEK_linux-paquetes/SKILL.md) — inventario universal
- [`XEK_linux-actualizaciones`](../skills/XEK_linux-actualizaciones/SKILL.md) — pendientes · CVE
- [`XEK_linux-systemd`](../skills/XEK_linux-systemd/SKILL.md) — units · timers
- [`XEK_linux-seguridad`](../skills/XEK_linux-seguridad/SKILL.md) — sysctl · MAC · kernel
- [`XEK_linux-red`](../skills/XEK_linux-red/SKILL.md) — firewall · LISTEN · DNS
- [`XEK_linux-vpn`](../skills/XEK_linux-vpn/SKILL.md) — túneles · DNS leak
- [`XEK_linux-gpu`](../skills/XEK_linux-gpu/SKILL.md) — vendor · drivers · CDI
- [`XEK_linux-peripherals`](../skills/XEK_linux-peripherals/SKILL.md) — audio+bluetooth (D-Bus unificado · fusión v0.6)
- [`XEK_linux-energia`](../skills/XEK_linux-energia/SKILL.md) — power · thermal · battery
- [`XEK_linux-contenedores`](../skills/XEK_linux-contenedores/SKILL.md) — runtime Docker/Podman/LXC en host
- [`XEK_linux-escritorio`](../skills/XEK_linux-escritorio/SKILL.md) — DE · extensions
- [`XEK_linux-backup`](../skills/XEK_linux-backup/SKILL.md) — restic/borg · offsite

## Especial (1)
- [`SINTESIS`](../skills/SINTESIS/SKILL.md) — procedimiento de merge del rol IA-síntesis. No es
  una skill de verificación operativa; implementa el paso de síntesis del protocolo dialéctico
  ([`METHODOLOGY.md`](../METHODOLOGY.md)).

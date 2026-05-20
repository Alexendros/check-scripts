# Security Policy

## Reportar vulnerabilidades

XEK es un cluster de **skills check-only**. No modifica los objetivos que
verifica. Aun así, una skill mal escrita puede:

- Exfiltrar información sensible vía `referencias_canonicas` apuntando a
  servicios externos no auditados.
- Almacenar findings que incluyan credenciales si la `allowlist` está mal
  configurada (riesgo principal en `XEK_datos-criticos`, `XEK_sast`,
  `XEK_linux-secretos`).
- Escalada de privilegios mal limitada en skills `XEK_linux-*` que usen
  `${XEK_SUDO}`.

## Cómo reportar

**No abras un issue público para vulnerabilidades.**

1. Usa GitHub Security Advisory: `Settings → Security → Advisories → Report
   a vulnerability` en este repositorio.
2. Como alternativa, contacta al/la responsable principal listado en
   [`CODEOWNERS`](CODEOWNERS).

Incluye:

- Skill afectada (slug).
- Modo de ejecución reproducido (`dry-run` / `sandbox` / `real`).
- Pasos de reproducción.
- Impacto observado (lectura no autorizada, escalada, leak, etc.).
- Versión del cluster (`docs/tesis-v*.html`).

## Política de respuesta

| Severidad | Reconocimiento | Parche objetivo |
|---|---|---|
| Crítica | < 48 h | < 7 días |
| Alta | < 72 h | < 14 días |
| Media | < 7 días | < 30 días |
| Baja | < 14 días | siguiente release minor |

## Alcance

**Dentro de alcance**:

- Skills publicadas en `skills/` con `estado: produccion` o `beta`.
- Workflows en `.github/workflows/`.
- `XEK_meta-forge/linter.py` (linter del cluster).
- Esquemas en `skills/XEK_orquesta/schemas/`.

**Fuera de alcance**:

- Skills en `estado: borrador` (claramente marcadas).
- Forks de terceros.
- Configuración del operador en `ROSTER.yaml`.
- Documentación visual (`docs/*.html`).

## Reconocimientos

Lista de personas e investigadores que han reportado responsablemente vivirá
en `SECURITY-HALL-OF-FAME.md` cuando exista el primer reporte.

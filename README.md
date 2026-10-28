# ts-skills — SDD incremental supervisado

Desarrollo guiado por especificaciones (SDD) que combina:

- **[OpenSpec](https://github.com/Fission-AI/openspec) como memoria funcional**: reglas de negocio vigentes, historial de cambios y análisis de impacto antes de tocar nada.
- **[hola-ai](https://github.com/nschurmann/hola-ai) como disciplina de implementación**: un test → rojo → código mínimo → verde → **parar y revisar**.

> Generar código es barato; comprenderlo, validarlo y mantenerlo sigue siendo caro. Detenerse a menudo cuesta menos que comprender de golpe miles de líneas generadas por una IA.

Dos garantías complementarias:

| | Pieza | Qué te asegura |
|---|---|---|
| **Control de producto** | OpenSpec + análisis de impacto | Sabes qué se construye, por qué y qué reglas existentes no pueden romperse |
| **Control de implementación** | `/sdd-pair` | Entiendes cada incremento antes de continuar; el agente no decide por ti |

## Flujo

```
/sdd-backlog (opcional)          idea → historias verticales = futuros changes
/opsx:propose <change>           impact → proposal → specs → design → tasks   ← revisas y apruebas
/sdd-pair                        1 tarea, 1 ciclo TDD, se detiene              ← revisas
/sdd-pair …                      repetir hasta completar tasks.md
/opsx:verify  →  /opsx:archive   las delta specs pasan a openspec/specs/
```

## Qué contiene

| Fichero | Qué aporta |
|---|---|
| `openspec/schemas/sdd-incremental/` | Schema OpenSpec (fork de `spec-driven`). Añade el artefacto **`impact`** antes de la propuesta, limita el tamaño de los cambios, exige specs de reglas de negocio, tareas pequeñas ligadas a escenarios y tests de regresión, y sustituye el `apply` "haz todas las tareas" por uno incremental. |
| `openspec/config.example.yaml` | Artefactos en español (encabezados validados por OpenSpec en inglés) y `operations.apply.guidance` como red de seguridad si alguien usa `/opsx:apply`. |
| `skills/sdd-pair/` | El núcleo: pair programming sobre una tarea de `tasks.md`. Propone la lista de tests, hace un ciclo TDD y para. Nunca commitea ni cambia specs para justificar el código. Sustituye a `/opsx:apply`. |
| `skills/sdd-backlog/` | Trocea una idea en 10–15 historias verticales, cada una un change pequeño. Consulta antes las specs vigentes. |
| `scripts/install.sh` | Instala todo en un proyecto. |

No se modifica OpenSpec: se usa su CLI oficial y sus puntos de extensión documentados (schemas propios, `config.yaml`). Los skills `openspec-*` siguen siendo de OpenSpec y `openspec update` los regenera sin tocar los `sdd-*`.

## Instalación

Requiere Node ≥ 20.19.

```bash
cd mi-proyecto
npx @fission-ai/openspec@latest init --tools claude,codex,github-copilot
/ruta/a/ts-skills/scripts/install.sh . --tools claude,codex,github-copilot
npx @fission-ai/openspec@latest schema validate sdd-incremental
```

Después, añade el stack y las restricciones del proyecto en `openspec/config.yaml` (`context`).

`/opsx:verify` no viene en el perfil por defecto de OpenSpec. Actívalo con `openspec config profile` (Change workflows only → verify) y luego `openspec update`.

### Invocación por agente

| Agente | Dónde se instalan | Cómo se invocan |
|---|---|---|
| Claude Code | `.claude/skills/` | `/sdd-pair`, `/sdd-backlog` |
| Codex | `.agents/skills/` | `$sdd-pair`, `$sdd-backlog` |
| GitHub Copilot | `.github/skills/` | skill `sdd-pair`, `sdd-backlog` |

Los skills son de invocación manual (`disable-model-invocation: true`): nunca se activan solos.

## Principios

- **No inventar.** Lo que falta se pregunta, no se rellena.
- **Las specs son reglas de negocio, no implementación.** ✅ «Una operación cancelada libera sus recursos asignados». ❌ «`cancelOperation()` invoca `resourceRepository.deleteAll()`».
- **Reglas aprobadas ≠ cambios propuestos ≠ comportamiento implementado.** Una spec nunca cambia porque el código haga otra cosa.
- **Consultar antes de proponer.** `openspec/specs/` es lo vigente; `openspec/changes/archive/` solo explica el porqué de decisiones pasadas.
- **Pequeño y vertical.** Changes de pocos requisitos; tareas de un ciclo TDD (~50 líneas, ≤3 ficheros).
- **Sugerir, no decidir.** Patrones, refactors y commits los decides tú.

## Limitación conocida

La parada tras cada ciclo es una **instrucción** al agente, igual que en hola-ai: ni OpenSpec ni hola-ai la imponen técnicamente. El progreso sí es fiable, porque vive en las casillas de `tasks.md`. Si en la práctica el agente no se detiene de forma consistente, el siguiente paso es un hook de Claude Code que bloquee marcar una segunda tarea en el mismo turno.

## Créditos

- Schema derivado de `spec-driven` de [OpenSpec](https://github.com/Fission-AI/openspec) (MIT, © OpenSpec Contributors).
- Skills adaptados de [hola-ai](https://github.com/nschurmann/hola-ai) (MIT, © Nicolas Schurmann).

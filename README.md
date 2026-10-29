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

```mermaid
flowchart TD
    idea["Idea o funcionalidad"] --> grande{"¿Es grande?"}
    grande -->|Sí| backlog["/sdd-backlog<br/>idea → historias de una línea"]
    grande -->|No| propose
    backlog --> historia["Elegir UNA historia"]
    historia --> propose["/opsx:propose &lt;historia + detalles&gt;"]

    subgraph plan ["Planificación (OpenSpec)"]
        propose --> impact["impact.md<br/>reglas afectadas, conflictos, preguntas"]
        impact --> preguntas{"¿Preguntas abiertas?"}
        preguntas -->|Sí| responder["Respondes"] --> impact
        preguntas -->|No| artefactos["proposal → specs → design → tasks"]
    end

    artefactos --> revision{"Revisas y apruebas"}
    revision -->|Cambios| artefactos

    subgraph impl ["Implementación (/sdd-pair)"]
        tarea["Primera tarea pendiente"] --> tests["Propone lista de tests"] --> aprueba{"¿Apruebas?"}
        aprueba -->|No| tests
        aprueba -->|Sí| ciclo["1 ciclo TDD<br/>rojo → mínimo → verde<br/>complejidad ≤ 15"]
        ciclo --> para["Se detiene: revisas"]
        para -->|Más tests| ciclo
        para -->|Tarea completa| marca["Marca [x] y sugiere commit<br/>(el commit lo haces tú)"]
        marca --> quedan{"¿Quedan tareas?"}
        quedan -->|Sí| tarea
    end

    revision -->|OK| tarea

    quedan -->|No| verify["/opsx:verify"] --> archive["/opsx:archive<br/>specs del cambio → openspec/specs/"]
    archive --> mas{"¿Más historias?"}
    mas -->|Sí| historia
```

| Paso | Comando | Qué haces tú |
|---|---|---|
| 0. Trocear (opcional) | `/sdd-backlog` | Cuentas la idea entera y ajustas la lista de historias |
| 1. Proponer | `/opsx:propose <historia>` | Respondes las preguntas de `impact.md` y revisas specs y tareas |
| 2. Implementar | `/sdd-pair` (una vez por tarea) | Apruebas la lista de tests y revisas cada ciclo |
| 3. Cerrar | `/opsx:verify` → `/opsx:archive` | Confirmas que el código cumple las specs |

### Qué descripción recibe cada comando

La descripción se da **dos veces y a dos niveles**:

- **`/sdd-backlog`** recibe la **idea entera** y la trocea en historias de **una línea**, sin detalle a propósito.
- **`/opsx:propose`** recibe **una historia** y la desarrolla: análisis de impacto, propuesta, specs con escenarios (los criterios de aceptación), diseño y tareas.

Una línea del backlog no basta para escribir specs. El detalle se completa en el propose: OpenSpec pregunta lo que afecte al alcance o a los criterios de aceptación, y `impact.md` añade las preguntas que te toca decidir.

En la **misma conversación** que el backlog, basta con el nombre:

```
/opsx:propose reasignar-recurso-manual
```

En una **sesión nueva** (por ejemplo, desde Jira), pega la historia y lo que sepas:

```
/opsx:propose reasignar-recurso-manual: Como operador, quiero reasignar un recurso a otra
operación, para cubrir un cambio de última hora. Solo recursos libres en ese horario;
el supervisor no tiene que aprobarlo.
```

**Sin backlog**, cuando el cambio ya es pequeño, describe directamente lo que quieres:

```
/opsx:propose "permitir cancelar una operación pendiente y liberar sus recursos"
```

## Qué contiene

| Fichero | Qué aporta |
|---|---|
| `openspec/schemas/sdd-incremental/` | Schema OpenSpec (fork de `spec-driven`). Añade el artefacto **`impact`** antes de la propuesta, limita el tamaño de los cambios, exige specs de reglas de negocio, tareas pequeñas ligadas a escenarios y tests de regresión, y sustituye el `apply` "haz todas las tareas" por uno incremental. |
| `openspec/config.example.yaml` | Artefactos en español (encabezados validados por OpenSpec en inglés) y `operations.apply.guidance` como red de seguridad si alguien usa `/opsx:apply`. |
| `skills/sdd-pair/` | El núcleo: pair programming sobre una tarea de `tasks.md`. Propone la lista de tests, hace un ciclo TDD y para. Nunca commitea ni cambia specs para justificar el código. Sustituye a `/opsx:apply`. |
| `skills/sdd-backlog/` | Trocea una idea en 10–15 historias verticales, cada una un change pequeño. Consulta antes las specs vigentes. |
| `scripts/install.sh`, `scripts/install.ps1` | Instalan todo en un proyecto (bash para Linux/macOS/Git Bash; PowerShell para Windows). |

No se modifica OpenSpec: se usa su CLI oficial y sus puntos de extensión documentados (schemas propios, `config.yaml`). Los skills `openspec-*` siguen siendo de OpenSpec y `openspec update` los regenera sin tocar los `sdd-*`.

## Instalación

Requiere Node ≥ 20.19.

```bash
cd mi-proyecto
npx @fission-ai/openspec@latest init --tools claude,codex,github-copilot,opencode
/ruta/a/ts-skills/scripts/install.sh . --tools claude,codex,github-copilot,opencode
npx @fission-ai/openspec@latest schema validate sdd-incremental
```

Usa en `--tools` solo los agentes que necesites, y los mismos en los dos comandos.

**En Windows** usa `install.ps1` desde PowerShell (Windows PowerShell 5.1 o PowerShell 7):

```powershell
cd C:\Users\<usuario>\dev\mi-proyecto
npx @fission-ai/openspec@latest init --tools opencode
powershell -ExecutionPolicy Bypass -File C:\Users\<usuario>\dev\ts-skills\scripts\install.ps1 . -Tools opencode
```

- `-Tools` acepta varios agentes separados por comas: `-Tools claude,opencode`.
- `-ExecutionPolicy Bypass` solo afecta a esa ejecución; hace falta porque Windows bloquea los scripts `.ps1` por defecto.
- Alternativa: `install.sh` desde Git Bash o WSL, con rutas tipo `/c/Users/<usuario>/dev/...`.

Después, añade el stack y las restricciones del proyecto en `openspec/config.yaml` (`context`).

`/opsx:verify` no viene en el perfil por defecto de OpenSpec. Actívalo con `openspec config profile` (Change workflows only → verify) y luego `openspec update`.

### Invocación por agente

| Agente | Dónde se instalan | Cómo se invocan |
|---|---|---|
| Claude Code | `.claude/skills/` | `/sdd-pair`, `/sdd-backlog` |
| Codex | `.agents/skills/` | `$sdd-pair`, `$sdd-backlog` |
| GitHub Copilot | `.github/skills/` | skill `sdd-pair`, `sdd-backlog` |
| OpenCode | `.opencode/skills/` | pide al agente que use el skill `sdd-pair` / `sdd-backlog`; los comandos de OpenSpec son `/opsx-propose`, `/opsx-explore`… |

En Claude Code los skills son de invocación manual (`disable-model-invocation: true`) y nunca se activan solos. Los demás agentes ignoran ese campo y pueden cargarlos por su cuenta si el contexto encaja; invócalos explícitamente.

## Principios

- **No inventar.** Lo que falta se pregunta, no se rellena.
- **Las specs son reglas de negocio, no implementación.** ✅ «Una operación cancelada libera sus recursos asignados». ❌ «`cancelOperation()` invoca `resourceRepository.deleteAll()`».
- **Reglas aprobadas ≠ cambios propuestos ≠ comportamiento implementado.** Una spec nunca cambia porque el código haga otra cosa.
- **Consultar antes de proponer.** `openspec/specs/` es lo vigente; `openspec/changes/archive/` solo explica el porqué de decisiones pasadas.
- **Pequeño y vertical.** Changes de pocos requisitos; tareas de un ciclo TDD (~50 líneas, ≤3 ficheros).
- **Complejidad cognitiva ≤ 15** (definición de SonarSource) en cada función que se escribe o se toca, siempre que sea posible. Si queda por encima, `/sdd-pair` lo avisa y propone un refactor antes de seguir; solo se acepta más de 15 con tu aprobación y un motivo.
- **Sugerir, no decidir.** Patrones, refactors y commits los decides tú.

## Limitación conocida

La parada tras cada ciclo es una **instrucción** al agente, igual que en hola-ai: ni OpenSpec ni hola-ai la imponen técnicamente. El progreso sí es fiable, porque vive en las casillas de `tasks.md`. Si en la práctica el agente no se detiene de forma consistente, el siguiente paso es un hook de Claude Code que bloquee marcar una segunda tarea en el mismo turno.

El límite de complejidad cognitiva también es una instrucción. Para que se cumpla de verdad, configúralo en el analizador del proyecto: SonarQube/SonarLint (regla de complejidad cognitiva, umbral 15), `eslint-plugin-sonarjs` (`sonarjs/cognitive-complexity: ["error", 15]`) en TypeScript/Angular, o PMD `CognitiveComplexity` en Java. `/sdd-pair` usa el analizador cuando existe y, si no, solo estima.

## Créditos

- Schema derivado de `spec-driven` de [OpenSpec](https://github.com/Fission-AI/openspec) (MIT, © OpenSpec Contributors).
- Skills adaptados de [hola-ai](https://github.com/nschurmann/hola-ai) (MIT, © Nicolas Schurmann).

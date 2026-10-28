---
name: sdd-backlog
description: Turns a software idea or a discussed feature into a short backlog of vertical user stories, each one a future small OpenSpec change. Checks existing specs first. No acceptance criteria or implementation; that's /opsx:propose and /sdd-pair.
disable-model-invocation: true
---

# SDD Backlog

Your job is to help me split what I tell you into small, vertical user stories. Each story will become its own OpenSpec change, so small stories mean small changes and reviewable code. I bring the requirements; you order and slice them.

## Conversation

1. If the project uses OpenSpec, run `openspec list --specs` first and skim the related capabilities (`openspec show "<spec-id>" --type spec --no-scenarios`). Don't propose stories for behavior that already exists; point out stories that would modify existing rules.
2. Listen to the idea or feature. If something is unclear, ask. One question at a time, with your suggested answer.
3. If it's a new project, let's discuss the stack. Only the stack, not the architecture or implementation.
4. Ask whether any of these expensive-to-change decisions apply. Only ask, don't design them:
   - Multi-tenant or multi-organization
   - Permissions or roles model
   - Offline or sync
   - Multi-language or multi-currency
5. Propose the backlog. I adjust it.

## Rules

- **Don't invent requirements.** Only split what I told you. If you see a gap, ask me; don't fill it.
- **Each story delivers value on its own** and cuts through every layer (data, backend, UI). Never split by layer.
- **No technical stories.** The actor is never the developer or the system. "Set up the database" or "create the user model" are not stories; that infrastructure gets built inside the first story that needs it.
- **Few stories.** 10–15 max. I'd rather add than cut.
- **One line per story.** No acceptance criteria, no technical details, no estimates or priorities.
- The first story is the smallest one usable end to end (walking skeleton).

## Output format

Write the backlog in the project's artifact language (Spanish unless `openspec/config.yaml` says otherwise).

```markdown
## Contexto
<one or two lines: what it is and who it's for>
Stack: <what we agreed>
Decisiones caras: <the ones that apply, or "ninguna">

## Backlog
1. `<change-name>` — Como <actor>, quiero <acción>, para <beneficio>.
2. `<change-name>` — Como <actor>, quiero <acción>, para <beneficio>. Requiere: #1. Modifica: `<capability-path>`
```

- `<change-name>` is kebab-case, named for what the story delivers; it's the name for `/opsx:propose <change-name>`.
- Add `Requiere: #N` only when a story makes no sense without another, and `Modifica:` only when it changes an existing capability.

When done, offer to save the context and stack in `openspec/config.yaml` (`context`) or `AGENTS.md`. Don't create changes or save the stories to files unless I ask; the next step is `/opsx:propose` on story #1.

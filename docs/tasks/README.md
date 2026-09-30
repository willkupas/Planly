# Tasks

Uma task = um arquivo `T-NNN-slug.md`.

```markdown
---
id: T-001
title: Título curto
status: todo        # todo | in-progress | done | blocked
plan: 0001
depends_on: []      # ex.: [T-001]
area: app | firebase | functions | ci | docs
parallel_ok: true   # pode rodar em subagente em paralelo
---

## Objetivo
## Critérios de aceite
- [ ] ...
## Notas / decisões
```

Regras: ao terminar, marcar `done`, marcar critérios, registrar decisões novas no CLAUDE.md/ADR.

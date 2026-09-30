---
id: T-011
title: Autenticação Google
status: todo
plan: 0001
depends_on: [T-007]
area: app
parallel_ok: true
---

## Critérios de aceite
- [ ] `AuthRepository` abstrato com implementação Google (outros provedores plugáveis depois)
- [ ] Telas splash e login; estado de sessão via provider; logout
- [ ] Documento `users/{uid}` criado/atualizado
- [ ] Testes de unidade/widget

---
id: T-022
title: Lembretes (notificações locais)
status: todo
plan: 0002
depends_on: [T-018]
area: app
parallel_ok: true
---

## Critérios de aceite
- [ ] Notificação local agendada para tarefas com `schedule` e `notification.enabled` (`offsetMinutes` antes)
- [ ] Permissão `POST_NOTIFICATIONS` (Android 13+) pedida no momento certo, com explicação; negada não quebra o app
- [ ] Alarmes exatos: decidir `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM` vs. janela aproximada (política da Play) e documentar
- [ ] Reagendar ao editar/concluir/excluir a tarefa e após reinício do aparelho
- [ ] Timezone correto (UTC + IANA), inclusive mudança de fuso
- [ ] Canais Android: "Lembretes", "Atividade da casa", "Conta e plano"
- [ ] Só lembretes pessoais; eventos compartilhados são push (T-023)
- [ ] Testes (unit do cálculo de horários) e roteiro manual

# ADR 0005 — Ciclo de vida da assinatura e transferência de ownership

**Status:** accepted (itens marcados "proposta" aguardam confirmação)

**Contexto:** a Play Store liga a assinatura à conta Google que comprou e não a transfere.

**Decisão:**
- Cancelar renovação não congela: a Family segue `active` até `expiresAt` (+ grace/account hold). Avisos antes.
- Sem transferência ao expirar → `frozen` (somente leitura, imposto pelas Rules) por 90 dias → exclusão, com avisos.
- Transferência = convite ao membro; ele assina com a própria conta; o backend valida a compra e troca o ownership; a Family volta a `active`. O owner também pode reassinar e desfazer o `frozen`.
- Exclusão de conta do owner bloqueada enquanto houver outros membros.
- **Aprovado:** se ao expirar só existe o owner e ≤ 1 casa, downgrade automático para Free em vez de `frozen`.
- **Aprovado:** plano reduzido com uso acima do novo limite → período de regularização (proposta: 30 dias) com modo restrito (só remover membros/casas); sem regularizar → `frozen`.
- Free: histórico dos últimos 7 dias. Timezone: tarefa guarda o fuso de criação, UI exibe no fuso do aparelho.

**Consequências:** precisa de jobs agendados (Blaze), validação server-side de compra (Play Developer API) e estados explícitos na Family. Ver `docs/specs/data-model.md` §4.

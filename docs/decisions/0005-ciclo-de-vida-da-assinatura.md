# ADR 0005 — Ciclo de vida da assinatura e transferência de ownership

**Status:** accepted (itens marcados "proposta" aguardam confirmação)

**Contexto:** a Play Store liga a assinatura à conta Google que comprou e não a transfere.

**Decisão:**
- Cancelar renovação não congela: a Family segue `active` até `expiresAt` (+ grace/account hold). Avisos antes.
- Sem transferência ao expirar → `frozen` (somente leitura, imposto pelas Rules) por 90 dias → exclusão, com avisos.
- Transferência = convite ao membro; ele assina com a própria conta; o backend valida a compra e troca o ownership; a Family volta a `active`. O owner também pode reassinar e desfazer o `frozen`.
- Exclusão de conta do owner bloqueada enquanto houver outros membros.
- **Proposta:** se ao expirar só existe o owner e ≤ 1 casa, downgrade automático para Free em vez de `frozen`.

**Consequências:** precisa de jobs agendados (Blaze), validação server-side de compra (Play Developer API) e estados explícitos na Family. Ver `docs/specs/data-model.md` §4.

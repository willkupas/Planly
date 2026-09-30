# ADR 0003 — Family como unidade de plano; Household como unidade de conteúdo

**Status:** accepted (supersede brainstorm seções 9, 46, 88–89, onde a Casa era a unidade de cobrança)

**Contexto:** a cobrança deve ser por "família", e o pagante pode ter várias casas e convidar pessoas a casas específicas.

**Decisão:**
- **Family** = plano/cobrança e pessoas; um owner (quem paga). Usuário: no máximo 1 Family Free; N pagas; pode ser membro de outras.
- **Household** = tasks/lists/activity; pertence a uma Family.
- Limites por plano (Free 1 pessoa/1 casa; Família 4/3; Família+ 8/ilimitado) vêm do `Entitlement` e são aplicados no backend.
- Membro só acessa casas às quais foi vinculado (`access` no doc da casa). Roles: família `owner|member`; casa `admin|member`.

**Consequências:** toda autorização passa por membership + acesso à casa. Detalhes em `docs/specs/data-model.md`. Preços podem mudar sem alterar o app (limites vivem no entitlement).

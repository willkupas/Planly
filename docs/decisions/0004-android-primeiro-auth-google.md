# ADR 0004 — Android primeiro; apenas Google Sign-In (extensível)

**Status:** accepted

**Decisão:** foco em Android; iOS e Apple Sign-In ficam para a Fase 3. MVP autentica só com Google. `AuthRepository` abstrai o provedor para adicionar e-mail/senha, Apple etc. sem refatorar. Autorização nunca usa e-mail; usa UID → membership → role.

**Consequências:** emulador precisa de imagem com Google Play Services. `applicationId` = `app.with.planly` (flavors `.dev`/`.staging`). Região `southamerica-east1`; i18n via ARB desde o início (pt-BR padrão).

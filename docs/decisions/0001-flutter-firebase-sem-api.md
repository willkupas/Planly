# ADR 0001 — Flutter + Firebase, sem API própria no MVP

**Status:** accepted

**Contexto:** produto mobile para famílias, barato de operar, precisa escalar sem administrar servidores. Brainstorm: `docs/00-brainstorm/AnaliseInicial.md` (seções 3, 26–28, 86).

**Decisão:** app em Flutter (Dart, Material 3, Riverpod, GoRouter). Backend 100% Firebase (Auth, Firestore, Functions 2nd gen, FCM, App Check, Crashlytics, Analytics, Remote Config). Sem API própria/.NET no MVP; Cloud Functions faz o que o cliente não pode fazer (convites, limites, billing, notificações, jobs).

**Consequências:** sem servidor para manter; custo proporcional ao uso; acoplamento ao Google Cloud. Functions na nuvem exigem plano Blaze (dev local usa emuladores). Uma API própria só entra se surgirem painel admin, integrações ou billing complexo.

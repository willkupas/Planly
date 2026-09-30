---
id: T-029
title: Qualidade, segurança e performance
status: todo
plan: 0003
depends_on: [T-028]
area: app
parallel_ok: true
---

## Critérios de aceite
- [ ] Custo do Firestore: medir leituras/escritas por fluxo no emulador, revisar listeners e queries (todas com `limit`), dimensionar budget alerts reais
- [ ] Performance: tempo de abertura, scroll de listas longas, consumo de bateria dos lembretes; perfilar com DevTools em release
- [ ] Acessibilidade: TalkBack, contraste, tamanhos de fonte, alvos de toque ≥ 48dp, rótulos semânticos
- [ ] Revisão de segurança (`/security-review`) e varredura de dependências (`flutter pub outdated`, `npm audit`)
- [ ] App Check: registrar Play Integrity (SHA-256 de release) e **ligar o enforcement** em Firestore e Functions 👤
- [ ] Crashlytics: forçar crash de teste em release (staging) e validar símbolos; Analytics sem PII
- [ ] Testes de carga leve do servidor (concorrência de convites/criação) e de dois aparelhos reais (roteiro `docs/testing/offline-dois-clientes.md`)
- [ ] Revisar mensagens de erro, estados vazios e textos pt-BR; preparar i18n de novos idiomas (somente ARB)
- [ ] Todos os requisitos mínimos M1–M13 de `docs/security.md` verificados e marcados

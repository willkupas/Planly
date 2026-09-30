---
id: T-030
title: Publicação na Google Play
status: todo
plan: 0003
depends_on: [T-029]
area: docs
parallel_ok: false
---

## Pré-requisitos (👤)
Conta de desenvolvedor Google Play (US$ 25, taxa única), identidade verificada, domínio/página para a política de privacidade.

## Critérios de aceite
- [ ] **Assinatura de release** com Play App Signing; chave de upload fora do repositório (segredo fora do git); `key.properties` local e no CI via secrets
- [ ] Build de release (`flutter build appbundle --flavor prod`), ofuscação (`--obfuscate --split-debug-info`) e símbolos guardados fora do repo
- [ ] SHA-1/SHA-256 da chave de upload e da assinatura da Play cadastrados no Firebase (Google Sign-In) e no App Check
- [ ] **Política de privacidade** e **termos de uso** publicados (LGPD: dados coletados, exclusão de conta, Analytics/Crashlytics) — requisito M12
- [ ] Formulário **Data safety** e classificação de conteúdo; declaração de uso de permissões (notificações; sem alarme exato)
- [ ] Listing: nome, descrições pt-BR, ícone, feature graphic, screenshots
- [ ] Teste interno → fechado → produção, com checklist de regressão manual (lembretes, dois aparelhos, compra)
- [ ] Monitoramento pós-lançamento: Crashlytics, budget alerts, painel de custos

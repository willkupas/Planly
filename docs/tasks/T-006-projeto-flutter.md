---
id: T-006
title: Criar projeto Flutter (Android)
status: done
plan: 0001
depends_on: [T-004]
area: app
parallel_ok: false
---

## Objetivo
Projeto base rodando no Android com `applicationId` `app.with.planly`.

## Critérios de aceite
- [x] Estrutura `lib/` feature-first conforme CLAUDE.md
- [x] Material 3, Riverpod, GoRouter
- [x] i18n com ARB (pt-BR padrão), sem texto fixo
- [x] `flutter analyze` e `flutter test` passando
- [x] APK debug compila e abre no emulador `planly_pixel`

## Notas
- Requer NDK 28.2.13676358 instalado manualmente: `android sdk install "ndk/28.2.13676358"` (o `sdkmanager` novo não instala sozinho pelo Gradle).
- `android/gradle.properties` tem `kotlin.incremental=false`: projeto em `D:` e pub-cache em `C:` quebravam o cache incremental do Kotlin.
- Entry points por flavor (`main_dev/staging/prod`) ficam para a T-007.

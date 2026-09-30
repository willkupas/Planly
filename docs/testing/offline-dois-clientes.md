# Offline e sincronização com dois clientes

Cobre o principal risco do projeto (sincronização + offline, brainstorm §73/§92). Duas partes:
o **roteiro manual** (dois aparelhos/emuladores) e o **teste automatizado**
`integration_test/offline_two_clients_test.dart` (dois `FirebaseApp` contra o Emulator Suite).

## Como o app se comporta (resumo)
- Escritas de conteúdo (tarefas, listas, itens) são **otimistas**: o efeito local é imediato e a
  linha fica com o ícone de relógio ("Aguardando sincronização") enquanto `hasPendingWrites`.
- Indicador de sync na AppBar: **Salvo neste dispositivo** (pendente e offline) -> **Sincronizando…**
  (pendente e online) -> **Sincronizado** (some após ~2 s). Faixa "Sem conexão" quando não há rede.
- Se o servidor **recusar** uma escrita já enfileirada (ex.: família congelada enquanto o aparelho
  estava offline), o SDK do Firestore **desfaz o efeito local** (não existe "item fantasma" para manter
  na lista). O app registra a falha no `WriteFailureCenter` (`lib/core/sync/write_failure_center.dart`):
  aparece a faixa vermelha "N alterações não foram sincronizadas" com **Ver** (descrição de cada uma,
  motivo e **Descartar** / **Descartar tudo**) e um snackbar para a mais recente. "Descartar" só dispensa o
  aviso, porque o dado local já voltou ao estado do servidor; para repetir a ação, o usuário refaz.
- Operações **só-online** (bootstrap, criar/renomear/excluir casa, acessos, convites, remover/sair de
  família) checam a conectividade antes: offline mostram "Sem conexão. Verifique sua internet e tente de
  novo." e nunca travam (botões continuam habilitados).
- Erro de Rules que chega **dentro de 2 s** volta ao chamador (snackbar da própria ação); erros que chegam
  **depois** (offline) vão para o canal central.

## Conflito last-write-wins (LWW)
O Firestore resolve **por campo**, e o app só envia os campos que mudaram:

| Situação | Resultado |
|---|---|
| A conclui (`status`, `completedAt`, `completedBy`) x B edita o título | as duas mudanças ficam (campos disjuntos), em qualquer ordem |
| A e B editam o **mesmo** campo (título) | vence a escrita que chegar **por último ao servidor** (não a que foi feita por último no relógio) |
| A conclui x B reabre sobre o mesmo estado | vence a última aplicada pelo servidor (`status` e `completedBy` juntos, pois vão no mesmo update) |

Testado sem emulador em `test/lww_conflict_test.dart` (patches reais do `FirestoreTaskRepository`
aplicados em sequência) e com Rules reais em `offline_two_clients_test.dart`.

## Roteiro manual (dois aparelhos/emuladores)
Pré-requisitos: dois emuladores Android (ou um aparelho + um emulador) com o flavor `dev` apontando para o
Emulator Suite (ver `docs/testing/integracao-emulador.md`; em aparelho físico use `--dart-define=EMULATOR_HOST=<IP do PC>`),
seed rodado (`node integration_test/seed/seed.mjs`). Como não há Google real no emulador, use duas contas do
seed na mesma casa (ex.: *dono* no aparelho A e *ana* no B, ambos na casa "Principal"), ou duas contas Google
de teste em um projeto `dev` real.

### Cenário 1 (crítico): A online / B offline cria tarefa -> B volta -> A recebe
1. A e B logados, ambos no Dashboard da mesma casa. Indicador mostra "Sincronizado" e some.
2. **B:** ative o modo avião. Aparece "Sem conexão — alterações ficam salvas neste dispositivo".
3. **B:** `+` -> "Comprar pão" -> ✓. A tarefa aparece na hora, com o relógio, e o indicador mostra
   **Salvo neste dispositivo**. O app não trava.
4. **A:** confirme que "Comprar pão" **não** aparece (esperar ~10 s).
5. **B:** desligue o modo avião. Indicador vai para **Sincronizando…** e depois **Sincronizado**; o relógio some.
6. **A:** "Comprar pão" aparece sozinha (sem recarregar), sem relógio. Aba Atividade de A mostra "criou a tarefa".
7. Repita com lista: B offline adiciona item "Leite" em uma lista -> reconecta -> A recebe o item.

### Cenário 2: conflito concluir x editar título (campos diferentes)
1. A e B online, com a tarefa "Regar plantas" criada por **B** (autor) visível nos dois.
2. **B:** modo avião; edite o título para "Regar plantas (varanda)". Fica pendente (relógio).
3. **A:** conclua "Regar plantas" (online).
4. **B:** volte a rede. Esperado nos dois: tarefa **concluída** e título **"Regar plantas (varanda)"**.

### Cenário 3: conflito no mesmo campo
1. Mesma preparação. **B:** offline, renomeia para "Versão B". **A:** online, renomeia para "Versão A".
2. **B:** volta a rede. Esperado: os dois terminam com **"Versão B"** (a última escrita a chegar ao servidor vence).

### Cenário 4: escrita recusada ao sincronizar
1. Conta de B é membro de uma família **congelada** (seed: "Família Congelada", conta *ana*). Troque para ela.
   (Em produção: o owner cancelou e a família congelou enquanto B estava offline.)
2. **B:** modo avião e crie uma tarefa (aparece com relógio; a UI de criação some quando a família já está
   congelada no cache, então provoque com a família ainda ativa e congele pelo console do emulador/Admin).
3. **B:** volte a rede. Esperado: a tarefa **desaparece**, surge a faixa "1 alteração não foi sincronizada",
   **Ver** mostra "Criar tarefa “…”" com "Você não tem permissão para fazer isso." e **Descartar** remove o aviso.

### Cenário 5: logout com escritas pendentes
1. **B:** modo avião, crie uma tarefa, Configurações -> Sair. Aparece "Alterações não sincronizadas".
2. **Cancelar** mantém a sessão; **Sair mesmo assim** sai, descarta o cache local e vai ao login.
   A tarefa **não** chega ao servidor (é descartada junto com o cache).

### Cenário 6: operações só-online offline
Com B offline: criar casa, renomear casa, gerar convite, remover membro, abrir fluxo de convite.
Esperado: mensagem "Sem conexão…" imediata, botões ainda habilitados, nenhum spinner infinito.

## Teste automatizado (não roda no CI padrão)
`integration_test/offline_two_clients_test.dart` (4 testes: cenário crítico, LWW em campos diferentes, LWW no
mesmo campo, escrita offline recusada em família congelada). B é um segundo `FirebaseApp` ("clientB"), com Auth e
cache próprios; A é o app padrão. Exercita os repositórios reais e as Rules reais; não usa a UI.

```powershell
# emuladores de pé (ver integracao-emulador.md) e o emulador Android ligado
.\integration_test\run_emulator_tests.ps1 -Test integration_test/offline_two_clients_test.dart
```
O script roda o seed (que zera Auth/Firestore) e passa `SEED_FAMILY`, `SEED_H1`, `SEED_FROZEN` etc.
por `--dart-define`. Reexecutar exige novo seed (o script já faz).

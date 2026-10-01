# Política de Privacidade — RASCUNHO

> **Rascunho técnico, sem validade jurídica.** Revisar com advogado/DPO antes de publicar (T-030).
> Itens entre `[colchetes]` dependem de decisão do dono do produto. Descreve o que o app faz hoje
> (código do repositório); atualizar sempre que mudar a coleta de dados.

**Controlador:** WITH [razão social, CNPJ, endereço]. **Contato (LGPD/encarregado):** [e-mail].
**Vigência:** [data]. **App:** Planly (`app.with.planly`).

## 1. Dados que coletamos
| Dado | Para quê | Base legal (LGPD) |
|---|---|---|
| Nome, e-mail e foto da conta Google | Identificar você e mostrar quem fez o quê na casa | Execução de contrato |
| Identificador único (UID) | Controle de acesso às famílias e casas | Execução de contrato |
| Idioma e fuso horário do aparelho | Exibir horários e textos corretamente | Execução de contrato |
| Conteúdo que você cria: casas, tarefas, listas, itens, histórico de atividade | Prestar o serviço e compartilhar com os membros que você autorizar | Execução de contrato |
| Dados de plano e assinatura da Família [quando houver billing] | Liberar limites do plano | Execução de contrato |
| Token de notificação push (FCM) [quando houver push] | Enviar avisos de eventos compartilhados | Execução de contrato |
| Relatórios de falhas (Crashlytics) e métricas de uso (Analytics), **somente na versão de produção** | Corrigir erros e melhorar o app | [Legítimo interesse / consentimento — decidir] |

Não coletamos localização, contatos, câmera, microfone nem dados financeiros (o pagamento é feito pela Google Play).

## 2. Com quem compartilhamos
- **Membros da sua família/casa:** veem o conteúdo das casas às quais você foi vinculado, com seu nome e foto.
- **Google (Firebase e Google Play):** operadores que armazenam e processam os dados (autenticação, banco de dados,
  funções, notificações, falhas, métricas, cobrança). Região do banco: São Paulo (`southamerica-east1`).
- Não vendemos dados nem os usamos para publicidade.

## 3. Por quanto tempo guardamos
- Enquanto sua conta existir. Casa excluída: removida definitivamente após 30 dias.
- Família congelada por falta de pagamento: somente leitura por 90 dias; depois é excluída.
- Plano Free: histórico de atividade visível por 7 dias [definir retenção real].
- Backups e logs: [definir].

## 4. Seus direitos (LGPD, art. 18)
Acesso, correção, portabilidade [definir se haverá exportação], eliminação, informação sobre compartilhamento e
revogação de consentimento. **Excluir conta:** Configurações → Excluir conta (apaga seus dados e anonimiza seu nome
no histórico das casas de outras pessoas). Outros pedidos: [e-mail do encarregado].

## 5. Segurança
Comunicação criptografada, regras de acesso por família/casa verificadas no servidor, App Check, sem armazenamento
de senhas (login via Google). Nenhum sistema é 100% seguro; em caso de incidente relevante, comunicaremos a ANPD e os
titulares conforme a lei.

## 6. Crianças
O app não é direcionado a menores de [13/18] anos. [Decidir política para menores em famílias.]

## 7. Mudanças
Avisaremos no app sobre mudanças relevantes nesta política.

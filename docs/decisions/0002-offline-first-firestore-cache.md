# ADR 0002 — Offline-first via cache persistente do Firestore

**Status:** accepted

**Contexto:** o app deve funcionar sem internet e sincronizar sozinho. Brainstorm seções 5–7, 33–34, 85.

**Decisão:** usar a persistência offline do Firestore SDK como banco local e mecanismo de sync. Não usar JSON como banco nem criar fila/sync próprios. Armazenamento local extra (preferências, onboarding) só em SharedPreferences (Hive/Isar só se necessário). Dados mutáveis ficam em documentos separados (ex.: itens de lista) para reduzir conflitos; conflito = last-write-wins.

**Consequências:** escrita de conteúdo é client-direct e funciona offline. Operações que dependem do servidor (criar família/casa, convites, limites) exigem internet — o primeiro acesso é online. Timestamps críticos usam `serverTimestamp`. UI precisa indicar estado de sync.

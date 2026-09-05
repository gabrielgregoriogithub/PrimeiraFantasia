# Warrior_V3 concept — provenance

Data: 2026-09-05 (America/Sao_Paulo)

## Ferramenta e método

- Ferramenta: OpenAI built-in raster image generation (`image_gen`), modo edit/identity-preserve.
- Input principal: `warrior_v3_master.png` inicial, arquivado em `rejected/warrior_v3_master_initial.png`.
- Contrato antes da geração: `WARRIOR_V3_DESIGN_LOCK.md`.
- Método escolhido: uma única geração multiângulo, seguida por duas edições localizadas e extrações condicionadas pela mesma folha.
- Normalização final: composição determinística em canvas 1536×1536, altura visual de 1200 px e ground line Y=1360.
- Nenhuma API key foi usada ou registrada.

## Simplificações canônicas

- Pouches: removidos; quantidade final zero.
- Correia diagonal: removida porque a direção traseira não permaneceu coerente; quantidade final zero.
- Cinto: um único cinto horizontal com fivela frontal.
- Scarf: gola vermelha e exatamente uma cauda curta posterior esquerda.
- Bracers: par espelhado.
- Calças: corte carvão simples, sem painéis extras.
- Botas: par espelhado com cuff, duas tiras de canela, tira de peito do pé e biqueira prata.

## Prompt da folha canônica

> Create ONE extra-wide clean sheet containing five full-body views of the SAME adult male Warrior_V3 in this exact left-to-right order: FRONT, BACK, LEFT PROFILE, RIGHT PROFILE, THREE-QUARTER FRONT. Every view uses identical scale, proportions, T-pose and ground line. Freeze the same blue sculpted hair, cream headband, one red scarf with exactly one posterior-left short tail, ivory shirt, brown jerkin, one waist belt, zero pouches, mirrored bracers, charcoal trousers and mirrored metal-toe boots. No weapons, props, UI or design variation.

O prompt completo também fixou números de camadas, paleta, materiais e exclusões descritos no Design Lock.

## Edições aceitas

1. Correção do `RIGHT PROFILE` para o lado ortográfico oposto ao `LEFT PROFILE`.
2. Remoção de todas as correias diagonais e suas pequenas fivelas em todas as vistas.
3. Extrações front/back/left/right condicionadas pela folha canônica.
4. Correção localizada da única cauda posterior esquerda no back.
5. 3/4 derivado do painel da mesma folha; versão individual limpa condicionada pela folha.
6. Promoção da frente canônica sem strap para `warrior_v3_master.png`.

## Imagens substituídas

- `warrior_v3_master.png`: master inicial com correia substituído pela frente canônica simplificada.
- `warrior_v3_front.png`, `back.png`, `left.png`, `right.png`, `3q_front.png`: gerações independentes anteriores substituídas por versões derivadas/condicionadas pela folha única.

## Rejeitadas

- `rejected/warrior_v3_turnaround_candidate_01.png`: LEFT e RIGHT apontavam para o mesmo lado.
- `rejected/warrior_v3_turnaround_candidate_02.png`: perfis corrigidos, mas correia traseira contradizia a frente.
- `rejected/warrior_v3_turnaround_candidate_03.png`: tentativa de correção da correia não resolveu o endpoint anatômico.
- `rejected/warrior_v3_back_candidate.png`: extração sem a cauda canônica do scarf.
- `rejected/warrior_v3_master_initial.png`: autoridade inicial preservada para auditoria; substituída pela simplificação aprovada.
- Uma tentativa de extração 3/4 foi bloqueada pela ferramenta (`moderation_blocked`, categoria `other`) e não produziu arquivo.

## Aprovadas

- `warrior_v3_turnaround_canonical.png`
- `warrior_v3_master.png`
- `warrior_v3_front.png`
- `warrior_v3_back.png`
- `warrior_v3_left.png`
- `warrior_v3_right.png`
- `warrior_v3_3q_front.png`

## Decisão

Todos os critérios do Visual QA do Stage 1 passaram. A folha canônica é a fonte multiângulo; o Design Lock resolve qualquer detalhe oculto por oclusão de perfil. Stage 1 pode ser marcado `DONE_AND_PRESENT`; Stage 2 permanece não iniciado nesta execução.

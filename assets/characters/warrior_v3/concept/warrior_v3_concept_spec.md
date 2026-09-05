# Warrior_V3 — concept specification

## Identidade

Jovem guerreiro aventureiro ágil, sério e confiante. O reconhecimento primário vem do cabelo azul volumoso, da faixa clara e do cachecol vermelho. A roupa comunica viagem e combate leve, não cavalaria pesada.

## Proporções

- 5 a 5,5 cabeças de altura.
- Cabeça moderadamente grande; tronco compacto e atlético.
- Ombros claros sem volume de armadura pesada.
- Mãos e botas ligeiramente ampliadas para leitura isométrica.
- Anatomia estilizada contínua e preparada para deformação esquelética.

## Paleta

| Elemento | Direção de cor |
|---|---|
| Cabelo | Azul profundo e saturado, highlights azul médio |
| Faixa | Creme/marfim claro |
| Cachecol | Vermelho vivo, sombra vinho |
| Couro principal | Marrom médio/quente |
| Couro secundário | Marrom escuro e caramelo |
| Calças | Carvão quase preto |
| Metal | Prata fosca/cinza claro |
| Pele | Tom quente natural |

## Materiais

- Blocos de cor pintados à mão e leitura soft-toon.
- Couro fosco com variação ampla, sem microtextura dependente de close-up.
- Tecido com roughness alta.
- Metal fosco com highlights controlados; evitar plástico e PBR hiper-realista.

## Peças de roupa

- Túnica/jerkin de couro marrom em grandes painéis.
- Camisa clara de manga curta sob o couro.
- Um único cinto horizontal largo; nenhuma correia diagonal e nenhum pouch.
- Bracers/luvas sem dedos em couro.
- Calças carvão soltas o suficiente para uma silhueta limpa.
- Botas robustas marrons com biqueira e pequenos reforços metálicos.

## Hair design

Massa azul forte composta por mechas grandes, pontudas e sobrepostas. A silhueta deve ser reconhecível de frente, costas e perfil. Evitar fios finos, massa amorfa ou mudança estrutural entre vistas.

## Scarf design

Cachecol vermelho espesso em volta do pescoço, com cauda curta e controlada para não interferir no rig. Deve continuar visível nos quatro lados, sem virar capa longa.

## Prioridades de silhueta

1. Cabelo azul e cabeça/faixa.
2. Cachecol vermelho separando cabeça e torso.
3. Ombros e T-pose limpos para reconstrução/rig.
4. Tronco compacto com camadas largas de couro.
5. Botas grandes e estáveis.

## Exclusões explícitas

- Knight/paladin, armadura de placas pesada, realismo, proporção de 7–8 cabeças.
- Chibi extremo, voxel, primitives, boneco de brinquedo ou placeholder.
- Espada, escudo ou qualquer objeto preso às mãos/corpo.
- Texto, UI, cenário, partículas e iluminação dramática.

## Notas para geração do modelo

- `WARRIOR_V3_DESIGN_LOCK.md` e `warrior_v3_master.png` são as autoridades visuais primárias.
- O master final é a vista frontal promovida da folha canônica, sem correia diagonal ou pouches.
- `warrior_v3_turnaround_canonical.png` congela front/back/left/right/3q na mesma geração.
- As vistas individuais derivam da folha canônica por extração condicionada e normalização determinística.
- Manter braços realmente separados do torso, mãos abertas, pernas separadas e botas inteiras.
- Não inferir espada ou escudo; serão assets independentes.

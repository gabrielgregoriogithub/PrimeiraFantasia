# Port de referência — Guardian Monsters (lucidtanooki)

Rascunhos GDScript baseados em partes do código-fonte real de
https://github.com/lucidtanooki/guardian_monsters (licença de código: Apache 2.0).
Repo original é Kotlin/libGDX; aqui é uma tradução manual de conceito, não um
"copy-paste" mecânico. Nenhum arquivo aqui é chamado pelo jogo — são
referência/rascunho para vocês decidirem o que vale integrar.

## O que é fiel ao original

- `ability_board.gd` — porta quase 1:1 a estrutura `Node`/`Edge`/`AbilityGraph`
  de `GuardianMonsters/guardians/.../abilities/{Node,Edge,AbilityGraph}.kt`:
  um grafo de nós (tipo EMPTY/ABILITY/EQUIPMENT/METAMORPHOSIS, estado
  DISABLED/ENABLED/ACTIVE) onde ativar um nó habilita os vizinhos.

## O que é inspirado, não copiado

- `element_system.gd` — a lista dos 13 elementos vem literalmente de
  `Element.kt` (`NONE, EARTH, FIRE, WATER, AIR, FOREST, DEMON, LINDWORM,
  FROST, SPIRIT, MOUNTAIN, ARTHROPODA, LIGHTNING`). **A matriz de
  fraquezas/resistências NÃO existe no código-fonte deles** — o
  `ElementSystem.md` do repo é só uma nota de design incompleta (fala em 5
  elementos: Água, Fogo, Terra, Ar, Energia) que nunca bateu com o enum
  implementado, e o multiplicador elemental (`ε` na fórmula de dano) não tem
  implementação encontrada no código público. A matriz incluída aqui é uma
  proposta minha, só usando os 13 nomes deles como vocabulário.

## O que NÃO portei (e por quê)

- **Fórmulas de stat (`StatCalculator.kt`)**: modelo Pokémon-like (nível +
  valor comum da espécie + valor individual "genético" + valor de
  crescimento + fator de personalidade). O jogo de vocês (`units.gd`) usa
  elenco fixo por partida (Guerreiro, Arqueiro, Mago...) sem sistema de
  nível/EXP nem "espécie vs indivíduo". Portar essa fórmula agora criaria
  um sistema órfão sem nada para alimentá-lo. Se um dia adicionarem
  progressão de personagem entre partidas, aí sim faz sentido revisitar.

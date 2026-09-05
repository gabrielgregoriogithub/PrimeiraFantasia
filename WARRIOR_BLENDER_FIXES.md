# Warrior — correções que exigem Blender

## High

1. Fazer revisão visual quadro a quadro de `Attack_Light_A/B/C`. Confirmar contato, interseção espada–corpo e uma pose de impacto forte. Remover da rotação qualquer variante inferior.
2. Revisar `Death_A` junto a quatro orientações. O corpo não reage a paredes; a Action precisa usar uma queda compacta para minimizar clipping no tabuleiro.
3. Adicionar sockets reais `SwordBase` e `SwordTip` ao rig/exportação. O trail atual acompanha a arma, mas não amostra a lâmina inteira.

## Medium

1. Revisar foot planting de Walk/Run em curvas de 90° e 180°.
2. Melhorar o lançamento de `Skill_ThrowSword`: hoje a coreografia existe, mas a espada rígida permanece na mão enquanto o projétil 2D existente viaja.
3. Conferir silhuetas de `Skill_PowerAttack`, `Skill_Whirlwind` e `Skill_Defend` na escala real de 192 px.

## Low

1. Refinar secondary motion de ombreiras/cinto sem adicionar física exportada.
2. Avaliar uma segunda Death somente depois da decisão de pipeline.

Nenhuma alteração de proporção, armadura ou estilo deve ser feita sem aprovação artística.

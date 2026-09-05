# Proveniência de assets e referências

## Cutscene de abertura "A Vila em Chamas" (2026-08-26)

`assets/cutscenes/scene_0.jpg`, `scene_1.jpg`, `scene_2.jpg` — as 3 ilustrações da cutscene de abertura (Guerreiro fugindo com o porco / encontrando o Arqueiro ferido / avançando contra o Troll), extraídas dos `data:image/jpeg;base64,...` embutidos em `assets/cutscenes/a_vila_em_chamas.html` (arquivo HTML fornecido pelo próprio usuário, mantido no repositório só como referência histórica — não é mais usado pelo jogo, ver `scenes/intro_cutscene.gd`). Precisaram de `godot --import` pra gerar os `.import`, já que foram criadas fora do editor.

Última auditoria: 2026-08-25 (expansão do Vale de Lua/Horda pra 26x22 — revisão 4, substitui as revisões 1/2/3 abaixo; cenário renomeado de "Cachoeira" pra "Horda" e câmera travada numa janela fixa de 13x13, sem zoom/arrastar — ver `LUA_VALLEY_CROP_ORIGIN` em `scenes/board_view.gd`)

## Legend of Lua

O cenário Vale de Lua adapta a composição da tela inicial do repositório local `legend-of-lua-main`: vale gramado, curso d'água, árvores e abertura rochosa. A licença original permanece no repositório de referência.

### Revisão de qualidade do cenário (2026-08-24)

A implementação anterior desenhava o Vale de Lua com formas vetoriais cruas
(`draw_rect`/`draw_colored_polygon`/`draw_circle`: montanha como triângulo
cinza, árvore como círculo verde, água como retângulos independentes por
tile, boca de caverna como círculo liso) e mantinha uma cachoeira animada já
pronta (`_draw_waterfall()`, com espuma e lâminas de fluxo, usando
`assets/tiles/waterfall.png`) como código morto, nunca chamada. Nenhum asset
real do próprio projeto era reaproveitado apesar de já existirem no
repositório. Correção: `scenes/board_view.gd` agora usa exclusivamente arte
real interna do projeto (nenhum arquivo de `legend-of-lua-main` foi copiado
— a referência local serviu só de inspiração de composição, conforme já
descrito acima):

| Elemento do Vale de Lua | Asset real usado | Técnica |
|---|---|---|
| Grama base | `assets/tiles/grass.png` (mesma textura do Campo/Torre) | tile a tile, com variação sutil de tom por posição pra quebrar repetição |
| Montanha | `assets/tiles/mountain.png` | várias cópias sobrepostas cobrindo toda a massa bloqueada contígua (`_draw_lua_mountains`), com jitter determinístico por fileira — não estica 1 imagem sobre o bloco inteiro (deformaria) nem repete 1 cópia por tile de 64px (ficaria quadriculado) |
| Árvores (`lua-tree`) | `assets/tiles/tree1.png`…`tree5.png` (`BoardLayout.TREE_ART_VARIANTS`, mesmo conjunto do Campo) | variante sorteada por árvore em `_setup_lua_valley()` (autoload/game_state.gd), desenhada cheia no tile |
| Decoração de grama (`tower-grass`) | `assets/tiles/flower1.png`…`flower3.png` | antes reusava o piso de masmorra do SPD (`tiles_prison.png`) fora de contexto; agora usa flor real, escolhida por posição, nas 8 células já sorteadas por `_setup_lua_valley()` (irregular, não em grade) |
| Rio | mesma técnica de bandas/gradiente + brilho de correnteza do rio do Campo (`_draw_river_bands`, refatorada de `_draw_continuous_river`), agora reaplicada aos tiles de água REAIS do Vale de Lua via `_draw_lua_river()` — antes cada tile de água era um retângulo isolado | polilinha contínua nascendo logo acima do primeiro tile de água |
| Cachoeira | `assets/tiles/waterfall.png` (já existia no projeto, nunca usada) | `_draw_waterfall_at()` (renomeada/parametrizada de `_draw_waterfall()`) ancorada na nascente do rio, com lâminas de fluxo animadas e espuma que já existiam no código |
| Boca de caverna | procedural (sem asset dedicado no projeto) | duas elipses escuras + arco de pedra, no lugar do círculo liso anterior |

O traçado fixo do rio do Campo (`_draw_continuous_river`/`_river_curve_points`)
passou a só desenhar quando o cenário ativo é o Campo — antes ele era
desenhado por baixo em TODOS os cenários e só ficava escondido por acidente
(coberto pelo retângulo de grama cru do Vale de Lua ou pelo piso da Torre).

Também corrigido: `scenes/unit_token.gd` `_unit_is_on_water()` checava
apenas a lista fixa de água do Campo (`BoardLayout.TERRAIN_LAYOUT`), então o
ripple/overlay de "pé na água" nunca refletia corretamente o rio do Vale de
Lua (nem os poços da Torre). Passou a consultar o terreno real do
`GameState` do cenário ativo.

O fantasma coletável após a contagem de morte usa `sprites/ghost.png` e a animação idle 0/1 descrita por `GhostSprite.java`, o Fantasma Triste da primeira sidequest do Shattered Pixel Dungeon (GPLv3+).

### Reconstrução estrutural do layout (2026-08-24, revisão 2)

A revisão anterior desta seção (acima) descrevia a referência de forma vaga
("tela inicial... vale gramado, curso d'água, árvores e abertura rochosa")
sem ter de fato decodificado o mapa do Tiled — o layout resultante (montanha
como faixa vertical inteira na borda leste, x=9..12, y=0..12; rio como coluna
reta em x=5/6) não correspondia à composição real da referência.

Desta vez o mapa foi decodificado de verdade: `legend-of-lua-main/maps/test.lua`
é a cena carregada por `startFresh()` (`src/startup/data.lua:88`) ao começar
um jogo novo — não `menu.lua` (tilemap vazio, só usado como pano de fundo do
menu) nem os mapas em `_old*/` (não referenciados por nenhum caminho de
carregamento ativo). Os dois tilesets do mapa (`overworld.png`,
`Overworld-edit.png`, ambos em `maps/_tilesets/`) foram compostos
programaticamente por GID sobre a grade 38x22 do layer `Base`, reproduzindo a
imagem exata do cenário (script descartável, não versionado). O resultado:
bosque denso à esquerda, campo aberto ao centro-sul, um paredão rochoso
horizontal cobrindo a faixa superior-direita (não a borda leste inteira), uma
cachoeira caindo por uma brecha nesse paredão, alargando num lago que
bifurca ao redor de uma ilhota de grama antes de reconectar e sair do mapa.

Essa estrutura foi convertida para o tabuleiro 13x13 preservando as posições
relativas (queda a ~75% da largura, paredão do centro até a borda direita,
bosque nos cantos superior/inferior esquerdos, lago ocupando o quadrante
direito) — ver `_lua_valley_definition()` em `autoload/scenario_manager.gd`
pros arrays de tiles e o raciocínio de conversão de escala. `scenes/board_view.gd`
ganhou `_terrain_bounds_groups()` (componentes conexas, em vez de 1 bbox
global) porque o paredão virou 2 massas separadas pela brecha da cachoeira, e
`_draw_lua_mountains()` passou a empilhar cópias na horizontal (a massa
agora é larga-e-baixa, não mais uma coluna alta) em vez de na vertical.
`_draw_lua_river()` passou a preencher o lago/bifurcação tile a tile
(`_draw_lake_tile()`) em vez de só uma fita fina no meio — uma fita de
~1 tile de largura não cobre visualmente um trecho de água com várias
colunas de largura, o que deixaria tiles logicamente aquáticos com aparência
de grama.

### Port literal do tileset real (2026-08-24, revisão 3)

As revisões 1 e 2 acima **ainda não usavam nenhum arquivo de
`legend-of-lua-main`** apesar do texto da revisão 1 dizer o contrário —
`mountain.png`, `tree1.png`…`tree5.png`, `waterfall.png` e
`flower1.png`…`flower3.png` são os mesmos assets do Campo/Torre, só
reorganizados por código (`_draw_lua_mountains`, `_draw_waterfall_at`,
`_draw_cave_mouth` com `draw_ellipse_shadow` etc.). O resultado tinha a
composição certa mas a linguagem gráfica errada: montanha nevada genérica,
cachoeira como retângulo azul, água quadriculada, boca de caverna como
círculo preto — relatado pelo usuário e confirmado revisando o próprio
código.

Correção real desta vez: `data/lua_valley_layout.gd` guarda, célula a
célula, os GIDs exatos lidos de `legend-of-lua-main/maps/test.lua`
(layers `Base`+`Objects`, tileset `Overworld-edit.png`, `firstgid=1481`),
recorte de 13x13 tiles (colunas 15–27, linhas 0–12 do mapa de 38x22
original) que contém o paredão com a cachoeira, o lago contínuo, o tronco
caído, as pedras e as flores — a mesma composição da tela inicial, não uma
aproximação dela.

| Elemento | Arquivo copiado de `legend-of-lua-main` | Como é usado |
|---|---|---|
| Atlas de tiles | `maps/_tilesets/Overworld-edit.png` → `assets/tiles/lua_valley/overworld_edit_atlas.png` (licença MIT, Challacade LLC) | amostrado tile a tile via `draw_texture_rect_region` em `_draw_lua_valley_board()` (`scenes/board_view.gd`), usando os GIDs reais de `LuaValleyLayout.BASE_GIDS`/`OBJECTS_GIDS` |
| Paredão | gids 1926/1966/2006/2046 (parede) + 2170/2171/2210/2211/2250/2251/2209/2247/2284/2285 (borda da brecha) | bloqueiam movimento (`walls` em `_lua_valley_definition()`) |
| Boca de caverna | gids 1928 (topo) + 1968 (base) — os mesmos 2 tiles que no mapa original ficam na coluna 14 (fora do nosso recorte) substituindo parede lisa | reposicionados na coluna 2 do nosso recorte (linhas 5-6), mesma arte, só não a coordenada global exata — a cachoeira precisava do quadro cheio |
| Cachoeira (corpo) | gids 1739/1779/1819, cada um animando por 3 colunas adjacentes do próprio tileset (ciclo real gravado no Tiled, 100ms/frame) | `_lua_animated_gid()` troca o gid pelo frame atual antes de desenhar |
| Espuma na base | gids 1858/1859/1860, cada um ciclando por 3 linhas do atlas (200ms/frame, também gravado no Tiled) | idem |
| Lago | gids 1763/1764/1765 (borda esquerda/preenchimento/borda direita, com a franja branca serrilhada já desenhada no tile) | dá a margem orgânica sem nenhuma lógica de auto-tile nossa |
| Ondulações da água | `sprites/environment/wave.png` → `assets/tiles/lua_valley/wave.png` (17 frames de 16x16) | porta o comportamento de `src/environment/water.lua` (`spawnWater`): spawna 1 ripple numa célula de água aleatória em intervalo aleatório, `_update_lua_ripples()`/`_draw_lua_ripple()` |
| Tronco caído | gids 1684/1685/1686 (camada Objects, 3 tiles) | decorativo, caminhável |
| Pedra grande | gid 1689 | bloqueia (mesma lista `walls`) |
| Pedra pequena / flor | gids 1691/1963/1964 | decorativo, caminhável |

`_setup_lua_valley()` (`autoload/game_state.gd`) e `_lua_valley_definition()`
(`autoload/scenario_manager.gd`) foram reescritos pra consumir `walls`/`water`
derivados desses GIDs em vez das listas `mountains`/`trees` desenhadas à
mão. O type `"lua-mountain"` permanece em `BoardLayout.BLOCKING_TERRAIN_TYPES`
(bloqueia igual); `"lua-tree"` foi removido de lá (não existe mais como
type — as "árvores" da versão anterior eram só um placeholder, a
composição real desta cena não tem árvore grande no recorte escolhido).
O overlay de flor genérica (`tower-grass`, `flower1-3.png` do Campo) também
foi removido: a variação de grama agora vem dos próprios tiles do Legend of
Lua (gids 2696/2698/2736/2775/2817 etc., variantes reais do tileset) e a
flor real (gid 1963/1964) já está na posição exata do mapa original.

A grid lógica (`board_view.gd::_draw()`) passou a desenhar quase invisível
(`alpha 0.035`) em estado neutro e só volta a `0.15` quando algum destaque
de movimento/ataque/magia está ativo — antes desenhava sempre em `0.15`,
"dominando" qualquer cenário por baixo. Essa mudança é geral (Campo/Torre
também), não só da Horda.

### Expansão para 26x22 (2026-08-25, revisão 4)

O recorte 13x13 da revisão 3 ficava "apertado" (pedido do usuário) — usava só
uma fração do mapa real disponível. Substituído por um recorte bem maior,
26 colunas x 22 linhas (colunas 8–33, linhas 0–21 do `test.lua` original de
38x22, ou seja, a altura MÁXIMA real do mapa e quase toda a largura),
ampliando o mesmo trecho da revisão 3 com mais conteúdo real adjacente:
bosque de árvores à esquerda, a boca de caverna na posição ORIGINAL do mapa
(sem precisar mais da relocação artificial pro recorte 13x13 antigo — ver
`CAVE_MOUTH := {"x":6,"y":7}` em `data/lua_valley_layout.gd`), ilha de
grama, faixa arenosa e cerca ao sul.

**Metodologia de colisão mudou** nesta revisão: em vez de classificar cada
GID individualmente em famílias "bloqueia/água/decorativo" (abordagem frágil
— dois GIDs já foram classificados errado nas revisões anteriores, 1885 e
1691), `BLOCKED_MASK`/`WATER_MASK` em `data/lua_valley_layout.gd` vêm
diretamente da geometria real das layers de objeto "Walls"/"Water" do
`test.lua` original: o centro de cada célula da grade é testado contra os
retângulos dessas layers. É a mesma fonte de verdade que o próprio Legend of
Lua usa pra colisão, não uma tabela adivinhada. Tronco (log) e pedra grande,
que têm seus próprios retângulos de "Walls" no mapa original, também
bloqueiam por essa via (`FORCE_BLOCK_OBJ_GIDS`).

**`GameState` ganhou `board_width`/`board_height` dinâmicos** (antes só
existia a constante quadrada única `GameConstants.BOARD_SIZE=13`, usada em
`in_bounds()` e nos loops de alcance/área) — Campo e Torre continuam 13x13
(default), só a Horda usa 26x22, lido de
`"board_width"`/`"board_height"` no dicionário devolvido por
`_lua_valley_definition()` (`autoload/scenario_manager.gd`).

**Câmera (revisão 2026-08-25 — enquadramento fixo 13x13, cenário renomeado
"Cachoeira" → "Horda")**: 26x22 tiles a 64px = 1664x1408px, maior que a
janela de jogo de 13x13 tiles (832x832px) mostrada em tela. Entre a
expansão pra 26x22 e esta revisão, o jogo teve uma fase intermediária com
zoom manual (roda do mouse) e arrastar (botão direito) pra navegar o mapa
inteiro — removida por completo nesta revisão a pedido do usuário.
`scenes/board_view.gd` mantém uma `Camera2D` filha própria, mas agora
travada em zoom 1:1 sempre: pro Campo/Torre (13x13) fica centralizada na
viewport igual sempre foi; pra Horda, desloca-se pra `LUA_VALLEY_CROP_ORIGIN`
(canto superior esquerdo, em tiles, do recorte 13x13 já aprovado
visualmente antes da expansão — reconstituído a partir do deslocamento de
+6 colunas sofrido pela escada nessa expansão, ver comentário na constante).
Como o mapa 26x22 ainda é maior que essa janela, `scenes/main.gd` também
passou a envolver `board_view` num `Control` com `clip_contents=true`
(`_board_clip`, 832x832px) — sem isso a câmera sozinha deixaria vazar tiles
extras nas bordas da janela (a viewport do jogo, 920x1200, é maior que
832x832). Como a HUD (botões, log, painéis) vive numa `CanvasLayer` própria,
ela ignora tanto a câmera quanto esse corte automaticamente; só os popups de
orientação (`_position_facing_controls` em `scenes/main.gd`) precisavam
saber converter coordenada do tabuleiro pra pixel de tela levando a câmera
em conta — fazem isso via `get_viewport().get_canvas_transform()`.

A escada (`LADDER_TILES`, feature adicionada em paralelo por outra sessão de
trabalho neste mesmo projeto) foi realocada da coluna 5 do recorte antigo
pra coluna 11 do recorte novo, porque a coluna 5 agora cai dentro do bosque
à esquerda em vez de no paredão — mesmo papel (atalho vertical entre o platô
de cima e o chão de baixo), só reposicionada pra continuar cortando uma
passagem através de parede sólida de verdade.

## Rato, Cobra, Slime e Gnoll (Shattered Pixel Dungeon, GPLv3+)

Os quatro inimigos do Vale de Lua/Horda já usavam a spritesheet real do
SPD (`assets/third_party/shattered_pixel_dungeon/sprites/{rat,snake,slime,gnoll}.png`,
já vendorizada) mas `scenes/unit_token.gd` só recortava o quadro 0 como uma
imagem estática — nenhuma das quatro tinha walk/attack/death, e a morte caía
no tingimento cinza genérico. Revisão: `SPD_MOB_ANIMS` em `unit_token.gd`
porta os índices de frame, FPS e loop **exatamente** como definidos nos
construtores originais (lidos diretamente do clone de referência em
`../_reference/shattered-pixel-dungeon`), sem nenhum frame escolhido "no
olho":

| Inimigo | Classe original | Spritesheet | Frame | idle | walk/run | attack | death |
|---|---|---|---|---|---|---|---|
| Rato | `sprites/RatSprite.java` | `rat.png` (256×64) | 16×15 | `[0,0,0,1]` @2fps loop | `[6,7,8,9,10]` @10fps loop | `[2,3,4,5,0]` @15fps 1x | `[11,12,13,14]` @10fps 1x |
| Cobra | `sprites/SnakeSprite.java` | `snake.png` (256×16) | 12×11 | sequência longa ponderada (corpo baixo, ereto, lampejo de língua 2→3→2) @10fps loop | `[4,5,6,7]` @8fps loop | `[8,9,10,9,0]` @15fps 1x | `[11,12,13]` @10fps 1x |
| Slime | `sprites/SlimeSprite.java` | `slime.png` (128×32) | 14×12 | `[0,1,1,0]` @3fps loop | `[0,2,3,3,2,0]` @10fps loop | `[2,3,4,6,5]` @15fps 1x | `[0,5,6,7]` @10fps 1x |
| Gnoll | `sprites/GnollSprite.java` | `gnoll.png` (256×64) | 12×15 | `[0,0,0,1,0,0,1,1]` @2fps loop | `[4,5,6,7]` @12fps loop | `[2,3,0]` @12fps 1x | `[8,9,10]` @12fps 1x |

Detalhes preservados do original:
- **Idle contínuo de verdade**: os quatro respiram em loop indefinido
  enquanto parados (`_advance_spd_idle`, `_process()`), não uma pose única —
  igual ao SPD real, onde `idle` também é uma `Animation(loop=true)`.
- **Slime = fluido verde, não sangue vermelho**: `SlimeSprite.blood()` no
  original retorna `0xFF88CC44`; o flash de dano do Slime usa essa cor verde
  em vez do vermelho padrão (`_flash_hit`, `unit_token.gd`).
- **Sem clipe de "hit" dedicado**: nenhuma das quatro classes originais
  define uma animação própria de dano (`CharSprite.flash()` no SPD só pisca
  branco por 0,05s) — preservado: o hit continua usando apenas o flash +
  recuo já existentes em `_flash_hit`, sem inventar um clipe.
- **Morte não volta pro idle**: `hold_last=true` mantém o último quadro de
  `death` até o cadáver virar alma (contagem 3→2→1→0 já existente), igual ao
  `CharSprite.die()` original (não-loop, segura o quadro final).
- **Direção só por espelhamento**: nenhuma das quatro tem arte separada por
  direção no SPD (`CharSprite.turnTo()` usa flip horizontal) — mantido: o
  flip já existente por `facing.dx` é a única variação direcional.
- **Escala proporcional real preservada**: Rato/Gnoll têm 15px de altura
  nativa no SPD; Cobra (11px) e Slime (12px) são propositalmente mais baixos
  — os quatro agora compartilham o mesmo fator de escala calculado a partir
  dessa altura de referência (`SPD_MOB_SCALE_REFERENCE_HEIGHT`) em vez de
  serem normalizados pra uma altura idêntica, então o Gnoll lê visualmente
  como o maior/mais robusto do grupo sem deformar nenhum dos quatro.
- **Golpe → SFX correto**: `autoload/game_state.gd` `_tower_creature_templates()`
  não marcava o tipo de golpe (`swing`) das armas de Rato/Cobra/Slime, então
  todo impacto soava como corte genérico (`_play_attack_vfx`, `scenes/main.gd`).
  Mordida (Rato) e Picada (Cobra) agora usam `swing:"stab"` (perfuração,
  como o bote/mordida original), Pancada (Slime) usa `swing:"crush"`
  (esmagamento, mais pesado/úmido). Nenhum dano/acerto/crítico/IA foi
  alterado — só a categoria de som/VFX de impacto.
- **Nada de stats/IA/spawn alterado**: HP, dano, chance de acerto, evasão,
  probabilidades e turnos de spawn continuam exatamente como antes desta
  revisão — só a arte, a animação e o som de impacto foram tocados.

## Feedback audiovisual de combate

- SFX de combate copiados de `core/src/main/assets/sounds/` do Shattered Pixel Dungeon (GPLv3+): ataques de arco/besta, hits de flecha/corte/perfuração/esmagamento/magia, miss, parry, fogo, gás, gelo, raio, natureza, buffs/debuffs, explosão e morte.
- Fonte de combate `Kenney Pixel.ttf`, acompanhada por `KENNEY_LICENSE.txt`, usada com nearest filtering visual, outline escuro e animações por categoria.

## Política adotada

O Shattered Pixel Dungeon foi clonado somente como referência técnica em
`../_reference/shattered-pixel-dungeon`, fora da raiz importável do projeto
Godot. Somente os assets explicitamente relacionados abaixo foram
incorporados, junto da licença GPLv3+ e da proveniência correspondente.

O motivo é que o código e os assets principais são distribuídos sob GPLv3,
enquanto a tela de créditos lista amostras de áudio de terceiros em grupos
CC BY e CC0 sem estabelecer, dentro do repositório, uma correspondência
inequívoca entre cada crédito e cada arquivo final processado. Sem essa
rastreabilidade individual, a escolha segura é não copiar os arquivos.

| asset/componente do jogo | origem | referência examinada | licença da referência | autor | modificação realizada |
|---|---|---|---|---|---|
| Sistema de projéteis | implementação original deste projeto | `effects/MagicMissile.java`, `sprites/MissileSprite.java` | GPLv3 (não copiado) | Evan Debenham/Oleg Dolya; adaptação original do projeto | Trajetória vetorial, rotação e callback de chegada implementados em GDScript |
| Bola de fogo do Mago | Shattered Pixel Dungeon + composição Godot original | `effects/Fireball.java`, `effects/fireball-short.png`, `FlameParticle.java`, `BlastParticle.java`, `SmokeParticle.java` | GPLv3+ | Oleg Dolya / Evan Debenham | Spritesheet real de 24 frames a 24 FPS, nearest-neighbor; integrado a chama, fagulhas, fumaça, luz pulsante, cast e impacto em uma cena reutilizável |
| Relâmpago | desenho procedural original | `effects/Lightning.java`, `SparkParticle.java` | GPLv3 (não copiado) | referência não incorporada | Arco segmentado, brilho, ramificações e faíscas originais |
| Veneno | desenho procedural original | `Poison.java`, `PoisonParticle.java` | GPLv3 (não copiado) | referência não incorporada | Burst verde/roxo e partículas ascendentes originais |
| Ripple/splash | desenho procedural original | `effects/Ripple.java` | GPLv3 (não copiado) | referência não incorporada | Elipse expansiva, gotas e fade originais |
| Bomba/explosão | desenho procedural original | `items/bombs/Bomb.java` e variantes | GPLv3 (não copiado) | referência não incorporada | Silhueta alquímica, clarão, fragmentos e fumaça originais |
| Armadilha | desenho procedural original | `levels/traps/` | GPLv3 (não copiado) | referência não incorporada | Marcador integrado ao chão e animação de acionamento originais |
| SFX geral | síntese PCM procedural deste projeto | catálogo `core/src/main/assets/sounds` e `AboutScene.java` | referências mistas CC BY/CC0 | autores listados na tela de créditos do SPD; síntese original do projeto | Sons gerais produzidos em runtime; exceções SPD usadas diretamente são discriminadas em linhas próprias |
| SFX Bola de Fogo | Shattered Pixel Dungeon | `sounds/chargeup.mp3`, `sounds/zap.mp3`, `sounds/blast.mp3` | GPLv3; amostras de terceiros conforme créditos do SPD | Shattered Pixel Dungeon e contribuidores creditados em `AboutScene.java` | Transcodificados para PCM WAV: carga no cast, zap no lançamento e blast no impacto; pré-carregados uma vez pelo AudioEngine |
| Música | síntese PCM procedural já existente | organização regional/intensidade do SPD | música da referência não copiada | Cube Code na tela de créditos do SPD; composição do projeto preservada | Barramento separado e ducking curto em impactos fortes |
| Cachoeira e tiles preexistentes | protótipo anterior do próprio jogo | `assets/tiles/` | asset interno do projeto | projeto do usuário | Preservados; nenhum arquivo SPD substituiu esses assets |
| Status Queimando | Shattered Pixel Dungeon | `effects/particles/FlameParticle.java` | GPLv3+ | Oleg Dolya / Evan Debenham | Comportamento visual portado para GDScript: cor `#EE7722`, tamanho 4, vida 0,6 s, aceleração Y −80, encolhimento e burst inicial; regras de dano não copiadas |
| Status Queimando fiel | Shattered Pixel Dungeon | `sprites/CharSprite.java`, estado `BURNING`; `FlameParticle.java` | GPLv3+ | Oleg Dolya / Evan Debenham | Emissor literal a cada 0,06 s sobre o sprite; partícula simples #EE7722, tamanho 4, vida 0,6 s, aceleração Y −80, fade-in original e encolhimento. Fumaça e chama multicamada removidas apenas deste status |
| Chamas compartilhadas (Bola de Fogo/Queimando/Flecha de Fogo) | Shattered Pixel Dungeon | `FlameParticle.java`, `BlastParticle.java`, `SmokeParticle.java` | GPLv3+ | Oleg Dolya / Evan Debenham | Componentes visuais centralizados em `SpdFireParticles`: Flame usa #EE7722, 4 px, 0,6 s, aceleração −80; Blast usa 8 px, velocidade 32–64 e aceleração +50. Aplicados sem copiar regras de combate |
| Chama viva — adaptação Godot | Shattered Pixel Dungeon + extensão visual deste projeto | `FlameParticle.java`, `BlastParticle.java`, `SmokeParticle.java`, `MagicMissile.java`, `WandOfFireblast.java` | GPLv3+ | Oleg Dolya / Evan Debenham; adaptação Godot do projeto | Parâmetros físicos originais preservados; núcleo branco/amarelo, corpo #EE7722, ponta oscilante, transição para vermelho, emissão irregular, color/scale ramps, blend aditivo apenas no fogo e fumaça alpha foram acrescentados para legibilidade moderna |
| Flecha de Fogo — voo e impacto | Shattered Pixel Dungeon + projétil original do jogo | `FlameParticle.java`, `BlastParticle.java` | GPLv3+ | Oleg Dolya / Evan Debenham | Flecha lógica preservada; rastro temporal de Flame durante o voo e impacto próprio com flash aditivo, Blast radial, chamas residuais e cleanup automático |
| Propagação da Bola de Fogo e projéteis incendiários | Shattered Pixel Dungeon | `WandOfFireblast.java` (burst de 30 `BlastParticle` e fumaça nas células vizinhas), `MagicMissile.java` (pour de `FlameParticle`) | GPLv3+ | Oleg Dolya / Evan Debenham | Bola de Fogo propaga uma onda escalonada de chama/blast/fumaça em cada tile da área real; Flecha de Fogo e Tiro Explosivo recebem chama no lançamento, voo e impacto, em intensidades próprias, sem alterar área ou dano |
| SFX Queimando | Shattered Pixel Dungeon | `core/src/main/assets/sounds/burning.mp3` | GPLv3; amostras de terceiros conforme créditos do SPD | Shattered Pixel Dungeon e contribuidores creditados em `AboutScene.java` | Transcodificado para PCM WAV por compatibilidade com o Godot local; conteúdo sonoro preservado; reproduzido uma vez na aplicação com volume −5 dB |
| Gás tóxico do Xamã | Shattered Pixel Dungeon | `effects/specks.png`, frame `STEAM`; `ToxicGas.java`; `Speck.java` tipo `TOXIC` | GPLv3+ | Oleg Dolya / Evan Debenham | Sprite real reutilizado com nearest-neighbor; hardlight `#50FF60`, rotação 30°/s, vida aleatória 1–3 s e emissão curta sobre os tiles do cone |
| SFX gás tóxico | Shattered Pixel Dungeon | `core/src/main/assets/sounds/gas.mp3` | GPLv3; amostras de terceiros conforme créditos do SPD | Shattered Pixel Dungeon e contribuidores creditados em `AboutScene.java` | Transcodificado para PCM WAV por compatibilidade; tocado uma vez ao conjurar o cone venenoso |
| Atlas de ambiente da Torre | Shattered Pixel Dungeon | `core/src/main/assets/environment/tiles_prison.png` | GPLv3+ | Evan Debenham / contribuidores do Shattered Pixel Dungeon | Reutilizado como atlas 16×16 para pisos, paredes de pedra, portas, entrada, escada, estante e estátua/pilar |
| Atlas de ambiente do 2º Andar | Shattered Pixel Dungeon | `core/src/main/assets/environment/tiles_sewers.png` | GPLv3+ | Evan Debenham / contribuidores do Shattered Pixel Dungeon | Reutilizado como atlas 16×16 para diferenciar visualmente o cenário modular `tower_floor_2`, inspirado na família `SewerLevel` sem copiar um mapa pronto |
| Atlas de ambiente do 3º Andar | Shattered Pixel Dungeon | `core/src/main/assets/environment/tiles_halls.png` | GPLv3+ | Evan Debenham / contribuidores do Shattered Pixel Dungeon | Reutilizado no cenário modular `tower_floor_3` para pedra escurecida, estruturas internas e ambientação de calor/lava; o mapa é uma composição original |
| Música interna da Torre | Shattered Pixel Dungeon | `core/src/main/assets/music/prison_1.ogg` | Consulte GPLv3 e créditos musicais do SPD (Cube_Code) | Cube_Code, distribuída no Shattered Pixel Dungeon | Reutilizada em loop nos cenários internos `tower_floor_1`, `tower_floor_2` e `tower_floor_3`, com fade curto |
| Passo em pedra | Shattered Pixel Dungeon | `core/src/main/assets/sounds/step.mp3` | Consulte GPLv3 e créditos de amostras do SPD | Créditos de áudio consolidados em `AboutScene.java` | Transcodificado para PCM WAV 44,1 kHz estéreo; substitui o passo procedural somente na Torre |
| Disparo das varinhas | Shattered Pixel Dungeon | `core/src/main/assets/sounds/zap.mp3` | Consulte GPLv3 e créditos de amostras do SPD | Créditos de áudio consolidados em `AboutScene.java` | Transcodificado para `wand_zap.wav`; usado pelo Míssil Mágico e Raio de Gelo |
| Impacto mágico das varinhas | Shattered Pixel Dungeon | `core/src/main/assets/sounds/hit_magic.mp3` | Consulte GPLv3 e créditos de amostras do SPD | Créditos de áudio consolidados em `AboutScene.java` | Transcodificado para `wand_hit_magic.wav`; pitch aleatório original e multiplicador 1,1× no gelo |

Os visuais das duas varinhas não vêm de bitmap separado. Foram adaptados de
`effects/MagicMissile.java`, `items/wands/WandOfMagicMissile.java` e
`items/wands/WandOfFrost.java`: partículas brancas aditivas para Míssil
Mágico e `MagicParticle` azul `#88CCFF` para Gelo, com burst no impacto.

## Conteúdo ambiental adicional da Torre

| Uso | Arquivo SPD | Adaptação |
| --- | --- | --- |
| Rato, slime, cobra e gnoll | `sprites/rat.png`, `slime.png`, `snake.png`, `gnoll.png` | Primeiro frame dos atlas originais escalado com nearest filtering nos tokens e portraits |
| Vasos e poções | `sprites/items.png` | Regiões do pote de mel, pote quebrado e poções reutilizadas como objetos e drops |
| Matos | `environment/tiles_prison.png` / mapeamento `FLAT_HIGH_GRASS` | Tile de grama alta do SPD integrado ao chão da Torre |
| Córrego | `environment/water0.png` … `water4.png` | Cinco frames alternados no corredor esquerdo, preservando custo de água |

Todos permanecem sob os mesmos termos GPLv3+ e créditos do Shattered Pixel
Dungeon já documentados acima. As probabilidades, atributos e regras de
interação são adaptações específicas deste RPG tático.

## Referências legais consultadas

- `LICENSE.txt` do Shattered Pixel Dungeon: GNU GPL versão 3 ou posterior.
- Cabeçalhos das classes Java examinadas: Pixel Dungeon (2012–2015,
  Oleg Dolya) e Shattered Pixel Dungeon (2014–2026, Evan Debenham), GPLv3+.
- `AboutScene.java`: música creditada a Cube Code; amostras Freesound
  creditadas em grupos Creative Commons Attribution e Creative Commons Zero.
- `docs/recommended-changes.md`: recomenda preservar créditos e informações
  de licença em modificações/distribuições.

## Inventário de áudio da referência

Foram auditados os grupos de ataque, impacto, magia, ambiente, interface e
música. Entre os candidatos avaliados estavam `atk_crossbow`,
`atk_spiritbow`, `blast`, `burning`, `chargeup`, `gas`, `hit_arrow`,
`hit_magic`, `lightning`, `miss`, `ray`, `trap`, `water` e `zap`. Todos foram
rejeitados para cópia direta; seus papéis de mixagem serviram apenas como
referência para SFX procedurais originais.

## Biblioteca `props` — curadoria visual (2026-08-24)

Foi auditada recursivamente a biblioteca fornecida em
`../props` (4.188 arquivos). O inventário reproduzível, com caminho,
formato, dimensões, transparência e classificação, está em
`tools/props_audit/inventory.csv`; as pranchas por pack ficam na mesma pasta.

Os recursos efetivamente usados pertencem ao pack **Ultimate Fantasy RTS -
Aug 2022**, de Quaternius, licença **CC0 1.0**. Foram copiados dos PNGs
transparentes pré-renderizados, sem conversão dos modelos 3D e sem alteração
destrutiva:

- `Logs.png` → `assets/props/environment/field_logs.png` (Campo);
- `Resource_Rock_1.png` → `assets/props/environment/field_rock_1.png` (Campo);
- `Resource_Rock_2.png` → `assets/props/environment/field_rock_2.png` (Campo);
- `Resource_Rock_3.png` → `assets/props/environment/field_rock_3.png` (Campo);
- `Barrel.png` → `assets/props/tower/barrel.png` (Torre);
- `Crate.png` → `assets/props/tower/crate.png` (Torre);
- `Crate_Stack1.png` → `assets/props/tower/crate_stack.png` (Torre).

Fonte/licença incluída no pack original:
`Ultimate Fantasy RTS - Aug 2022/License.txt`, CC0 1.0 Universal,
modelos por @Quaternius (https://quaternius.com/).

Os demais packs foram inventariados, mas não importados em massa: em sua
maioria contêm modelos FBX/OBJ/GLTF/Blend, texturas UV/normal/roughness ou
imagens de preview, e não sprites 2D prontos coerentes com os mapas atuais.

### Escada caminhável da Horda

A passagem vertical da Horda usa `Ladder_long.obj` e
`Ladder_long.mtl`, do pack **Platformer Pack - Nov 2018** de Quaternius
(**CC0 1.0**). Os arquivos-fonte foram preservados em
`assets/props/waterfall/source/`; o modelo foi renderizado frontalmente,
com transparência e filtro nearest, em
`assets/props/waterfall/ladder_long.png`. A escada ocupa quatro células do
paredão e essas células são terreno caminhável no cenário.

### Casa/moinho e props da Vila (2026-08-25)

Substituídos os polígonos 2D desenhados à mão (`_draw_village_house`/
`_draw_village_mill` antigas) por sprites reais, a pedido do usuário, usando
o **Medieval Village MegaKit [Standard]** de Quaternius (**CC0 1.0**,
`props/Medieval Village MegaKit[Standard]/` na raiz do repositório, fora do
projeto Godot). Peças glTF necessárias (paredes, porta, janela, telhado,
chaminé, carroça, caixote, cerca, entulho) e as texturas PBR que elas
referenciam foram copiadas pra `assets/props/village/source/kit/` — só o
subconjunto usado, não o pack inteiro.

Pipeline de renderização (scripts descartáveis, não fazem parte do projeto):
cada casa/moinho foi montado como uma cena 3D própria (paredes + cantos
formando uma caixa 2x2, telhado por cima, porta/janela encaixadas no vão
recortado da parede) dentro de um `SubViewport` transparente com uma
`Camera3D` ortográfica elevada (~35-40° de inclinação, sem rotação lateral,
ecoando o ângulo já usado por `castle.png`/`mountain.png`), luz direcional +
preenchimento, e capturado via `SubViewport.get_texture().get_image().
save_png()`. **Renderização headless (`--headless`) trava indefinidamente
nesta máquina pra conteúdo 3D** (SubViewport nunca termina de renderizar) —
funciona normalmente rodando a janela real (`--path .` sem `--headless`), é
assim que os PNGs finais foram gerados. Resultado recortado (`get_used_rect`
+ margem) e salvo em `assets/props/village/`:

| Sprite | Peças do kit usadas | Arquivo |
|---|---|---|
| Casa (`village-house`) | `Wall_Plaster_Door_Flat` + `Door_1_Flat`, `Wall_UnevenBrick_Straight`/`_Window_Wide_Flat`, `Corner_Exterior_Wood`, `Roof_Wooden_2x1`, `Prop_Chimney`, `Floor_UnevenBrick` | `village_house.png` |
| Moinho (`village-mill`) | mesmas paredes/porta em pedra (`UnevenBrick`) num corpo de 2 andares + `Roof_Tower_RoundTiles` (escalado a 0.5) no topo | `village_mill.png` |
| Carroça / caixote / cerca / entulho (decoração) | `Prop_Wagon` / `Prop_Crate` / `Prop_WoodenFence_Single` / `Prop_Brick1`+`Prop_Brick2` | `village_wagon.png` / `village_crate.png` / `village_fence.png` / `village_rubble.png` |

**O kit não inclui nenhuma peça de moinho de vento** (sem pás/hélice/rotor —
só o kit de construção modular medieval). `village-mill` usa a torre de
pedra do próprio kit (2 andares + telhado cônico) como substituto mais
próximo disponível; as pás procedurais antigas (`_draw_village_mill`) foram
removidas junto com o resto do desenho vetorial, já que uma torre de pedra
com hélices de moinho não lia bem visualmente.

`board_view.gd::_draw_village_building` agora desenha esses sprites
encaixados (`_contain_rect`, preserva proporção sem esticar) dentro do
retângulo do prédio; fogo (`_draw_village_flame`) e a sombra elíptica
continuam procedurais por cima, sem mudança. Os quatro props soltos entraram
em `CURATED_PROP_TEXTURES`/`VILLAGE_PROP_MAX_DIM` (mesmo mecanismo não-
bloqueante de `field-logs`/`tower-barrel` etc.) e foram espalhados como
`decorations` extras em `_village_definition()` (`scenario_manager.gd`) só
pra dar mais vida estática ao cenário — não alteram `terrain_map`,
`blocked_tiles`, spawn nem nenhuma outra regra de jogo.

#### Revisão: casa/moinho trocados de pack (2026-08-25, mesmo dia)

Usuário considerou a casa/moinho acima (Medieval Village MegaKit) fracos
visualmente e pediu packs específicos pra cada um:

- **Casa (`village-house`)**: `Ultimate Fantasy RTS - Aug 2022` de
  Quaternius (**CC0 1.0**, `props/Ultimate Fantasy RTS.../PNG/`) já vem com
  ícones isométricos PRONTOS (mesmo ângulo elevado usado em todo o resto do
  jogo) — sem montagem 3D nenhuma dessa vez, só recorte direto de
  `Houses_SecondAge_{1,2,3}_Level1.png` pra `village_house_{1,2,3}.png`. As
  3 variantes ciclam pela ordem das casas em `buildings`
  (`_draw_village_board`/`_draw_village_building`, parâmetro `house_index`)
  pra não repetir a mesma casa 4x — o campo `"kind":"village-house"` em
  `scenario_manager.gd` continua único/genérico de propósito, porque
  `test_scenario_village.gd` conta por esse kind; a variante visual é
  escolhida só dentro de `board_view.gd`, não é um dado do cenário.
- **Moinho (`village-mill`)**: `Farm Buildings - Sept 2018` de Quaternius
  (**CC0 1.0**), `OBJ/TowerWindmill.obj` (+ `.mtl`, cores sólidas por
  material, sem textura nenhuma) copiado pra
  `assets/props/village/source/farm/` — desta vez com pás de moinho DE
  VERDADE (o pack anterior não tinha nenhuma peça de hélice/pá). Importante:
  `load("*.obj")` devolve um `Mesh` (`ArrayMesh`), não um `PackedScene` como
  glTF — precisa de `MeshInstance3D.new(); inst.mesh = load(...)` em vez de
  `.instantiate()`. Renderizado pelo mesmo pipeline em `SubViewport`
  (câmera ortográfica elevada, luz direcional + preenchimento, recorte por
  `get_used_rect()`), substituindo o `village_mill.png` antigo.

`village_house.png` (variante única antiga) e os textos que citavam
"Medieval Village MegaKit" pra casa/moinho foram removidos/atualizados;
os quatro props soltos (carroça/caixote/cerca/entulho) continuam do
Medieval Village MegaKit, sem mudança — só casa e moinho foram trocados.

### Mais props da Vila: celeiro, barquinho e peixes (2026-08-26)

Mesmo pipeline (`SubViewport` + `Camera3D` ortográfica + `MeshInstance3D`
com `mesh = load("*.obj")`, já que OBJ vira `Mesh` puro, não `PackedScene`):

- **Celeiro** (`village-barn`) e **barquinho** (`village-boat`, o menor do
  pack — `Boat.obj`, bem menor que `Lifeboat`/`BoatWSail`/etc.) do **Farm
  Buildings**/**Ships by @Quaternius** (ambos CC0), copiados pra
  `assets/props/village/source/{farm,ships}/`. O barco entra como
  `decorations` parado numa célula do rio (`_village_definition()`), o
  celeiro como decoração grande (`VILLAGE_PROP_MAX_DIM["village-barn"]=150`).
- **Peixe pulando a cada 5 turnos**: `Cute Fish Pack - Feb 2020` (CC0),
  4 espécies (`Koi`/`Goldfish`/`Tetra`/`Piranha`) renderizadas de PERFIL
  (câmera no eixo X, não Z — o modelo desses peixes fica de "nariz" ao
  longo de Z, então a câmera original de frente só mostrava os dois olhos).
  `board_view.gd::_update_village_fish_jump()`/`_draw_village_fish_jump()`
  sorteiam espécie e célula de água a cada múltiplo de `global_turn_count`,
  animando um arco parabólico (sobe, gira levemente, desce) de ~1,1s — só
  visual, não roda nenhuma regra de jogo nem precisa ser testado por GUT
  (mesmo critério das ondulações da Horda/chamas da Vila).

### Árvores da Floresta (novo cenário, 2026-08-26)

`Textured Stylized Trees - May 2020` (Quaternius, CC0). Diferente dos packs
anteriores, o `.mtl` do OBJ não referencia textura nenhuma (`Kd` cinza liso
— import via OBJ ficava todo branco). Usado o **FBX** em vez do OBJ, mas
mesmo assim o importador FBX do Godot não resolveu as texturas externas
(caminho absoluto da máquina do autor); o material chega com nome certo
("Bark"/"Tree_Leaves"/"Pine_Leaves"/"Birch_Bark"/"Birch_Leaves") só que sem
`albedo_texture`. Corrigido reatribuindo manualmente um `StandardMaterial3D`
por nome de material com o PNG copiado à mão pra
`assets/props/village/source/trees/` (`Tree_Bark.jpg`, `Tree_Leaves.png`,
`Pine_Leaves.png`, `Birch_Bark.png`, `Birch_Leaves_Green.png`) — e como as
folhas usam textura com alfa recortado (cartões de folha, não geometria
real), precisou `transparency = TRANSPARENCY_ALPHA_SCISSOR` +
`cull_mode = CULL_DISABLED` nesse material, senão o recorte aparecia como
losango preto opaco. Variantes usadas: `Tree_2` (frondosa), `Pine_3`
(conífera), `Birch_4` (bétula) → `assets/tiles/forest_tree.png`/
`forest_pine.png`/`forest_birch.png`, seguindo o mesmo mecanismo de
`terrain["art"]` que o Campo já usa pras próprias árvores
(`BoardLayout.TREE_ART_VARIANTS`) — só que com uma lista própria da
Floresta em `_forest_definition()`, sem alterar nada do Campo.

### Castelo e montanha do Campo trocados por imagens do usuário (2026-08-26)

`assets/tiles/castle.png` e `assets/tiles/mountain.png` substituídos por
artes fornecidas diretamente pelo usuário (não vêm de nenhum pack de
terceiros — recebidas como imagem anexada na conversa, redimensionadas com
`Image.resize(..., INTERPOLATE_LANCZOS)` antes de salvar porque
`board_view.gd` usa `texture_filter = NEAREST` e reduzir uma imagem grande
direto com nearest-neighbor pinça artefatos).

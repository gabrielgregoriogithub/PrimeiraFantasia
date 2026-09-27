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

### Obstáculos novos da Vila: cerca arrombada, barricada, ponte quebrada e casa em ruínas (2026-09-05)

Usuário pediu pra usar assets de "cidades: casas, estradas, terrenos, cercas,
pontes" dos repositórios `PokemonWorkshop/PokemonStudio`, `grunt-lucas/
porytiles`, `PokeAPI/sprites` e `nikouu/Pokemon-gen-2-style-tilemap`, com uma
imagem de referência (vila isométrica estilo Stardew/Sea of Stars) — pra
reforçar a Vila em chamas/destruída, com os novos elementos funcionando como
obstáculos de verdade (bloqueando movimento), não só decoração.

Antes de copiar qualquer arquivo, os 4 repositórios foram auditados (`gh`/
`WebFetch`, sem clone local):

| Repositório | Resultado da auditoria |
|---|---|
| `PokeAPI/sprites` | Sprites oficiais de criaturas Pokémon (Nintendo/Game Freak, copyright reservado) — nem o tipo de asset certo (sem casas/estradas/cercas) nem livre pra reuso. |
| `grunt-lucas/porytiles` | Só uma ferramenta CLI que compila tilesets — não tem nenhum asset gráfico no repositório. |
| `PokemonWorkshop/PokemonStudio` | Engine/editor de fangames com licença própria vinculada ao uso da IP Pokémon — não é uma licença que permita extrair arte pra outro projeto. |
| `nikouu/Pokemon-gen-2-style-tilemap` | MIT, arte própria do autor (recriação "legalmente diferente", não extraída do jogo) — mas são tiles GB Style de 8x8 (parede/piso/1 prédio único/path/grama/água), sem cerca nem ponte, e destoaria do estilo isométrico pré-renderizado que a Vila já usa. |

Nenhum dos 4 servia. Conforme decisão do usuário, substituídos por um pack
CC0 já da mesma família dos demais props da Vila (Kenney, como o
`fantasyTown_0.1` já presente em `../props/`, fora do projeto Godot):

`Fantasy Town` de Kenney (**CC0 1.0**, `props/fantasyTown_0.1/`,
`Models/GLTF format/*.glb`). Peças usadas, copiadas pra
`assets/props/village/source/fantasy_town/` (só o subconjunto usado, mesma
regra dos demais packs):

| Sprite novo | Peça(s) do kit | Kind | Bloqueia? |
|---|---|---|---|
| `village_fence_broken.png` | `fenceBroken.glb` (peça pronta, cerca com tábua solta) | `village-fence-broken` | Sim |
| `village_barricade.png` | `polesHorizontal.glb` (peça pronta, 2 postes + 2 travessas) | `village-barricade` | Sim |
| `village_bridge_broken.png` | `planksOpening.glb` (peça pronta, tabuleiro de madeira com buraco no meio) | `village-bridge-broken` | Sim |
| `village_house_ruin.png` | `wallWoodBroken.glb` + `wallBroken.glb` (2 paredes quebradas, madeira + pedra, montadas formando um V) | `village-house-ruin` (entra em `buildings`, não em `decorations`) | Sim (automático, mesmo mecanismo das demais `buildings`) |

Pipeline de renderização igual ao já usado pra casa/moinho/celeiro
(`SubViewport` + `Camera3D` ortográfica elevada + `DirectionalLight3D` key/
fill, script descartável não versionado): `GLTFDocument.append_from_file`
carrega cada `.glb` direto do caminho absoluto (não pelo `res://`, os arquivos
não estão na árvore importável do projeto), monta a composição, captura via
`SubViewport.get_texture().get_image()` e recorta com `get_used_rect()` +
margem. **Desta vez a renderização funcionou em `--headless`** pra consultar
geometria (`AABB`, sem rasterizar) mas **precisou de janela real (sem
`--headless`)** pra capturar pixel de verdade — em `--headless` o Godot usa
um rasterizador dummy que devolve textura vazia/lixo, não trava
indefinidamente como o registro anterior desta seção sugeria (Farm Buildings,
2026-08-25) mas também não renderiza nada visível.

`village-fence-broken`/`village-barricade`/`village-bridge-broken` entraram
em `CURATED_PROP_TEXTURES`/`VILLAGE_PROP_MAX_DIM` (mesmo mecanismo dos props
"decorativos" já existentes), mas — ao contrário deles — sua célula também é
somada a `blocked_tiles` por `_village_definition()` (`scenario_manager.gd`,
array `obstacles`), então bloqueiam movimento de verdade: barricada no meio
da estrada principal (7,6), trecho de cerca arrombado (5,7) e coto de ponte
na margem do rio onde a estrada encontra a água (10,7). `village-house-ruin`
entra como um quinto item de `buildings` (5,0, 2x2, canto livre a nordeste),
bloqueando pelo mesmo mecanismo automático das demais construções — não
precisou de nenhuma lista nova pra isso.

### Casas da Vila trocadas por pixel art pintado (2026-09-05, mesmo dia)

Usuário achou as 3 casas (`village_house_1/2/3.png`, recortes do pack
isométrico "Ultimate Fantasy RTS") fracas visualmente perto da imagem de
referência (vila em pixel art pintado à mão, telhado com textura de telha,
sombreamento rico, estilo "Sea of Stars"/Stardew Valley) e pediu mais
qualidade/vida nesse asset específico.

Substituídas pelo pack **"Pixel Art Fantasy Houses Top Down – Free Pack"**
de Luminous Dice (itch.io) — pintado à mão, telhado com textura de telha
real, várias variantes de corpo/telhado e até uma versão já danificada.
**Licença própria (não é CC0)**: uso livre em projetos pessoais/comerciais,
pode editar/remixar/recolorir, só não pode revender ou redistribuir os
arquivos (originais ou modificados) como pack de assets próprio; crédito
apreciado mas não obrigatório (texto completo em
`assets/props/village/source/fantasy_houses_pack/ReadMe.txt`, junto do PNG
original — mesma regra de proveniência dos demais packs).

O pack só vem em roxo (mais 3 variantes soltas de telhado em vermelho/azul/
verde, mas sem o corpo "sem telhado" correspondente pra recombinar). Em vez
de tentar remontar peça por peça, cada casa final foi recolorida por rotação
de matiz (HSV) só nos pixels do telhado roxo (faixa de matiz ~283°±40°,
saturação mínima 0.18 — exclui madeira/contorno preto/realce branco, que têm
matiz bem diferente ou saturação baixa), preservando saturação e valor
originais — o sombreamento pintado (dobras da telha, luz/sombra) sai intacto,
só a cor muda. Matiz-alvo de cada recolor amostrado das próprias peças de
telhado vermelho/azul/verde do pack (matiz médio real, não escolhido no
olho), pra bater com a paleta que o próprio artista já validou:

| Sprite | Peça de origem (`Fantasy_Houses.png`, retângulo em px) | Matiz roxo→alvo | Resultado |
|---|---|---|---|
| `village_house_1.png` | Casa de telhado grande em duas águas, `(10,316,236,276)` | 283.2°→202.5° (azul, igual à peça de telhado azul do pack) | Bate com o telhado azul-esverdeado da imagem de referência do usuário |
| `village_house_2.png` | Casa pequena de telhado em hangar, `(10,108,140,180)` | 283.2°→0.0° (vermelho, igual à peça de telhado vermelha do pack) | Variedade de cor entre as 3 casas |
| `village_house_3.png` | Casa-torre de 3 andares, `(170,12,140,292)` | 283.2°→156.5° (verde, igual à peça de telhado verde do pack) | Variedade de cor + silhueta mais alta/estreita |

Script de recolorização descartável (não versionado) usando PIL/numpy: máscara
por distância angular de matiz + `colorsys.hsv_to_rgb` pixel a pixel dentro da
máscara. Resolução nativa bem menor que os sprites antigos (140-236px de
largura contra ~350px) — proposital, dá o visual "pixel grande" de pixel art
de verdade em vez de um render 3D suavizado; `board_view.gd` já usa
`texture_filter = NEAREST` no nó inteiro, então o upscale fica nítido/
quadriculado, não borrado. Nenhuma mudança de código foi necessária além de
sobrescrever os 3 PNGs — `VILLAGE_HOUSE_TEXTURES`/`_contain_rect`
(`board_view.gd`) já lidam com qualquer resolução/proporção de origem.

## PORTO — novo cenário independente (2026-09-05)

Cenário jogável novo, pedido do usuário, inspirado na composição de
`cenario1.png` (vila costeira pintada: casa grande, praça de pedra, fonte/
monumento central, água com margem) — só como referência de COMPOSIÇÃO, sem
copiar pixel a pixel. Ver `ScenarioManager._porto_definition()`,
`GameState._setup_porto()`, `board_view.gd` (`_draw_porto_board`/`_draw_
porto_water`/`_draw_porto_fountain`/`_draw_battleable_debug`) e
`tests/unit/test_scenario_porto.gd`.

Assets novos, todos do **Kenney "Fantasy Town"** (CC0 1.0,
`props/fantasyTown_0.1/`, já usado antes pelos obstáculos da Vila — mesmo
pack, `.glb` copiados pra `assets/props/porto/source/fantasy_town/`):

| Sprite | Peça do kit | Kind | Uso |
|---|---|---|---|
| `porto_fountain.png` | `fountainRoundDetail.glb` (pronta) | `porto-fountain` | Fonte/monumento (landmark #2), 2x2 tiles, bloqueia. Brilho central é procedural (`_draw_porto_fountain`), não faz parte do PNG — ecoa o obelisco luminoso da referência sem copiar o desenho. |
| `porto_pier_deck.png` | `planks.glb` (pronta) | `porto-pier` (terreno estático, tile a tile) | Píer de madeira, 3 tiles, bloqueia (`battleable=false` pedido explicitamente mesmo parecendo superfície andável). |
| `porto_cart.png` | `cart.glb` (pronta) | `porto-cart` (prop curado) | Carroça de mercador perto do píer/praça, puramente decorativa (bloqueia por entrar em `blocked_tiles`, igual aos demais obstáculos avulsos). |

Casa grande (landmark #1) e demais props (cerca, barril, caixa, pedra de
margem, barco) **não precisaram de asset novo** — reaproveitam sprites já
existentes e já documentados nas seções da Vila acima:
`village_house_1.png` (via o mesmo mecanismo `buildings`/`_draw_village_
building` da Vila, kind genérico `"village-house"`, sem ciclar variante),
`village-fence`, `tower-barrel`/`tower-crate`/`tower-crate-stack`
(Ultimate Fantasy RTS, Quaternius CC0), `field-rock-1`/`field-rock-2`
(mesmo pack, já usados pelo Campo) e `village-boat` (Ships by @Quaternius,
CC0).

**Atualização (2026-09-06)**: reconstruído com recortes reais tirados PELO
USUÁRIO da própria imagem de referência (`porto/porto.png`, pasta fora do
projeto) — substitui o conjunto acima quase por inteiro. `porto_fountain.png`
e `porto_pier_deck.png` (Kenney) foram removidos do projeto; `porto_cart.png`
é o único asset 3D antigo mantido (sem equivalente no recorte pixel-art).
`_draw_porto_board()`/`_draw_porto_water()`/nova `_draw_porto_house()`
desenham sprite real esticado/tileado por célula em vez de `draw_rect`
procedural para praça e casa; os juncos da margem (`shore_tufts`) viram
sprite real em vez das linhas onduladas de antes.

**Atualização (2026-09-06, água)**: `porto_water.png` (recorte de
`porto/tile_35.png`) foi removido de novo — pedido do usuário, a água
precisava ficar "unida, igual o rio do Campo" em vez de blocos separados, e
o recorte por célula criava costura visível de tile em tile (a arte tem
mottling próprio que não alinha nas bordas). `_draw_porto_water()` voltou ao
gradiente procedural (varia suave por seno, sem repetição de padrão — zero
costura por definição) e ganhou uma margem/costa: uma linha traçada em CADA
aresta onde uma célula de água encosta em terra firme (checagem dos 4
vizinhos contra o próprio conjunto de tiles de água), cobrindo o formato
irregular real do PORTO (recorte do píer, bolsão isolado do canto) sem
precisar forçar o polyline fino de `_draw_river_bands` (pensado pra um rio
de 1 célula de largura, não uma costa larga como a do PORTO) por cima de uma
área errada.

| Sprite | Origem | Kind | Uso |
|---|---|---|---|
| `assets/props/porto/pixel/porto_house.png` | Recorte de `porto/tile_1.png` | `porto-house` | Casa grande (landmark #1), substitui `village-house`/`_draw_village_building` só neste cenário |
| `assets/props/porto/pixel/porto_fountain.png` | Recorte de `porto/tile_2.png` | — (const `PORTO_FOUNTAIN_TEXTURE`) | Fonte/monumento (landmark #2); brilho central continua procedural |
| `assets/props/porto/pixel/porto_cobblestone.png` | Recorte de `porto/tile_25.png` | — (desenhado direto por `_draw_porto_board`) | Piso da praça, substitui o cinza procedural |
| `assets/props/porto/pixel/porto_dock_plank.png` | Recorte de `porto/tile_21.png` | `porto-pier` (terreno estático) | Píer de madeira |
| `assets/props/porto/pixel/porto_fence.png` | Recorte de `porto/tile_6.png` | `porto-fence` | Cerca de madeira |
| `assets/props/porto/pixel/porto_barrel.png` | Recorte de `porto/tile_12.png` | `porto-barrel` | Barril avulso |
| `assets/props/porto/pixel/porto_barrel_stack.png` | Recorte de `porto/tile_52.png` | `porto-barrel-stack` | Pilha de barris |
| `assets/props/porto/pixel/porto_crate.png` | Recorte de `porto/tile_13.png` | `porto-crate` | Caixa |
| `assets/props/porto/pixel/porto_mossy_rock.png` | Recorte de `porto/tile_16.png` | `porto-mossy-rock` | Pedra musgosa de transição grama→água |
| `assets/props/porto/pixel/porto_boat.png` | Recorte de `porto/tile_23.png` | `porto-boat` | Barco ancorado, substitui `village-boat` só aqui |
| `assets/props/porto/pixel/porto_market_stall.png` | Recorte de `porto/tile_3.png` | `porto-market-stall` | Banca de mercado (landmark #3, cluster novo) |
| `assets/props/porto/pixel/porto_awning.png` | Recorte de `porto/tile_4.png` | `porto-awning` | Toldo do cluster de mercado |
| `assets/props/porto/pixel/porto_lantern_post.png` | Recorte de `porto/tile_5.png` | `porto-lantern-post` | Poste de lanterna |
| `assets/props/porto/pixel/porto_reeds_1.png`, `_2.png` | Recorte de `porto/tile_41.png`/`tile_43.png` | — (`shore_tufts` em `_draw_porto_board`) | Juncos da margem, 2 variantes |
| `assets/props/porto/pixel/porto_lilypad.png` | Recorte de `porto/tile_47.png` | `porto-lilypad` | Vitória-régia na água |

Pipeline de renderização idêntico ao já documentado (SubViewport + Camera3D
ortográfica + `GLTFDocument.append_from_file` carregando `.glb` por caminho
absoluto, recorte por `get_used_rect()`): **confirmado nesta sessão que
`--headless` funciona pra consultar geometria (AABB) mas usa um
rasterizador dummy que não produz pixels reais** — precisa de janela real
(sem `--headless`) pra capturar a imagem, o que já estava certo no registro
anterior desta seção (Vila, obstáculos), só a explicação da causa (dummy
rasterizer, não travamento) foi confirmada agora.

### Regras de terreno específicas do PORTO

Água comum (`"water"`) em todo cenário existente é andável a custo dobrado
(`GameState.water_step_cost`) — o usuário pediu água 100% intransitável só
no PORTO. Em vez de mudar essa regra global, a água do PORTO usa um type
**novo e exclusivo**, `"porto-water"`, somado a
`BoardLayout.BLOCKING_TERRAIN_TYPES` — bloqueia total, zero efeito sobre
`"water"` nos demais cenários (Campo/Vila/Vale de Lua/Torre continuam
exatamente como estavam). Dois outros types novos e exclusivos do PORTO
entraram na mesma lista pelo mesmo motivo (obstáculo próprio, não
reaproveitável): `"porto-pier"` (píer) e `"porto-blocked"` (casa/fonte/
cercas/barris/caixas/carroça — genérico, já que a arte desses vem de
`buildings`/`decorations`, não do terrain_map).

`GameState.is_battleable(x, y)` é um utilitário novo e genérico (funciona em
qualquer cenário, não só o PORTO): "battleable" neste projeto é sinônimo de
"não bloqueado pelo terreno" — não existe um modo exploração separado do
modo batalha aqui, todo tile andável já É um tile de batalha. Grama conta
como battleable por ausência de entrada em `terrain_map` (mesma convenção
de todos os `_setup_*` existentes).

`BoardView.debug_show_battleable` (default `false`, zero custo quando
desligado) é o overlay de QA temporário pedido pelo usuário: verde
translúcido em tile battleable+livre, vermelho no resto — ver
`_draw_battleable_debug()`.

**PVP**: `ScenarioManager.PORTO` entrou em `scenes/pvp_setup.gd:SCENARIO_IDS`
— escolhível no Modo PVP como qualquer outro cenário, sem nenhuma mudança em
`GameState.apply_pvp_scenario()` (já genérico o bastante). Fora de
`PHASE_ORDER` de propósito: não altera a progressão de fase da campanha.

**Atualização (2026-09-13, enriquecimento de decoração)**: pedido do
usuário — distribuir mais objetos ao redor do mapa, com maior concentração
no canto superior direito (que estava vazio), preservando casa/fonte/
estrada centrais intocadas. Assets novos fornecidos pelo usuário na pasta
`porto/` (fora do projeto): `tile_3/4/5.png` eram bytes idênticos aos já
importados `porto_market_stall/awning/lantern_post.png` (reaproveitados,
só ganharam mais 1-2 instâncias cada); `barril.png` é idêntico a
`porto_barrel_stack.png` (reaproveitado); `caixa.png`/`saco.png` eram
recortes novos e reais do mesmo spritesheet de referência (`tile_53.png`/
`tile_58.png`, confirmado por hash), importados como `porto_crate_2.png`/
`porto_sacks.png`. `arvore.png`/`luz.png`/`casa.png` vieram com um
checkerboard cinza/branco *rasterizado* como fundo opaco (não transparência
de verdade — export do usuário fora do pipeline do spritesheet), removido
por script (limiar de cor quase-neutra e clara) antes de importar como
`porto_tree.png`/`porto_lamp.png`/`porto_house_2.png`; este último
também foi reduzido de ~1400px pro maior lado ~500px (a fonte original era
desproporcional a qualquer uso em tile único).

| Sprite | Origem | Kind | Uso |
|---|---|---|---|
| `assets/props/porto/pixel/porto_tree.png` | `porto/arvore.png` (limpo) | `porto-tree` | Árvore, preenchimento de borda |
| `assets/props/porto/pixel/porto_lamp.png` | `porto/luz.png` (limpo) | `porto-lamp` | Poste com lanterna acesa + cerca baixa, variante de `porto-lantern-post` |
| `assets/props/porto/pixel/porto_house_2.png` | `porto/casa.png` (limpo, redimensionado) | `porto-house-2` | Segunda casa (landmark do canto superior direito), prop curado de tile único — não entra em `buildings` |
| `assets/props/porto/pixel/porto_crate_2.png` | `porto/caixa.png` = `porto/tile_53.png` | `porto-crate-2` | Caixa, variante de `porto-crate` |
| `assets/props/porto/pixel/porto_sacks.png` | `porto/saco.png` = `porto/tile_58.png` | `porto-sacks` | Par de sacos de estopa |

Todos os 5 registrados em `CURATED_PROP_TEXTURES`/`PORTO_PROP_MAX_DIM`
(`board_view.gd`) e posicionados via `obstacles` em
`ScenarioManager._porto_definition()` — mesmo mecanismo genérico já usado
por todo o resto do PORTO (bloqueiam via `blocked_tiles`, sem regra nova).

## DESFILADEIRO — novo cenário independente (2026-09-06)

Cenário jogável novo, pedido do usuário, inspirado na composição de
`cenario3.png` (desfiladeiro gelado: ravina central, ponte de pedra, neve,
monólitos/lápides inclinados, montanhas nevadas ao fundo) — só como
referência de composição/atmosfera, sem copiar pixel a pixel. Ver
`ScenarioManager._desfiladeiro_definition()`, `GameState._setup_
desfiladeiro()`/`maybe_trigger_desfiladeiro_wind()`, `board_view.gd`
(`_draw_desfiladeiro_board`/`_draw_desfiladeiro_chasm`) e
`tests/unit/test_scenario_desfiladeiro.gd`.

**Atualização (2026-09-06)**: reconstruído com recortes reais tirados PELO
USUÁRIO da própria imagem de referência (`desfiladeiro/desfiladeiro.png`,
pasta fora do projeto) — substitui inteiramente o conjunto Kenney/Quaternius
original abaixo. `_draw_desfiladeiro_board()`/`_draw_desfiladeiro_chasm()`
agora desenham sprite real (textura esticada/tileada por célula) em vez de
`draw_rect`/`draw_circle` procedural para neve, pegadas, ponte, canal de
gelo e paredão da ravina.

Assets novos:

| Sprite | Origem | Kind | Uso |
|---|---|---|---|
| `assets/tiles/snow_pine_1.png`, `snow_pine_2.png` | Recorte direto de `desfiladeiro/tile_5.png`/`tile_6.png` (fornecidos pelo usuário) | `"tree"` (`art` alterna entre os dois) | Árvore nevada, 2 variantes |
| `assets/props/desfiladeiro/desfiladeiro_monolith_1..4.png` | Recorte de `desfiladeiro/tile_7..10.png` | `desfiladeiro-monolith-1..4` | Lápide/monólito, obstáculo — 1 kind por instância, sem repetir arte |
| `assets/props/desfiladeiro/desfiladeiro_rock_1..4.png` | Recorte de `desfiladeiro/tile_15,16,21,22.png` | `desfiladeiro-rock-1..4` | Pedra nevada, obstáculo |
| `assets/props/desfiladeiro/desfiladeiro_crystal_rock.png` | Recorte de `desfiladeiro/tile_14.png` | `desfiladeiro-crystal` | Rocha escura com cristais azuis (canto da referência), obstáculo |
| `assets/props/desfiladeiro/desfiladeiro_bush_1..3.png` | Recorte de `desfiladeiro/tile_17,19,20.png` | `desfiladeiro-bush-1..3` | Arbusto seco na neve, puramente decorativo |
| `assets/props/desfiladeiro/desfiladeiro_snow_ground.png` | Recorte de `desfiladeiro/tile_11.png` | — (desenhado direto por `_draw_desfiladeiro_board`) | Textura de chão repetida em toda célula do tabuleiro |
| `assets/props/desfiladeiro/desfiladeiro_snow_footprints.png` | Recorte de `desfiladeiro/tile_12.png` | — (idem) | Substitui a neve lisa nas 4 células junto às duas bocas da ponte |
| `assets/props/desfiladeiro/desfiladeiro_bridge.png` | Recorte de `desfiladeiro/tile_4.png` | — (desenhado direto, esticado pro retângulo 4x2 da ponte) | Ponte de pedra com parapeito — vão do arco é TRANSPARENTE no PNG (ver atualização abaixo) |
| `assets/props/desfiladeiro/desfiladeiro_cliff_wall_1.png`, `_2.png` | Recorte de `desfiladeiro/tile_25.png`/`tile_26.png` | — (colunas x=4/x=7 da ravina, uma por lado, bloco vertical único) | Paredão rochoso nevado da ravina |

**Atualização (2026-09-07, geometria/rio)**: 3 pedidos do usuário resolvidos
juntos:
1. O corredor de 4 colunas da ravina não existe mais nas 3 primeiras linhas
   (y=0..2, faixa de céu) — `ScenarioManager._desfiladeiro_definition()`
   gera `chasm`/`bridge` só a partir de y=3 agora (antes cobria y=0..12
   inteiro, ficando escondido atrás do fundo de montanhas). `sky` cobre a
   largura INTEIRA (13 colunas) sem exceção pra essas 3 linhas.
2. `desfiladeiro_ice_channel.png` (recorte de `tile_18.png`, linha da
   tabela removida acima) foi descartado — as 2 colunas internas (x=5/x=6)
   agora são um RIO DE VERDADE, reaproveitando `_draw_river_bands()` (mesma
   função do Campo/Vale de Lua/Estrada Inverno) com um novo parâmetro
   opcional `width_scale` (default 1.0, sem efeito nos outros chamadores) —
   o rio do DESFILADEIRO passa `1.9` porque ocupa 2 células de largura, não
   1. Isso também resolve o pedido de "borda do penhasco como bloco
   vertical único": as colunas x=4/x=7 voltaram a ser só a arte da parede
   real repetida sem mistura de gradiente escuro por cima (removido).
3. O rio agora é UM traçado contínuo (y=3 até o fim do tabuleiro), sem cortar
   nas linhas da ponte — `_draw_desfiladeiro_chasm()` passou a ser chamado
   ANTES do `draw_texture_rect` da ponte (ordem trocada em `_draw_
   desfiladeiro_board()`), deixando o vão transparente do arco da ponte
   revelar o rio por baixo em vez da neve que aparecia ali antes.

Conjunto anterior (Kenney Fantasy Town CC0, mantido aqui só como histórico —
os arquivos abaixo foram removidos do projeto):

| Sprite | Origem | Kind | Uso |
|---|---|---|---|
| `assets/tiles/snow_pine.png` | Recolor de `assets/tiles/forest_pine.png` (já real do projeto, Quaternius CC0 — ver seção "Árvores da Floresta" acima) | `"tree"` (reaproveita o obstáculo já existente, só troca `art`) | Árvore nevada — folhagem levada pra um branco-azulado pálido preservando sombra/luz original (mesma técnica de rotação HSV das casas da Vila, mas em vez de girar o matiz, empurra pra perto do branco proporcional à saturação) |
| ~~`assets/props/desfiladeiro/desfiladeiro_rock.png`~~ | Kenney Fantasy Town (CC0), `rockLarge.glb` | ~~`desfiladeiro-rock`~~ | Removido — ver tabela acima |
| ~~`assets/props/desfiladeiro/desfiladeiro_monolith.png`~~ | Kenney Fantasy Town (CC0), `pillarStone.glb`, renderizado inclinado (13°) | ~~`desfiladeiro-monolith`~~ | Removido — ver tabela acima |

`snow_pine.png` (sem sufixo) continua no projeto: ainda é usado pela ESTRADA
INVERNO (ver seção abaixo).

### Regras de terreno e mecânica específicas do DESFILADEIRO

**Ponte**: retângulo lógico de 2 (espessura) x 4 (comprimento) tiles —
`ScenarioManager._desfiladeiro_definition()` gera isso varrendo as 4 colunas
da ravina (x=4..7) e reservando 2 linhas (y=5..6) como `"desfiladeiro-
bridge"` (battleable/walkable). Testado como retângulo de verdade (colunas
distintas == 4, linhas distintas == 2), não só a contagem total de 8.

**Ravina**: as mesmas 4 colunas da ponte, em TODAS as outras linhas, viram
`"desfiladeiro-chasm"` — bloqueia unidades terrestres, sobrevoável. Esse type
**não** entra em `BoardLayout.BLOCKING_TERRAIN_TYPES` (que bloquearia
voadores também); em vez disso, `GameState.compute_reachable`/`_can_unit_
anchor_at` ganharam uma checagem exclusiva pra esse type, seguindo o MESMO
padrão de exceção `u.get("flying", false)` que a função já usava pra
cadáver/ocupante inimigo/estrutura — não uma mecânica de voo nova só pra
Fantasma/Fada. `GameState.is_battleable()` (utilitário genérico, reaproveitado
do PORTO) também trata esse type como não-battleable, já que é uma pergunta
sobre o TERRENO em si (independe de que unidade específica esteja jogando).

**Vento gelado** (`GameState.maybe_trigger_desfiladeiro_wind`, chamado de
dentro de `begin_turn_for` a cada turno, fora do bloco `if not
pvp_custom_battle` — vale também no Modo PVP por ser hazard de mapa, não
roteiro): a cada 5 `global_turn_count` (mesmo contador que a Vila já usa pros
reforços dela), rola 80% de chance por unidade viva em campo e, se acertar,
aplica dano ambiental 1-3 (gelo) + a MESMA redução de agilidade do Cone de
Gelo do Mago — lida dinamicamente de `Spells.build()["iceCone"].
appliesSpeedReduction` (se o Mago for rebalanceado, o vento acompanha
automaticamente) — respeitando as mesmas regras de afinidade elemental já
existentes (`elementAffinity["ice"]`: imune/cura/dobra, e meio dano em
morto-vivo, os mesmos trechos que `resolve_single_hit` já usa). Não passa
pela mira/ângulo geométrico de um ataque de verdade (não faz sentido
flanquear o vento) nem consome CT/chama `finalize_action` — é hazard de
mapa, testado isoladamente (`test_wind_does_not_touch_ct_or_current_actor`).

Apresentação visual (pausa ~3s + tremor de câmera) reaproveita
`BattlePresentationController.present_event` (mesmo popup com letterbox já
usado por reforços/eventos de campanha) — ganhou um parâmetro `hold`
opcional (default 0.55s, preserva todo chamador existente) só pra permitir
a pausa mais longa pedida. `GameState.desfiladeiro_wind_events` é uma fila
"só visual" no mesmo padrão de `bone_explosion_events`/`bard_song_vfx_
events`, drenada por `main.gd:_sync_visuals()` — os efeitos (dano/status) já
foram aplicados de forma síncrona antes disso, então a apresentação nunca
bloqueia turn order/CT/AI/pathfinding.

**PVP**: `ScenarioManager.DESFILADEIRO` entrou em `scenes/pvp_setup.gd:
SCENARIO_IDS`, igual PORTO.

## ESTRADA INVERNO — novo cenário independente (2026-09-06)

Cenário jogável novo, pedido do usuário, inspirado na composição de
`cenario2.png` (trilha de terra clara cortando a neve, rio na borda
superior, platô elevado com pedras à direita) — sem copiar pixel a pixel.
Ver `ScenarioManager._estrada_inverno_definition()`, `GameState._setup_
estrada_inverno()`, `board_view.gd` (`_draw_estrada_inverno_board`/`_estrada_
inverno_river_points`/`_draw_estrada_inverno_stairs`) e `tests/unit/
test_scenario_estrada_inverno.gd`.

Asset novo (histórico):

| Sprite | Origem | Uso |
|---|---|---|
| `assets/tiles/bare_snow_tree.png` | Recolor de `assets/tiles/forest_pine.png` (real do projeto, Quaternius CC0) — folhagem apagada (alpha=0 nos pixels verdes) deixando só tronco/galhos, com leve geada nos galhos restantes | **Corrompido** (o color-key deixou fragmentos translúcidos em vez de um tronco limpo, visível abrindo o PNG). Nunca chegou a ser usado — ver atualização abaixo. |

Antes desta atualização, poço/pedras/barris/ossada reaproveitavam sprites
genéricos de outros cenários (`village-well`, `field-rock-1/2/3`,
`tower-barrel`, `corpse-bones-pile` do 2º Andar da Torre) e as árvores usavam
`snow_pine.png` (substituto do DESFILADEIRO, já que o recolor acima saiu
corrompido).

**Atualização (2026-09-06)**: reconstruído com recortes reais tirados PELO
USUÁRIO da própria imagem de referência (`estrada inverno/estrada
inverno.png`, pasta fora do projeto) — substitui os reaproveitamentos acima
por kinds/arts próprios do cenário. O chão de neve, a água e a trilha
CONTINUAM procedurais de propósito: os tiles equivalentes da pasta do
usuário são peças de autotile com borda irregular transparente (pensadas pra
composição vizinho-a-vizinho, não pra repetição lado a lado) — usá-las cru
por célula criaria uma grade visível de retalhos separados em vez de um chão
contínuo, então só os elementos "objeto isolado" (parede, árvores, poço,
pedras, barris, caveira) foram trocados.

| Sprite | Origem | Kind/`art` | Uso |
|---|---|---|---|
| ~~`assets/props/estrada_inverno/estrada_inverno_cliff_wall.png`~~ | Recorte de `estrada inverno/tile_18.png` | ~~`estrada-inverno-cliff`~~ | Removido — ver atualização abaixo |
| `assets/props/estrada_inverno/estrada_inverno_tree_1.png`, `_2.png` | Recorte de `estrada inverno/tile_26.png`/`tile_27.png` | `"tree"` (`art` alterna entre os dois) | Árvore seca/nevada, substitui `snow_pine.png` |
| `assets/props/estrada_inverno/estrada_inverno_well.png` | Recorte de `estrada inverno/tile_36.png` | `estrada-inverno-well` | Poço de pedra |
| `assets/props/estrada_inverno/estrada_inverno_rock_1..3.png` | Recorte de `estrada inverno/tile_29,30,31.png` | `estrada-inverno-rock-1..3` | Pedra nevada |
| `assets/props/estrada_inverno/estrada_inverno_barrel_1..2.png` | Recorte de `estrada inverno/tile_37,38.png` | `estrada-inverno-barrel-1..2` | Barril nevado |
| `assets/props/estrada_inverno/estrada_inverno_skull.png` | Recorte de `estrada inverno/tile_44.png` | `estrada-inverno-skull` | Caveira na neve, substitui `corpse-bones-pile` |

**Atualização (2026-09-13, chão de neve real + enriquecimento)**: pedido
explícito do usuário — a nota acima (chão procedural "de propósito", por
causa da borda irregular do autotile) foi revista: `_draw_estrada_inverno_
board()` agora desenha `assets/tiles/estrada_inverno_neve1.png` (recorte de
`estrada inverno/neve1.png` — já estava importado de uma tentativa anterior,
só nunca tinha sido ligado ao código de desenho) por célula via `draw_texture_rect`, EXATAMENTE
a mesma técnica já usada por `DESFILADEIRO_SNOW_TEXTURE`/`_draw_
desfiladeiro_board` (que tem a mesma borda irregular transparente e já
está em produção) — água e trilha continuam procedurais, não fazem parte
deste pedido. Também entraram 3 árvores a mais (`estrada_inverno_tree_3.png`,
recorte novo) e 9 props novos espalhados pelo mapa:

| Sprite | Origem | Kind | Uso |
|---|---|---|---|
| `estrada_inverno_tree_3.png` | `estrada inverno/arvore3.png` | `"tree"` (`art`) | 3ª variante de árvore seca/nevada |
| `estrada_inverno_log_1.png` | `estrada inverno/arvore4.png` | `estrada-inverno-log-1` | Tronco caído nevado |
| `estrada_inverno_log_2.png` | `estrada inverno/arvore6.png` | `estrada-inverno-log-2` | Tronco caído nevado, variante |
| `estrada_inverno_stump.png` | `estrada inverno/arvore5.png` | `estrada-inverno-stump` | Toco nevado |
| `estrada_inverno_snow_rocks_1/2.png` | `estrada inverno/tile_40.png`/`tile_41.png` | `estrada-inverno-snow-rocks-1/2` | Agrupamento de pedras nevadas |
| `estrada_inverno_snow_pebbles_1/2.png` | `estrada inverno/tile_42.png`/`tile_43.png` | `estrada-inverno-snow-pebbles-1/2` | Pedrinhas nevadas, menores |
| `estrada_inverno_snow_bush_1/2.png` | `estrada inverno/tile_45.png`/`tile_46.png` | `estrada-inverno-snow-bush-1/2` | Arbusto nevado |

Todos registrados em `CURATED_PROP_TEXTURES`/`ESTRADA_INVERNO_PROP_MAX_DIM`
(`board_view.gd`) e posicionados via `obstacles`/`trees` em
`ScenarioManager._estrada_inverno_definition()` — mesmo mecanismo genérico
já usado pelo resto do cenário (bloqueiam via `blocked_tiles`).

**Atualização (2026-09-06, morro/parede)**: pedido do usuário — "o morro onde
os inimigos estão começando" precisa ficar IGUAL ao morro da HORDA (Vale de
Lua). `estrada_inverno_cliff_wall.png` (recorte da referência do usuário,
tabela acima) foi removido; `_draw_estrada_inverno_cliff_tile()` (`board_
view.gd`) agora desenha os MESMOS GIDs reais do paredão de terra do mapa
original do Legend of Lua (`LuaValleyLayout.ATLAS_PATH`, GIDs 1926 de borda/
1966-2046 de continuação — os mesmos que compõem o paredão visível em
`_draw_lua_valley_board`), em vez de arte própria nova — mesma técnica de
`_draw_lua_atlas_tile`, só reindexando pela posição da célula dentro de cada
trecho da parede (a faixa da Estrada Inverno é mais alta que os 4 tiles
originais do recorte da Horda, então repete os 3 GIDs de "corpo" em vez de
parar em 4 linhas). A escada de acesso já reaproveitava o mesmo asset da
Horda (`LuaValleyLayout.LADDER_PATH`) antes desta atualização — só a parede
em si estava com arte própria, agora as duas partes usam a fonte real da
Horda.

### Água — reaproveitamento literal do rio do Campo (regra 7/8 do pedido)

A água daqui usa o **mesmo type `"water"`** já usado por Campo/Vila/Vale de
Lua/Torre — **sem type próprio**. Isso herda automaticamente todo o
comportamento existente sem duplicar nenhuma lógica:

- `GameState.water_step_cost`: custo de movimento dobrado (não bloqueia);
- `GameState.get_effective_hit_chance_breakdown`: -10pp atirando de dentro
  d'água, +10pp acertando alvo "atolado" na água;
- imunidade a pegar fogo (`resolve_single_hit`, `appliesBurn`);
- bypass total pra quem voa (`u.get("flying", false)`).

Testado explicitamente (`test_water_reuses_the_exact_same_type_and_mechanics_
as_field`) comparando o terrain type e o custo de movimento entre um tile de
água do Campo (`BoardLayout.TERRAIN_LAYOUT["water"]`) e um tile de água da
Estrada Inverno — são literalmente o mesmo comportamento.

O visual reaproveita a MESMA função `_draw_river_bands()` (bandas de
gradiente + brilho de correnteza) que o Campo (`_draw_continuous_river`) e o
Vale de Lua (`_draw_lua_river`) já usam — só com pontos próprios
(`_estrada_inverno_river_points`, cobrindo a borda superior em vez da coluna
central do Campo).

### Platô elevado — mesmo padrão estrutural da Horda (regra 9-13, 24)

Auditado como o Vale de Lua ("Horda") implementa sua área elevada: **não**
existe um sistema de "altura"/elevação numérica no motor (`elevation_map` é
só uma tabela auxiliar do Campo pra água/estruturas, não usada pelo Vale de
Lua) — o "platô de cima" da Horda é simplesmente terreno comum (sem type
especial) isolado topologicamente por uma parede sólida
(`"lua-mountain"`, bloqueia) com um único vão (`"lua-ladder"`, andável)
cortando essa parede.

A Estrada Inverno reaproveita EXATAMENTE esse padrão estrutural — parede
sólida + vão único de acesso —, mas com **types próprios**
(`"estrada-inverno-cliff"` bloqueia, `"estrada-inverno-stairs"` andável) em
vez de reaproveitar `"lua-mountain"`/`"lua-ladder"` diretamente: esses dois
já têm renderização em ATLAS bem específica do Vale de Lua
(`_draw_lua_valley_board`, GIDs de um tileset real portado do Legend of
Lua), sem nenhum parâmetro pra reaproveitar em outro formato de mapa —
reutilizar o type arriscaria interferir no render do cenário existente
("não altere os cenários existentes" era regra explícita do pedido). O
*padrão* foi 100% reaproveitado; só o *type/asset* de cada peça é próprio:

- Parede (`estrada-inverno-cliff`): mesmo asset visual `MOUNTAIN_TEXTURE`
  (`assets/tiles/mountain.png`, imagem do usuário) já usado pelo Campo.
- Escada (`estrada-inverno-stairs`): mesmo asset `ladder_long.png`
  (CC0, Quaternius/Platformer Pack — já vendorizado em `assets/props/
  waterfall/ladder_long.png`, ver seção "Escada caminhável da Horda" acima)
  e a mesma técnica de desenho de `_draw_lua_ladder` (textura esticada pelas
  N células da escada, sombra curta na base) — só parametrizada pros tiles
  próprios da Estrada Inverno em vez do array hardcoded do Vale de Lua.

`test_plateau_is_only_reachable_through_the_stairs` reconstrói o caminho
real até um tile do platô e confirma que ele sempre passa por uma célula de
"stairs" — a mesma garantia estrutural que a Horda já tem.

### Nota técnica: neve opaca em vez de translúcida nesta seção

Ao contrário do DESFILADEIRO (onde a neve translúcida por cima de terreno já
desenhado funciona bem), aqui a neve precisou ser **opaca**: o loop genérico
de terreno estático em `_draw()` desenha árvore/parede ANTES do código
específico do cenário rodar, e as duas artes (`bare_snow_tree.png`,
`mountain.png`) têm fundo transparente (não uma cor sólida) — neve
translúcida por cima só lavava a arte quase até sumir, e pular esses tiles
deixava a grama verde universal (primeira camada de `_draw()`) aparecer por
trás. A solução: pintar neve opaca em TODO tile primeiro, depois redesenhar
árvore/parede por cima (mesmas texturas que o loop genérico já ia usar, só
que depois da neve em vez de antes) — ver comentário em `_draw_estrada_
inverno_board`.

**PVP**: `ScenarioManager.ESTRADA_INVERNO` entrou em `scenes/pvp_setup.gd:
SCENARIO_IDS`, igual PORTO/DESFILADEIRO.

### Castelo e montanha do Campo trocados por imagens do usuário (2026-08-26)

`assets/tiles/castle.png` e `assets/tiles/mountain.png` substituídos por
artes fornecidas diretamente pelo usuário (não vêm de nenhum pack de
terceiros — recebidas como imagem anexada na conversa, redimensionadas com
`Image.resize(..., INTERPOLATE_LANCZOS)` antes de salvar porque
`board_view.gd` usa `texture_filter = NEAREST` e reduzir uma imagem grande
direto com nearest-neighbor pinça artefatos).

## TEMPLO e CEMITÉRIO — novos cenários independentes (2026-09-18)

Dois mapas verticais maiores que 13x13 (Templo 13x26, Cemitério 17x24), fora de
`ScenarioManager.PHASE_ORDER`, escolhíveis pelos botões TEMPLO/CEMITÉRIO do topo
e pela tela de cenários do PVP. Mesmo grid (`BoardView.TILE_SIZE` = 96), mesma
câmera (zoom/arrasto/barras de rolagem, `BoardView._update_camera`), mesmo
movimento/colisão (`GameState.compute_reachable`/`_can_unit_anchor_at`).

### Origem dos assets

| Pasta original (raiz do repositório) | Conteúdo | Destino no projeto |
|---|---|---|
| `templo/tile_1..60.png` | recortes com alpha da folha `ChatGPT Image ... 19_50_18.png` (pinheiros, ruínas, monólitos, arco, árvore rúnica, plataforma ritual, lagoa...) | `assets/props/templo/templo_<nome>.png` (60) |
| `cemitario/tile_1..50.png` | recortes com alpha da folha `ChatGPT Image ... 19_59_48.png` (lápides, cruzes, sarcófago, cripta, portão, estátuas, velas, lanternas, névoa...) | `assets/props/cemiterio/cemiterio_<nome>.png` (48) |
| `templo/templo.jpeg`, `cemitario/cemiterio.png` | imagens-guia de composição (NÃO são usadas como fundo) | — |

Nota: `cemiterio.png` (1024x1536, RGB opaco) é a **imagem-guia** da composição;
a folha de assets real é a "ChatGPT Image", que já vem recortada em `tile_N.png`.

Os originais nunca são alterados. `tools/import_scenery_tiles.py` (reexecutável:
`python tools/import_scenery_tiles.py --src ..`) copia cada recorte com nome
semântico, sem mexer em cores, contornos ou resolução dos pixels. Só faz:

1. remover fragmentos soltos de objetos vizinhos que vieram no recorte
   (componentes minúsculos, pedaços encostados na borda e retângulos listados em
   `DROP_RECTS`/`ERASE_RECTS`: caveira na névoa, resto de lanterna nas folhas,
   pedras/ilhota na lagoa, pontas de grade...);
2. dividir recortes que juntavam vários objetos: `tile_37` do cemitério (3
   árvores secas; a árvore do meio vem cortada pela vizinha e não é exportada) e
   `tile_24` (portão em duas metades, com o vão do caminho no meio, como na
   imagem-guia);
3. aparar a margem totalmente transparente (o pivô de desenho é a base do
   desenho visível).

Fora de escopo no Cemitério (pedido: sem templo/capela/altar/círculo ritual/runas):
`tile_23` (capela), `tile_39` (obelisco com runas), `tile_50` (círculo ritual).
As pedras do caminho não vieram nos recortes: são desenhadas proceduralmente
(`SceneryVisuals.Ground._draw_trail`) em paralelepípedos grandes, com a mesma
paleta cinza-azulada. O pacote do Templo não traz velas/lanternas: as runas
brilhantes (árvore e plataforma), a névoa e as partículas do bioma fazem a
atmosfera sobrenatural.

### Arquitetura

- `data/haunted_scenery.gd` (`HauntedScenery`): montador. Cada prop tem footprint
  (fw x fh células), sólido (`"wall"` bloqueia todos, `"prop"` bloqueia unidades de
  1 casa e é ignorado por unidades de 4 casas, `""` só visual) e camada (`"y"`
  ordenado por Y, `"flat"` decalque no chão). Não deixa sólido sobre caminho/spawns.
- `data/cemiterio_layout.gd`, `data/templo_layout.gd`: catálogo, caminhos (polilinhas
  rasterizadas em células), spawns e composição. Seed fixa: o mapa é igual em toda partida.
- `autoload/scenario_manager.gd`: `TEMPLO`, `CEMITERIO` (definição via os layouts).
- `autoload/game_state.gd` `_setup_haunted_scenery`: terrain_map a partir de
  `blocked_tiles` (`scenery-wall`/`scenery-prop`) e da água da lagoa; os times padrão
  nascem nos spawns (nenhuma unidade fixa). Cada slot inimigo tem 2x2 livres.
- `scenes/scenery_visuals.gd` (`SceneryVisuals`): apresentação. `Ground` (filho do
  BoardView com z_index -1: grama, caminho, decalques, vinheta; os destaques de
  movimento/ataque continuam por cima), `Prop` (z_index = linha dos pés; fica
  translúcido quando alguém está atrás), `Light` (brilho aditivo de velas/lanternas/runas),
  `Mist` (névoa à deriva).
- `data/board_layout.gd`: `scenery-wall`/`scenery-prop` em `BLOCKING_TERRAIN_TYPES`;
  `scenery-prop` em `LARGE_UNIT_PASSABLE_TERRAIN_TYPES`.
- Ferramentas: `tools/render_scenery_preview.tscn` (mapa inteiro num PNG) e
  `tools/scenery_ingame_check.tscn` (cena Main real, capturas dos 4 cantos, relatório
  de tokens/rolagem). Testes: `tests/unit/test_scenery_scenarios.gd`.

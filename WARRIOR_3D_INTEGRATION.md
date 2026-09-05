# Integração do Guerreiro 3D

## Asset e arquitetura

O GLB está em `res://assets/characters/warrior/warrior_animated_v1.glb`. A cena reutilizável é `res://scenes/characters/Warrior3D.tscn`, controlada por `warrior_3d.gd`.

O jogo existente é 2D. Para preservar grid, câmera, seleção, UI e ordenamento, somente o Guerreiro é renderizado em um `SubViewport` 3D transparente dentro do `UnitToken`. O sprite antigo permanece carregado e pode ser reativado com `use_3d_visual = false`.

## Orientação e escala

- O modelo olha para **-Z no Godot**.
- `VisualRoot` gira apenas no eixo Y.
- `model_scale` ajusta o tamanho sem modificar o GLB.
- O token continua centralizado pelo mesmo cálculo `BoardView.tile_center`/`TILE_SIZE` já existente.

## Animações

O `AnimationTree` cria uma state machine com Idle, Walk, AttackLight, AttackHeavy, Block, Hit, Death e Victory. Idle/Walk têm crossfade de 0,12–0,14 s; ações usam blends curtos de 0,06–0,12 s. Death nunca retorna a Idle.

Métodos públicos: `play_idle`, `play_walk`, `play_attack_light`, `play_attack_heavy`, `play_block`, `play_hit`, `play_death`, `play_victory`, `face_world_position` e `face_direction`.

`animation_speed_scale` permite ajuste em runtime. Movimento é in-place: o Node2D lógico/tween existente continua sendo a única autoridade do deslocamento.

## Impacto e gameplay

`attack_impact` é emitido no frame documentado do Blender: 10/30 s para AttackLight e 21/30 s para AttackHeavy. Markers de pose do Blender não viram automaticamente Call Method Tracks no Godot, portanto o timing configurado é o fallback determinístico.

O sinal não calcula dano. Fórmulas, crítico, accuracy, status, CT e HP continuam no `GameState`. A integração visual usa o fluxo já existente de VFX/feedback e evita criar um segundo resolvedor de dano.

## Movimento e feature flag

`UnitToken.animate_path` mantém um único Walk durante todo o caminho e retorna a Idle apenas no final. Cada mudança de trecho chama a rotação suave do modelo.

`@export var use_3d_visual := true` existe no `UnitToken`, mas só é aplicado quando `spriteKey == "guerreiro"`. Nenhum outro herói ou inimigo é convertido.

## Teste isolado

Abra `res://scenes/characters/Warrior3DTest.tscn` e execute a cena:

- 1 Idle
- 2 caminho A→B→C→D
- 3 AttackLight
- 4 AttackHeavy
- 5 Block
- 6 Hit
- 7 Death
- 8 Victory

Ataques olham para o dummy e imprimem `ATTACK IMPACT` no instante do evento.

## Performance e limitações

- O protótipo usa um SubViewport 192×192 somente para o Guerreiro. Se dezenas de unidades 3D forem adotadas, prefira uma viewport 3D compartilhada.
- A oclusão com paredes/árvores continua sendo o `z_index` 2D lógico. Não há depth buffer compartilhado entre CanvasItem e o SubViewport.
- A sombra 3D é simples; o marcador de seleção 2D original continua sendo a autoridade visual.
- Toon avançado/outline fica para um passe posterior; os materiais chapados do GLB já preservam a leitura cartoon.
- Campo, Vila e Torre reutilizam o mesmo `BoardView`/`UnitToken`, portanto a integração é comum às três cenas. A principal revisão manual pendente é a escala/offset visual em cada composição de cenário.

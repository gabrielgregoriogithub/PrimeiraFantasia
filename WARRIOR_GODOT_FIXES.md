# Warrior — correções no Godot

## Blocker para migração da pipeline completa

1. Definir uma estratégia de composição/oclusão. Cada Guerreiro é um SubViewport 3D transformado em Sprite2D; ele respeita `z_index` do token inteiro, mas não pode ser parcialmente ocultado pela geometria desenhada do mapa.

## High

1. Substituir o SubViewport por personagem por uma camada 3D compartilhada, ou provar com profiling em hardware-alvo que múltiplos render targets são aceitáveis.
2. Compartilhar materiais toon/outline. Atualmente cada instância cria materiais e 27 meshes de outline próprias.
3. Fazer capturas A/B reais em Campo, Vila, Torre e pisos vulcânicos; headless não valida contraste, clipping ou qualidade artística.

## Medium

1. Conectar Turn_Left/Right/180 à decisão angular de runtime; hoje as Actions existem, mas a rotação procedural continua sendo a principal autoridade.
2. Unificar timing visual de `throwSword` com o release do projétil 2D.
3. Adicionar preset de câmera/iluminação por bioma sem lights individuais por personagem.
4. Tornar materiais de VFX compartilhados e considerar pool somente se o profiler mostrar spikes.

## Low

1. Adicionar captura automática A/B no modo debug.
2. Melhorar o painel de métricas com GPU frame time numa build não-headless.

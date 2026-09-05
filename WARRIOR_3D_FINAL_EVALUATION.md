# Avaliação final do Guerreiro 3D

## Veredito

**AINDA NÃO substituir definitivamente o sprite.** O protótipo 3D demonstra ganho claro em movimento, impacto e personalidade, mas a composição por SubViewport individual ainda não prova integração visual nem escalabilidade suficientes para justificar converter toda a pipeline.

## Estado e testes executados

- V3 carregado com um skeleton e Actions de locomotion, combate, reação, identidade e quatro skills reais.
- Validador headless confirmou ações, sockets, estados, hit-stop, VFX, Death lock e snapshot de gameplay.
- Stress estrutural disparou dez ataques/slashes/hits simultâneos; nenhum VFX da camada de skills ficou órfão.
- Benchmark headless de 90 frames (execução final): 1 = 7.154 ms/frame; 5 = 6.824; 10 = 7.553; 20 = 7.673. Houve variação entre execuções, como esperado em wall time. Esses números medem CPU sem renderização real e **não são um benchmark de GPU**. Vinte instâncias ficam como WARNING devido a vinte render targets independentes.
- A suíte GUT passou pelos testes de gameplay e pelo teste do ataque ponderado do Guerreiro após correção de tipagem. A coleta completa possui um problema alheio em `test_tower_new_enemies.gd:201`, portanto não há um resultado global totalmente limpo nesta execução.
- Não foi possível concluir julgamento visual honesto de Campo/Vila/Torre/Lava em headless. As notas visuais abaixo são provisórias e precisam de capturas no hardware/câmera real.

## Scorecard provisório (1–10)

| Categoria | Sprite | 3D | Motivo |
|---|---:|---:|---|
| Qualidade visual | 7 | 7 | 3D tem volume/toon; sprite encaixa melhor na arte existente. |
| Animação | 5 | 8 | Rig e Actions dão variedade e transições reais. |
| Impacto de combate | 6 | 8 | Hit-stop, recoil, pose e trail favorecem o 3D. |
| Legibilidade | 8 | 7 | Sprite foi desenhado para a escala; 3D ainda requer prova em todos os fundos. |
| Personalidade | 5 | 8 | Idles, LowHP, ataques e skills exclusivas dão vantagem ao 3D. |
| Integração com cenário | 9 | 5 | Sprite compartilha naturalmente a composição 2D; 3D não compartilha depth. |
| Movimento | 7 | 7 | 3D gira melhor, mas foot sliding/turns ainda precisam inspeção. |
| Attack feel | 6 | 8 | 3D comunica antecipação/impacto/recovery melhor. |
| Skill feel | 6 | 8 | Coreografias reconhecíveis; ThrowSword ainda é híbrido. |
| Performance | 9 | 5 | Sprite é barato; SubViewport e outline por instância são caros. |
| Manutenção técnica | 8 | 5 | A cadeia Blender→GLB→Godot é maior e há timers de markers documentados. |
| Escala para outros personagens | 7 | 6 | Skeleton humanoide é reutilizável, arquitetura de composição ainda não. |

## Comparação objetiva

O 3D ganha em animação, impacto e capacidade de variação. O sprite ganha em legibilidade comprovada, integração com os cenários e custo. Neste momento, o principal risco não é o modelo: é a arquitetura híbrida. O personagem inteiro pode ficar atrás ou à frente de um prop conforme `z_index`, mas braços/espada/corpo não recebem oclusão parcial coerente.

## Performance e memória

- Skeleton: 32 bones; adequado para gameplay.
- Modelo: 27 partes rígidas/meshes e GLB V3 de aproximadamente 569 KB.
- Outline: mais 27 drawables por personagem.
- Toon e outline criam materiais por instância para permitir flash/flags.
- Cada token 3D cria SubViewport 192×192 com update contínuo enquanto habilitado.
- GLB/PackedScene é compartilhado, mas overrides de materiais e render targets não são gratuitos.

## Problemas por severidade

- **BLOCKER:** ausência de depth compartilhado com o cenário 2D para oclusão parcial.
- **HIGH:** custo não medido em GPU real de muitos SubViewports; materiais/outlines por instância; falta de comparação visual nos quatro biomas.
- **MEDIUM:** turns ainda não comandam toda rotação; ThrowSword mistura Action 3D e projétil 2D; sockets de ponta/base ausentes.
- **LOW:** pooling e captura A/B automática; refinamentos de secondary motion.

## Modo A/B

Ative `warrior_ab_test` no node principal em build debug. Durante a mesma batalha e sem trocar câmera/tile:

- `A`: sprite antigo.
- `B`: Guerreiro 3D.

`UnitToken.set_use_3d_visual()` faz a troca em runtime, desabilitando o update do SubViewport no modo Sprite. `warrior_3d_scale` centraliza a escala sem editar o GLB.

Roteiro recomendado: usar a mesma seed/situação em Campo, Vila, Torre e Torre vulcânica; registrar Idle, caminho com curvas, 20 ataques, Heavy, quatro skills, miss, critical, hits direcionais e Death junto a parede.

## Direção recomendada

Continuar o protótipo apenas até resolver/provar a composição compartilhada e obter profiling/capturas reais. Se esses dois pontos forem aprovados, o melhor segundo humanoide é o **Arqueiro**: reaproveita skeleton, testa arma/poses diferentes, projéteis e uma silhueta menos pesada sem introduzir instrumentos/props complexos como o Bardo.

Não converter outro personagem antes desse gate.

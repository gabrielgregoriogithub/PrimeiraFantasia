# Warrior 3D — final polish pass

## Diagnóstico

- O menor ponto geométrico do GLB é `Y = -0.00000000298`, portanto a sola já foi exportada praticamente em `Y = 0`. `ModelRoot` e `Skeleton3D` chegam com transform identidade; `Root` tem rest local `Y = 0.02` e `Hips` `Y = 0.8`.
- A flutuação percebida não vinha da coordenada do grid. O `UnitToken` aplicava bob/squash do controlador 2D ao SubViewport 3D inteiro e os ataques aplicavam uma segunda translação/escala no pai. Além disso, o recoil restaurava `VisualRoot.scale` para `1`, perdendo o `model_scale = 0.68` após o primeiro golpe.
- Idle não possui deslocamento vertical dos pés; Walk, ataques, Hit e Skill_Defend retornam ao mesmo valor inicial. Death é a única Action cujo Hips termina deslocado/rotacionado, intencionalmente.
- O GLB é composto por 27 peças rígidas bone-parented. Não há malha de escudo no asset original e não há `.blend` no projeto.

## Correções aplicadas

- Hierarquia visual: `GroundAnchor -> VisualRoot -> ModelRoot`. O nó lógico permanece no plano do grid; `visual_offset` pertence ao `VisualRoot`; `model_scale` pertence somente ao `ModelRoot`.
- Grounding por AABB usa a sola, não o centro geométrico. O debug `show_ground_anchor` exibe âncora, footprint e marcadores dos dois pés e permanece desligado por padrão.
- O bob/squash/lunge/recoil 2D do `UnitToken` não movimenta mais o Guerreiro 3D inteiro. Todas as ações restauram a baseline visual antes/depois, sem drift ou escala acumulada.
- MISS mantém o gesto corporal, mas não produz hit-stop/recoil de contato.
- Attack Light: impacto em ~333 ms; FinishPose inicia ~443 ms depois do começo, segura 85 ms e recupera a 0.88x. Extensão total de 160 ms antes de Idle.
- Attack Heavy: impacto em ~700 ms; FinishPose em ~860 ms, segura 120 ms e recupera a 0.78x. Extensão total de 300 ms.
- Skills: FinishPose começa 120 ms após o impacto, segura 80 ms e recupera a 0.86x; o sinal `skill_finished` agora inclui essa extensão visual.
- Hit-stop existente foi preservado: curto para light e mais forte para heavy/critical. VFX continuam depois da leitura corporal e MISS não dispara impacto falso.
- Death desliga o AnimationTree no fim e conserva exatamente a pose final; nunca transita para Idle.
- Foi acrescentado escudo estilizado azul/dourado no `Hand_L`, com face, aro e boss, seguindo o osso nas Actions atuais. Espada recebeu contraste de aço e escala local moderada; cabeça, ombreiras, mãos e botas receberam exagero local pequeno e data-driven, sem alterar a escala global ou footprint.

## Revisão de gameplay real

Capturas estão em `artifacts/warrior_polish/`: Idle, contatos/passing de Walk, Attack MISS/HIT (preparation, impact, finish, recovery), Skill_Defend, Hit e três fases de Death, tanto na câmera da batalha quanto isoladas com sufixo `_model`.

- Idle e Walk permanecem assentados no tile e retornam à mesma altura.
- Hit reage com tronco/cabeça e retorna à baseline visual.
- Death termina e permanece na pose caída.
- O escudo agora é legível e acompanha o braço esquerdo.
- Não existe uma ação/skill `Shield Bash` no perfil de combate atual; `Skill_Defend` foi revisada sem criar regra de combate nova.

## Limitações do asset que exigem Blender

- As poses intermediárias de Attack Light do GLB afastam várias peças rígidas do enquadramento no impacto/finish; a espada permanece visível, mas o corpo perde leitura. Isso é conteúdo da Action importada e precisa ser corrigido nos keyframes/parenting do rig, não escondido com VFX.
- O ataque ainda precisa de arco mais claro e transferência `quadril -> tronco -> ombro -> braço`; o asset rígido não fornece deformação/overlap suficiente.
- Walk levanta os pivôs dos pés alternadamente, porém ainda precisa de curvas e contatos de sola refinados para eliminar visualmente todo foot sliding.
- Block/Hit elevam simultaneamente os pivôs dos dois pés em alguns frames; a correção definitiva requer IK/plant keys no arquivo-fonte.
- As variantes direcionais `Hit_Left`, `Hit_Right` e `Hit_Heavy` possuem pouco ou nenhum movimento dos pés/quadril e precisam de poses corporais mais distintas.
- Para a próxima passagem manual: corrigir parenting/export das 27 peças, plantar as solas, reconstruir Attack/Shield Bash com poses-chave claras e revisar o contato final de Death. Não há arquivo `.blend` nem Blender disponível neste projeto para executar essa etapa com segurança.

## Validação

- `PipelineValidation.tscn`: todos os itens do pipeline e regressão do Guerreiro passaram.
- Auditoria determinística: AABB, transforms, bones, começo/fim e altura dos pés para Idle, Walk, Attack A/B/C/Heavy, Block, Hit, Death e Skill_Defend.
- A suíte GUT global não consegue coletar testes por um erro preexistente fora deste escopo em `tests/unit/test_tower_new_enemies.gd:201` (`living` sem tipo inferível).

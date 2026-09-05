# Auditoria da migração da pipeline 3D

## Antes

Responsabilidades genéricas concentradas em `warrior_3d.gd` (624 linhas): descoberta de model/skeleton, AnimationTree, locomotion, rotação, seleção, LowHP, ataques, hit/death/revive, hit-stop, câmera, toon/outline/shadow e validação. `warrior_vfx.gd` (138 linhas) implementava material e VFX base. Skill mapping e scene wiring também tinham nomes do Guerreiro.

Específico de Guerreiro: três cortes de espada, stance pesada, quatro skills (`powerAttack`, `throwSword`, `spinAttack`, `defend`), socket da espada e seus timings/VFX.

Genérico: lifecycle visual, registry lógico→Action, state machine, fallbacks, in-place movement, facing, selection, hit/death/revive, sockets, shader, shadow, VFX cleanup, hit-stop, câmera e validação.

## Depois

- `Warrior3DVisual`: wrapper compatível de 5 linhas.
- `warrior_3d_profile.tres`: toda configuração específica sem valores de gameplay.
- Infraestrutura compartilhada: `CharacterVisual3D`, profile, factory, locomotion/look-at, VFX, skill VFX, shadow, selection, feel e validators.
- Shaders passaram de `warrior_*` para `character_*`.
- `UnitToken` consulta disponibilidade/capabilities da factory/profile, sem decidir pelo nome Guerreiro.
- `main.gd` ainda contém regras de apresentação histórica identificadas pelo `spriteKey` em outras áreas do jogo, mas o caminho novo de ataque/skill 3D não depende do nome do Guerreiro.

## Duplicação restante

### Pode ser removido após revisão

- `scenes/characters/warrior_skill_registry.gd`: substituído por `profile.skill_visuals` e não possui consumidores.
- Nomes legados `_warrior_3d`, `_uses_warrior_3d`, `play_warrior_skill_visual`: mantidos para compatibilidade/testes; podem virar aliases deprecated de nomes `character_3d`.
- `Warrior3DTest.tscn`: útil para regressão histórica, mas `Character3DTest.tscn` é a cena canônica nova.

### Precisa revisão antes de remover

- Scripts Blender históricos na raiz de `tools/blender`: scripts de identidade importam arquivos por caminho relativo.
- `Warrior3D.tscn`: wrapper é usado por testes e referências existentes.
- V1/V2/V3 GLBs e blends: são rollback/versionamento, não duplicação acidental.

## Métricas

Antes: quatro módulos diretamente específicos (`warrior_3d`, `warrior_vfx`, `warrior_skill_vfx`, `warrior_skill_registry`) mais cena e shaders nomeados por personagem.

Depois: um wrapper mínimo + um profile + GLB/manifest; controllers e shaders são comuns. Dry run Arqueiro: um profile, nenhuma cópia de controller/shader. Para produção, espera-se GLB + profile + manifest + VFX opcional.

Reutilização estimada para o próximo humanoide: **88–92%** da infraestrutura. A parte específica restante é majoritariamente conteúdo, não lógica.

## Performance

A refatoração não adiciona `_process()` contínuo novo: locomotion/look-at são helpers e o feel é orientado a eventos/tweens. Resources e PackedScenes são compartilhados. A limitação dominante continua sendo o SubViewport por token e os materiais/outlines por instância, já existente antes da migração.

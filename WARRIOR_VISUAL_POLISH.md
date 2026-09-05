# Warrior Visual Polish

## Toon shading

`warrior_toon.gdshader` usa três bandas de iluminação, sombra mínima de 32%, specular discreto e rim light controlado. Cada surface preserva a cor base importada. Pele, tecido e couro recebem specular baixo; materiais originalmente metálicos recebem highlight toon mais forte. O preset HIGH aumenta apenas o rim.

## Outline

O contorno usa inverted hull por mesh com `cull_front` e expansão pela normal (`outline_width`, padrão 0,008 m). É configurável por `outline_enabled` e `outline_intensity`. Essa técnica é previsível dentro do SubViewport e não exige pós-processamento global, mas dobra os draw calls das 27 peças.

## Sombra, seleção e sockets

A blob shadow é um cilindro achatado unshaded no chão. Ela muda discretamente em Walk/Attack e se alonga em Death. `SelectionMarker` pode ser acionado por `set_selected()`; o marcador 2D existente continua funcionando. Sockets disponíveis:

- `VFXSocket`: torso/impacto.
- `WeaponVFXSocket`: anexado em runtime ao bone `WeaponSocket_R`.
- `DamageNumberOrigin`: acima da cabeça.

## VFX e feedback

`warrior_vfx.gd` concentra slash, burst, impacto pesado e flash. Os efeitos são temporários e executam `queue_free`; não calculam dano nem alteram estado lógico. AttackLight usa arco curto, AttackHeavy usa arco maior, burst e anel de chão. O impacto também aplica shake curto apenas à câmera do SubViewport.

`play_hit()` dispara flash branco de 0,10 s e fragmentos cartoon. Death remove o feedback de seleção e preserva o corpo. `fade_out_after_death()` existe, mas não é chamado automaticamente.

Walk emite `footstep_left` e `footstep_right`. Poeira por terreno fica desativada até existir uma política visual explícita para cada terreno.

## Flags e presets

- `toon_enabled`
- `outline_enabled`
- `shadow_enabled`
- `vfx_enabled`
- `debug_vfx`
- `quality_preset`: LOW, MEDIUM ou HIGH

LOW desativa outline e VFX; MEDIUM ativa toon, outline, sombra, slash e hit; HIGH também aumenta rim/VFX. A feature flag de rollback completa continua sendo `UnitToken.use_3d_visual`.

Na cena `Warrior3DTest.tscn`: 9 testa slash, 0 testa hit, F1 alterna toon, F2 outline, F3 sombra e F4 VFX.

## Custos e limitações

- Um SubViewport 192×192 e duas luzes locais são usados somente no Guerreiro experimental.
- O outline adiciona 27 draw calls. Para dezenas de personagens, usar LOW ou migrar para uma viewport 3D compartilhada.
- Transparência fica restrita aos VFX curtos e marcador.
- O sistema híbrido mantém oclusão por `z_index` 2D, sem depth compartilhado com paredes.
- O slash procedural é um arco gráfico, não uma ribbon que amostra continuamente a ponta da espada.

## Ajustes de Blender observados

O modelo segmentado pode revelar pequenos espaços em cotovelos/joelhos nas poses extremas. A espada e mãos grandes são escolhas estilizadas; avalie na câmera real antes de alterar geometria. Nenhuma geometria Blender foi modificada nesta fase.

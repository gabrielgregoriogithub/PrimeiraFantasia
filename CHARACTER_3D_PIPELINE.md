# Pipeline oficial de personagens 3D

## Quick start: novo humanoide em 10 passos

1. Modele em metros, com os pés em Z=0 e frente Blender -Y (Godot -Z).
2. Use o skeleton humanoide padrão ou declare um `bone_map` customizado.
3. Crie Actions independentes e in-place; mantenha `Root` sem translação horizontal.
4. Marque eventos (`impact`, `cast`, `projectile_spawn`, passos e `death_ground`).
5. Rode os validadores de `tools/blender/common`.
6. Exporte GLB versionado com `export_character_glb()`.
7. Crie um `Character3DProfile.tres` com modelo, animações, capacidades, sockets e timings fallback.
8. Registre somente `character_id → profile` em `CharacterVisualFactory.PROFILES`.
9. Abra `Character3DTest.tscn`, escolha o profile e valide animações/skeleton.
10. Ative o flag 3D somente para esse personagem e rode regressão/batalha A/B.

## Arquitetura

`CharacterVisual3D.tscn` é a cena comum. `CharacterVisual3D` carrega o modelo do profile, resolve animações, constrói AnimationTree, fornece APIs de ataque, skill, hit, death, seleção, rotação, LowHP e revive. `CharacterVFXController`, `CharacterSkillVFX`, `CharacterLocomotionController`, `CharacterLookAt`, `CombatFeelManager` e `SkeletonCompatibility` são componentes reutilizáveis. A factory retorna `null` quando não existe profile, preservando o sprite.

O Guerreiro mantém `Warrior3DVisual` como wrapper compatível de três linhas; não contém controller próprio. Ajustes comuns são editáveis no Inspector/profile. Comportamento verdadeiramente exclusivo deve ser um componente/hook, nunca `if character_id` na base.

## Profile

O Resource contém apenas apresentação: modelo, escala, offset, footprint visual, eixo frontal, registry de animações, eventos/timings, skills visuais, bones, sockets, arma, toon/shadow e áudio futuro. Dano, HP, MP, CT, alcance e rolagens nunca entram no profile.

Fallbacks esperados:

- Run ausente: Walk com playback maior.
- Hit direcional ausente: Hit genérico.
- Selected ausente: círculo/outline.
- Victory ausente: Idle.
- Socket opcional ausente: Marker3D de fallback documentado.
- Profile/modelo inválido: erro em debug e sprite preservado no roster.

## Skeleton padrão humanoide

Obrigatórios: `Root`, `Hips`, `Spine`, `Chest`, `Neck`, `Head`, braços `Shoulder/UpperArm/Forearm/Hand_L/R` e pernas `Thigh/Shin/Foot_L/R`. Toe e sockets são opcionais. Criaturas podem fornecer skeleton arbitrário e outro `required_bones`; não há obrigação de encaixar quadrúpedes, voadores ou unidades 2x2 no humanoide.

Sockets convencionais: `Weapon_R`, `Weapon_L`, `Head`, `Chest`, `Back`, `ProjectileOrigin`, `VFX_Head`, `VFX_Chest`, `VFX_Feet`, `DamageNumberOrigin`. O profile mapeia nomes reais, portanto `WeaponSocket_R` do Guerreiro continua válido.

## Blender

`tools/blender/common/rig_utils.py` valida rig/simetria/transforms e cria sockets. `animation_utils.py` cria Actions, keys, markers, Fake User e valida root motion. `validation_utils.py` cruza o asset com o manifest. `export_utils.py` exporta somente armature e descendentes, sem câmera/luz/debug.

Convenção de versão: `character_v1.glb`, `character_v2.glb`. Nunca usar `final2`. Manifests JSON registram versão, rig, frente, sockets e Actions obrigatórias.

## APIs

- `play_attack_light(critical)` / futura fachada `play_basic_attack(target,result)`.
- `play_skill_visual(skill_id,result,target)`.
- `play_hit_from_direction(source,critical)`.
- `play_death()` e `reset_from_death()` para revive comandado pelo gameplay.
- `face_world_position()` / `face_direction()`.
- sinais padronizados de início, impacto, fim, passos, queda e skills.

O gameplay sempre decide Hit/Miss/Critical, dano e alvos. A camada visual só recebe o resultado.

## Arquétipos e extensibilidade

- `Humanoid_Melee`: Guerreiro, Orc, Esqueleto.
- `Humanoid_Ranged`: arco/besta, duas mãos e ProjectileOrigin.
- `Humanoid_Caster`: Cast/Channel, mãos/cajado/SpellOrigin.
- Criaturas quadrúpedes, voadoras e Large 2x2: profile customizado, footprint/offset/scale e skeleton próprio.

Transformações futuras trocam o profile/model instance mantendo a unidade lógica. Mounted/dual-wield usam sockets/capabilities adicionais. Death não é permanentemente irreversível: `reset_from_death()` permite Zombie/revive.

## Testes

- `Character3DTest.tscn`: showcase orientado pelo registry, sem atalhos específicos.
- `PipelineValidation.tscn`: profile, skeleton, factory, APIs e dry run.
- `Warrior3DFinalValidation.tscn`: stress/performance e snapshot de gameplay.
- GUT: `test_character_3d_pipeline.gd` valida factory, fallback, IDs e ausência de gameplay nos profiles.

## Dry run: Arqueiro

O dry run exigiu um único `.tres`, zero controllers e zero shaders/VFX base duplicados. Ainda serão necessários modelo GLB, rig/animações, arco, `ProjectileOrigin`, timings de draw/release e VFX particular da flecha. Ao existir o GLB, apenas uma entrada na factory é necessária.

Estimativa: 4 arquivos específicos para um humanoide simples — GLB, profile, manifest e VFX opcional. Aproximadamente 88–92% da infraestrutura visual é reutilizada; código específico pode ser zero para o caso comum.

## Troubleshooting

- Frente errada: corrija `forward_axis`/offset no profile antes de alterar Actions.
- Escala errada: `model_scale` e `visual_offset`.
- Missing animation: confira candidates e caixa/nome exportado; required falha, optional usa fallback.
- Arma solta: valide bone/socket e rigid parenting.
- Foot sliding: Blender/Action; não esconder estruturalmente com tween.
- Impacto fora do tempo: marker exportável ou `animation_events` fallback.
- Death volta a Idle: marque one-shot e valide Death lock.
- Outline/material quebrado: use shaders comuns e confira surface overrides.
- Skeleton mismatch: rode `SkeletonCompatibility` e `rig_utils.validate_armature`.

## Limitação conhecida

A pipeline reutiliza o sistema existente de SubViewport por token. A limitação de oclusão/performance identificada na Fase 9 permanece e deve ser resolvida antes de migrar todo o elenco.

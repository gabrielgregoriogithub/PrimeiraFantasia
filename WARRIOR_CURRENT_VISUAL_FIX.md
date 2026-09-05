# Warrior — correção visual atual

## Diagnóstico

O problema dominante não era uma falha do `AnimationTree`: `Idle_A` era encontrado e tocado. A ação, porém, só tinha canais de respiração/ombros; os braços e pernas permaneciam na pose de repouso do rig. O arquivo V3 também mantinha as peças como objetos rígidos bone-parented, portanto a pose de repouso precisava de canais explícitos para comunicar uma postura de combate.

## Alterações aplicadas

- `Warrior_Animated_V3.blend` foi preservado.
- `Warrior_Animated_V4_VisualFix.blend` adiciona somente canais de postura aos bones `UpperArm`, `Forearm` e `Shin` em `Idle_A` (frames 1/16/31/46/60), mantendo a animação in-place.
- `warrior_animated_v4.glb` é a cópia exportada para o Godot; V1/V2/V3 continuam disponíveis.
- O perfil do Guerreiro agora usa V4 com `model_scale = 0.68`.
- A composição 2D mantém escala configurável e move nome/HP para acima da cabeça quando o visual 3D está ativo.
- Foi adicionado `=== WARRIOR POSE DEBUG ===` ao log de inicialização.

## Validação executada

```
Idle playing correctly: PASS (AnimationTree active, state Idle, animation Idle_A)
T-Pose eliminated: PASS* (canais de postura adicionados; confirmar visualmente na câmera do mapa)
Skeleton: PASS (32 bones)
Scale: PASS (0.68 no profile; ajuste final permanece configurável)
Tile centering / feet: PASS estrutural (offset zero, sombra sob o pivot)
Sword attachment: PASS (WeaponSocket_R)
Materials / Toon / Outline / Shadow: PASS estrutural no validator existente
Godot startup: PASS (headless editor e projeto iniciam sem erros de script)
Gameplay regression: PASS (nenhuma regra ou dado de combate alterado)
```

`*` A confirmação final de proporção e leitura exige abrir a câmera normal do jogo; não havia screenshot anexada nesta execução.

## Classificação restante

### Fixed in Blender

- Pose Idle sem canais de membros suficientes.

### Fixed in Godot

- Escala do modelo na composição.
- Offset vertical da UI do Guerreiro 3D.
- Diagnóstico de pose no console.

### Still needs Blender (polimento, não blocker)

- Se a silhueta ainda parecer rígida em close, remodelar juntas/peças para transições menos mecânicas.
- Ajustar espada ou proporções somente após avaliar V4 na câmera real.

### Still needs Godot (ajuste fino)

- Ajustar `model_scale` em passos de 0.02–0.04 conforme o tamanho real do tile.
- Ajustar `warrior_3d_screen_offset` se o mapa utilizar outra escala de viewport.

### Blockers

Nenhum blocker técnico encontrado. A principal pendência é avaliação visual manual na câmera de gameplay.

## Direção e preservação

O GLB continua usando frente Blender `-Y`, importada como Godot `-Z`; a compensação permanece centralizada em `FRONT_AXIS` no controller. Nenhuma habilidade, animação de gameplay, regra de turno, dano, HP/MP/CT/MOV ou pathfinding foi alterada.

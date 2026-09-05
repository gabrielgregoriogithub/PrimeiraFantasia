# Warrior — Iteração de polimento 1

## Diagnóstico objetivo

| Categoria | Severidade | Estado atual | Origem |
|---|---|---|---|
| Visual base | HIGH | A pose estava muito aberta e pouco legível em gameplay | Blender/Action Idle |
| Modelagem/proporção | HIGH | A silhueta é geométrica e algumas peças parecem blocos rígidos | Blender (polimento posterior) |
| Rig/skinning | MEDIUM | Rig humanoide válido; peças são rígidas bone-parented, não uma pele contínua | Blender |
| Animação | HIGH | `Idle_A` não tinha canais de membros suficientes; Walk/ataques precisam revisão visual manual | Blender |
| Materiais/shader | MEDIUM | Paleta autoral existe, mas importadores podem retornar branco; toon precisava fallback | Godot shader/controller |
| Integração no mapa | HIGH | Escala anterior cobria demais o tile; composição 2D/3D continua limitada por z-index | Godot |
| Combate/feel | MEDIUM | Eventos e impacto funcionam, mas só devem ser refinados depois da pose base | Godot/Blender |
| UI/leitura | HIGH | Nome/HP ficavam baixos e próximos dos pés do modelo 3D | Godot |
| Polimento final | LOW | Ainda requer avaliação visual na câmera real e fundos de mapa | Godot/editor |

## Roadmap de qualidade

- **Iteração 1 (atual):** Idle, escala, pivot, espada, grounding, shadow, materiais seguros, UI e diagnóstico.
- **Iteração 2:** validar proporções/silhueta na câmera real e corrigir somente problemas confirmados de mesh/espada no Blender.
- **Iteração 3:** revisar Walk, AttackLight, Hit e Death com foco em articulação e foot planting.
- **Iteração 4:** calibrar toon/outline/shadow contra Campo, Vila e Torre.
- **Iteração 5:** refinar timing e impacto básico, sem adicionar conteúdo.
- **Iteração 6:** regressão final, A/B sprite versus 3D e decisão de aprovação.

## Iteração 1 executada

- Criado `Warrior_Animated_V4_VisualFix.blend`; V3 permanece intacto.
- `Idle_A` agora possui canais de postura em `UpperArm_L/R`, `Forearm_L/R` e `Shin_L/R`, mantendo root motion in-place.
- Perfil usa `warrior_animated_v4.glb` com `model_scale = 0.68`.
- UI do token 3D foi elevada (`name/HP/MP`) e mantém offsets configuráveis.
- Fallback de paleta foi adicionado para superfícies GLB importadas como branco puro.
- Debug de pose informa skeleton, AnimationPlayer, AnimationTree, estado, Idle e escala.
- Nenhuma regra de gameplay, turno, dano, HP/MP/CT/MOV ou skill foi modificada.

## Evidências

```text
AnimationTree active: true
Current state: Idle
Current animation: Idle_A
Idle playing: true
Skeleton bone count: 32
Model scale: 0.68
GLB/Skeleton/AnimationPlayer: PASS
Idle/Walk/Attack/Hit/Death: PASS
Toon/Outline/Shadow/Sword socket: PASS
Projeto Godot inicia: PASS
Warrior3DTest: PASS
```

## Pendências honestas

- A confirmação estética final em câmera de gameplay precisa ser feita visualmente no editor/jogo; a execução disponível foi headless e não recebeu screenshot anexada.
- A geometria ainda é deliberadamente low-poly e rígida. Se a silhueta continuar parecendo um conjunto de blocos, isso exige Blender, não efeitos no Godot.
- A arquitetura híbrida 2D/3D ainda usa composição por `SubViewport`/`z_index`; o depth não é compartilhado como em uma cena 3D pura.

## Próxima iteração recomendada

Abrir a cena real com VFX desligado e comparar V3/V4 em Idle nos tiles Campo/Vila/Torre. Ajustar apenas `model_scale`, `warrior_3d_screen_offset` e a pose Blender se a silhueta ainda ultrapassar um tile ou os pés não estiverem apoiados.

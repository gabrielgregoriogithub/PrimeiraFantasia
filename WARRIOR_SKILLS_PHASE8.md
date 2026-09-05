# Guerreiro 3D — Fase 8

## Habilidades reais preservadas

| ID | Nome | MP | CT | Dano | Alcance/área | Acerto | Efeito |
|---|---|---:|---:|---|---|---:|---|
| `powerAttack` | Ataque Poderoso | 4 | 0 | +3 no próximo ataque | self | — | +15% crítico no próximo ataque do turno |
| `throwSword` | Arremessar Espada | 3 | 50 | 8–10, crítico ×2 | 1–3, apenas cardinal | 80% | projétil `blade` |
| `spinAttack` | Ataque Giratório | 3 | 50 | 8–10, crítico ×2 | oito casas vizinhas | 80% | resolução multi-alvo existente |
| `defend` | Defender | 1 | 0 | — | self | — | redução 2 por 3 turnos |

Esses valores continuam definidos somente em `data/spells.gd`; a camada visual não os lê nem os modifica. A tabela antes/depois é idêntica.

## Mapeamento visual

| Skill | Action V3 | Evento | VFX | Câmera / hit-stop |
|---|---|---|---|---|
| `powerAttack` | `Skill_PowerAttack` | cast 15/30 s | impulso de força | light / light |
| `throwSword` | `Skill_ThrowSword` | cast 13/30 s; impacto visual acompanha o projétil existente | lançamento | medium / light |
| `spinAttack` | `Skill_Whirlwind` | impact 22/30 s | arco circular | heavy / heavy |
| `defend` | `Skill_Defend` | cast 10/30 s | postura/aura curta | none / none |

Todas possuem markers Blender `skill_start`, `cast` ou `impact`, `recovery` e `skill_end`, usam o mesmo skeleton, são in-place e ficam separadas em Actions. No runtime, timers documentados são usados porque markers glTF não viram method tracks automaticamente.

`WarriorSkillRegistry` centraliza nomes e perfis. `Warrior3DVisual` emite `skill_started`, `skill_windup`, `skill_impact` e `skill_finished`; esses sinais são cosméticos. O gameplay continua resolvendo Hit/Miss/Critical, alvos, MP, CT, dano e status pelo fluxo existente. Um sequence ID invalida callbacks quando Death ou outra skill interrompe a apresentação.

## Arquivos e rollback

- Blender: `Warrior_Animated_V3.blend`; script `tools/blender/animate_warrior_skills_v1.py`.
- Godot: `assets/characters/warrior/warrior_animated_v3.glb`.
- V1, V2 e seus `.blend`/`.glb` permanecem preservados.
- `Warrior3D.tscn` aponta para V3; para rollback, troque apenas o ext_resource para V2.

## Teste

Na `Warrior3DTest.tscn`: `P`, `T`, `G`, `D` executam as quatro skills; Shift simula Critical. O projétil e a resolução real de miss/critical continuam sob responsabilidade do combate existente.

Limitações: a trajetória da espada é uma coreografia procedural simples, sem simulação física; o trail V3 usa o socket da mão/arma e não amostra ainda `SwordTip` e `SwordBase`. A validação automatizada confirma estrutura e callbacks; avaliação artística final ainda deve ser feita na câmera real do jogo.

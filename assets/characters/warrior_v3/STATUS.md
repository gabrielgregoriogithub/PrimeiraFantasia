# Warrior_V3 — fonte de verdade

Última atualização: 2026-09-05 01:43:03 -03:00

## Objetivo

Produzir `Warrior_V3.glb` por uma pipeline externa de asset (`reference -> concept -> raw mesh -> visual QA -> rig/skinning -> equipment/sockets -> animations -> Godot integration -> in-game QA`), mantendo gameplay e o Guerreiro legado intactos até aprovação.

## Estado atual

`STAGE 0 — DONE_AND_PRESENT`. A estrutura isolada e esta auditoria existem. Nenhum asset Warrior_V3 foi produzido. Alegações de aprovação presentes na conversa não são evidência de arquivos ou jobs concluídos.

## Matriz de stages

| Stage | Status | Evidência |
|---|---|---|
| 0 — audit / setup | DONE_AND_PRESENT | Este `STATUS.md`; diretórios `reference/`, `concept/`, `raw/`, `rigged/`, `animations/`, `equipment/`, `previews/`, `final/` e `tools/warrior_v3/`. |
| 1 — reference / concept | NOT_STARTED | Nenhum arquivo V3 em `reference/` ou `concept/`; nenhum job/log de geração encontrado. |
| 2 — raw 3D mesh | NOT_STARTED | Nenhum `Warrior_V3_RAW.glb`, GLTF, FBX, OBJ ou Blend encontrado. |
| 3 — rig | NOT_STARTED | Nenhum `Warrior_V3_RIGGED` e nenhum mapeamento de skeleton V3 encontrado. |
| 4 — sword/shield sockets | NOT_STARTED | Nenhum `WarriorSword.glb`, `WarriorShield.glb`, `WeaponSocket_R` ou `OffhandSocket_L` pertencente ao V3. |
| 5 — animations | NOT_STARTED | Nenhuma biblioteca/clip V3 e nenhum log de retarget. |
| 6 — Godot integration | NOT_STARTED | Nenhum profile, scene, resource ou flag `use_warrior_v3`. |
| 7 — UI | PARTIAL | UI world-space/bounds foi trabalhada e capturada somente com o Guerreiro legado em `artifacts/warrior_polish/`; nunca validada com V3. |
| 8 — final QA | NOT_STARTED | Houve uma resposta textual de QA, mas não existia asset V3 para testar. |

## Inputs existentes

- Nenhum input com identidade `Warrior_V3` foi encontrado.
- Não há reference/concept V3 persistido.
- Não há job ID, resposta de API ou log Tripo/Meshy/Rodin/Hunyuan.

## Outputs existentes

- Nenhum output Warrior_V3.
- Legado, fora da pipeline V3: `assets/characters/warrior/warrior_animated_v1.glb` até `warrior_animated_v5.glb`.
- Fonte legada: `.warrior_sources/warrior_animated_v5.blend`.
- Protótipo rejeitado V2: `.warrior_sources/v2/warrior_v2_base.blend` e `.glb`.
- QA rejeitado V2: `artifacts/warrior_v2_gate/warrior_v2_{north,east,south,west}.png`.
- Capturas do Guerreiro legado: `artifacts/warrior_polish/`.

## Ferramentas disponíveis

- Blender 4.5.11 portátil: AVAILABLE por caminho absoluto em `C:/Users/gabri/Tools/blender-4.5.11/blender-4.5.11-windows-x64/blender.exe` (não está no PATH).
- Godot 4.7.2: AVAILABLE por caminho absoluto.
- Automação Blender legada para rig/animação/export: AVAILABLE em `tools/blender/`; não é uma pipeline V3 e não deve ser reutilizada como gerador do corpo final.
- Auditoria/captura GLB no Godot: AVAILABLE (`tools/warrior_animation_audit.gd`, `tools/capture_warrior_gameplay.gd`).
- `uv`, `git`, `node`: AVAILABLE. `python` independente não está no PATH; Blender inclui seu próprio Python.
- Tripo CLI/API: NOT AVAILABLE.
- Meshy CLI/API: NOT AVAILABLE.
- Assimp e gltf-transform: NOT AVAILABLE.
- Ferramenta integrada de geração de imagem da sessão: AVAILABLE para concept raster, mas não produz mesh 3D.

## APIs (presença, nunca valores)

- `TRIPO_API_KEY`: NOT AVAILABLE
- `OPENAI_API_KEY`: NOT AVAILABLE
- `MESHY_API_KEY`: NOT AVAILABLE
- `RODIN_API_KEY`: NOT AVAILABLE
- `STABILITY_API_KEY`: NOT AVAILABLE
- `HUNYUAN3D_API_KEY`: NOT AVAILABLE

## Git

- Este diretório do jogo não contém `.git` próprio.
- O Git ascendente encontrado é `C:/Users/gabri/.git`, branch `main`, remote `Professional_Profile.git`; ele não representa com segurança o histórico deste projeto.
- `git status` e histórico do jogo não são determináveis como repositório independente. Não há commits verificáveis relacionados ao Warrior_V3.

## Diagnóstico de recuperação

A causa comprovada para a ausência do V3 é: as etapas 1–8 foram avançadas apenas por afirmações textuais na conversa. Não existe evidência de execução de geração externa, upload, arquivo salvo, job remoto, commit, branch alternativa ou output temporário V3. As APIs 3D estavam indisponíveis. Não há evidência de que arquivos V3 tenham sido apagados ou sobrescritos.

## Próximo gate

Executar de verdade **STAGE 1 — reference / concept** e persistir os arquivos aprovados em `reference/` e `concept/`, acompanhados de prompt/spec e manifesto de origem. Não iniciar image-to-3D antes desse output existir e ser aprovado.

# Warrior_V3 — fonte de verdade

Última atualização: 2026-09-06 (America/Sao_Paulo)

## Objetivo

Produzir `Warrior_V3.glb` pela pipeline `reference -> concept -> raw mesh -> visual QA -> rig/skinning -> equipment/sockets -> animations -> Godot integration -> in-game QA`, mantendo gameplay e Guerreiro legado intactos até aprovação.

## Estado atual

`STAGE 1 — DONE_AND_PRESENT`. `STAGE 2 — DONE_AND_PRESENT`: candidate_01 recuperado com cleanup local no Blender e aprovado nos gates RAW. `raw/Warrior_V3_RAW.glb` presente: 21.501 triângulos, 1 material, textura 2048×2048. Original intocado; recuperação sem créditos adicionais. Histórico Tripo: 270 créditos.

## Matriz de stages

| Stage | Status | Evidência |
|---|---|---|
| 0 — audit / setup | DONE_AND_PRESENT | Estrutura isolada, Git local e baseline `291ee67`. |
| 1 — reference / concept | DONE_AND_PRESENT | `WARRIOR_V3_DESIGN_LOCK.md`, folha canônica, master, cinco vistas 1536×1536, spec, provenance e QA completo. |
| 2 — raw 3D mesh | DONE_AND_PRESENT | `raw/Warrior_V3_RAW.glb`; QA PASS na seção SALVAGE candidate_01 de `raw/RAW_QA.md`; dez renders e comparação antes/depois/concept. |
| 3 — rig | DONE_AND_PRESENT | `rigged/Warrior_V3_RIGGED.glb`, `BONE_MAP.json`, `RIG_QA.md`; 23 bones, dez poses PASS, fonte Blender preservada. |
| 3A — static preview | PASS | STATIC_GODOT_PREVIEW = PASS; cena isolada `tools/warrior_v3/WarriorV3Preview.tscn`, cinco screenshots em `previews/godot_static/`. |
| 4 — sword/shield sockets | DONE_AND_PRESENT | GLBs independentes; variante EQUIPPABLE de 53 bones preserva rig aprovado; SOCKET QA = PASS; GODOT EQUIPMENT PREVIEW = PASS. Sete poses e quatro direções; `equipment/EQUIPMENT_QA.md`. |
| 5 — animations | PARTIAL | Auditoria de fontes e candidato de retarget Quaternius CC0 presentes em animations/work. Sete bases sem aprovação final; ajuste de equipamentos, contatos e fases pendente. |
| 6 — Godot integration | NOT_STARTED | Nenhuma cena/profile/flag V3. |
| 7 — UI | PARTIAL | Trabalho existente aplica-se somente ao Guerreiro legado. |
| 8 — final QA | NOT_STARTED | Não existe asset 3D V3 para QA final. |

## Autoridades do Stage 1

- `concept/WARRIOR_V3_DESIGN_LOCK.md` — contrato objetivo.
- `concept/warrior_v3_master.png` — autoridade frontal final.
- `concept/warrior_v3_turnaround_canonical.png` — autoridade multiângulo.
- `concept/warrior_v3_concept_spec.md` — especificação de produção.
- `concept/PROVENANCE.md` — histórico de geração, rejeições e simplificações.

## Vistas normalizadas

| Arquivo | Resolução | Altura visual | Ground line |
|---|---:|---:|---:|
| `warrior_v3_master.png` | 1536×1536 | 1200 px | Y=1360 |
| `warrior_v3_front.png` | 1536×1536 | 1200 px | Y=1360 |
| `warrior_v3_back.png` | 1536×1536 | 1200 px | Y=1360 |
| `warrior_v3_left.png` | 1536×1536 | 1200 px | Y=1360 |
| `warrior_v3_right.png` | 1536×1536 | 1200 px | Y=1360 |
| `warrior_v3_3q_front.png` | 1536×1536 | 1200 px | Y=1360 |

## Visual QA

| Critério | Resultado | Observação |
|---|---|---|
| IDENTITY | PASS | Cabelo azul, faixa creme, scarf vermelho e aventureiro leve inequívocos. |
| PROPORTIONS | PASS | Relação cabeça/corpo e comprimentos normalizados; linguagem 5–5,5 cabeças. |
| FRONT SILHOUETTE | PASS | T-pose limpa, membros separados, mãos e botas completos. |
| SIDE SILHOUETTE | PASS | Perfis opostos, mesmo corpo e volumes compatíveis. |
| BACK CONSISTENCY | PASS | Costas usam as mesmas camadas; nenhuma roupa/strap/pouch inventado. |
| HAIR CONSISTENCY | PASS | Crown, largura lateral e volume traseiro coerentes. |
| SCARF CONSISTENCY | PASS | Uma gola e uma única cauda curta posterior esquerda. |
| CLOTHING CONSISTENCY | PASS | Jerkin, cinto, bracers, calças e botas seguem o Design Lock. |
| T-POSE SUITABILITY | PASS | Braços/pernas separados, mãos e pés visíveis; oclusão natural apenas nos perfis ortográficos. |
| IMAGE-TO-3D SUITABILITY | PASS | Autoridade única, vistas normalizadas e contrato explícito para detalhes ocultos. |

## Simplificações aprovadas

- Zero pouches.
- Zero correias diagonais.
- Um cinto horizontal.
- Uma única cauda curta posterior esquerda no scarf.
- Elementos de braço e botas espelhados.

## Git

- Repositório: `C:/Users/gabri/Downloads/modo aventura 2d/prototipoPVP-Godot/.git`.
- Branch: `main`.
- Baseline: `291ee67 baseline before Warrior V3 reconstruction`.
- Commit de conclusão do Stage 1: `complete Warrior V3 concept turnaround` (consultar o HEAD do repositório).

## Próximo gate

Stage 3 DONE_AND_PRESENT; STATIC_GODOT_PREVIEW = PASS; commit `378779c`. Stage 4 DONE_AND_PRESENT: SOCKET QA = PASS e GODOT EQUIPMENT PREVIEW = PASS; commit `282a4bf`. Stage 5 PARTIAL: candidato de retarget em avaliação. Tripo recusou retarget do rig Mixamo (saldo devolvido, custo líquido zero); fontes CC0 Quaternius em uso. Próximo gate: motion QA com equipamentos, contatos e fases dos golpes. RAW e rigs aprovados preservados; nenhuma integração de combate.

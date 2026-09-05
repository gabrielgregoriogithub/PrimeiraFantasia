# Warrior_V3 — fonte de verdade

Última atualização: 2026-09-05 (America/Sao_Paulo)

## Objetivo

Produzir `Warrior_V3.glb` pela pipeline `reference -> concept -> raw mesh -> visual QA -> rig/skinning -> equipment/sockets -> animations -> Godot integration -> in-game QA`, mantendo gameplay e Guerreiro legado intactos até aprovação.

## Estado atual

`STAGE 1 — DONE_AND_PRESENT`. Design congelado, turnaround canônico e vistas normalizadas existem fisicamente e passaram em todos os critérios do QA do concept. `STAGE 2` continua `NOT_STARTED`; nenhum asset 3D foi criado nesta execução.

## Matriz de stages

| Stage | Status | Evidência |
|---|---|---|
| 0 — audit / setup | DONE_AND_PRESENT | Estrutura isolada, Git local e baseline `291ee67`. |
| 1 — reference / concept | DONE_AND_PRESENT | `WARRIOR_V3_DESIGN_LOCK.md`, folha canônica, master, cinco vistas 1536×1536, spec, provenance e QA completo. |
| 2 — raw 3D mesh | NOT_STARTED | Nenhum `Warrior_V3_RAW.glb` ou `.blend` V3. |
| 3 — rig | NOT_STARTED | Nenhum rig V3. |
| 4 — sword/shield sockets | NOT_STARTED | Nenhum equipamento/socket V3. |
| 5 — animations | NOT_STARTED | Nenhuma animação V3. |
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

Stage 2 — geração e QA do raw mesh — está liberado pelo concept, mas não foi iniciado. Qualquer execução futura deve usar Design Lock + master + turnaround canônico e respeitar o hard gate do raw mesh.

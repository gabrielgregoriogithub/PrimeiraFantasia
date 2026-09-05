# Warrior_V3 — RAW mesh QA

**Stage 2: DONE_AND_PRESENT. candidate_01 recovered locally and promoted after RAW QA PASS. Original generation results below remain historical FAIL; see SALVAGE candidate_01.**

Date: 2026-09-05 (America/Sao_Paulo). Stage 1 remains DONE_AND_PRESENT at commit `0a8cc48`.

## Generation and provenance

API: Tripo v3, POST https://openapi.tripo3d.ai/v3/generation/multiview-to-model.

The four canonical PNGs were uploaded separately and supplied as explicit front, left, back and right view-key inputs. The whole turnaround was not submitted. Paths, SHA-256 hashes and tokens are in `candidates/source_uploads.json` and each candidate JSON. All four Stage 1 documents were read and the four canonical images inspected.

TRIPO_API_KEY was AVAILABLE and authenticated; its value was never printed or persisted. After the initial zero-credit block, the user topped up the account. Balance before generation: 1,000. Final balance: **730 credits, 0 frozen**. Total consumed: **270 credits**.

P2 was preferred for its documented low-poly multiview and quad support. After two P2 results failed back consistency, the last attempt used P1, also a multiview low-poly model. Model capability is not proof of riggability.

| Candidate | Model | Geometry/texture seed | Requested face limit | Quad | Credits | GLB triangles | Materials | Texture |
|---|---|---:|---:|---|---:|---:|---:|---|
| candidate_01 | P2-20260801 | 2026090501 | 10,000 | true | 110 | 21,862 | 1 | 1 × 2048×2048 base color |
| candidate_02 | P2-20260801 | 2026090517 | 12,000 | true | 110 | 26,162 | 1 | 1 × 2048×2048 base color |
| candidate_03 | P1-20260311 | 2026090589 | 20,000 | omitted | 50 | 18,193 | 1 | 1 × 2048×2048 base color |

Common explicit settings: `texture=true`, `pbr=false`, `texture_quality=standard`, `texture_alignment=original_image`, `export_uv=true`. Both model_seed and texture_seed use the listed seed. PBR disabled for the painted stylized palette. export_orientation, orientation, auto_size and compression were omitted. Exact requests and server-returned inputs are preserved in each candidate JSON.

The requested face limit was not a strict final triangle cap. Candidate_01 FBX has 12,182 polygons, including 9,680 quads. Candidate_02 has 14,679 polygons, including 11,483 quads. Both exceed the approximate 8k–20k final triangle target; no decimation was performed.

| Candidate | Task ID |
|---|---|
| candidate_01 | f0980b28-dcbf-4cd3-bc36-83a3f02d64b5 |
| candidate_02 | 9249a1ed-c150-496f-9a65-44e1f39c80eb |
| candidate_03 | da9db7e3-ffae-4b95-a374-da1dfdf8b9dc |

One candidate_02 request was rejected before task creation: a PowerShell cache read produced an array instead of one string token per view. No generation or charge occurred for that request. The rejected payload is retained in candidate_02_rejected_request.json; the corrected accepted request uses exactly one token per view. There are exactly three accepted generation tasks.

Documentation consulted:
- https://developers.tripo3d.ai/en/docs/generation-multiview-to-model/p
- https://developers.tripo3d.ai/en/docs/files
- https://developers.tripo3d.com/en/docs/billing

## Serialized models and previews

P2 with quad=true delivered binary FBX. Both originals are preserved, with embedded 2048px color textures. Blender 4.5.11 imported and serialized them as GLB with standard format triangulation. No character geometry edits, sculpt, orientation override, scale normalization, ground adjustment or rigging were performed. Serialization reports record original and GLB hashes. P1 delivered a native GLB, preserved byte-for-byte.

Each GLB was reloaded from disk in a fresh Blender process for measurement and rendering. These are **local renders of the real serialized GLBs**, not remote previews. Cycles CPU, 24 samples with denoising, 1024×1024, neutral gray world, three broad area lights, orthographic cameras. Character geometry and materials were not edited for presentation.

Each `previews/raw/candidate_0N/` contains all seven required renders: front, back, left, right, 3q_front, 3q_back and isometric_game_camera; plus detail_head_front, detail_head_back and detail_hands_top. mesh_stats.json and render_manifest.json contain GLB hashes and camera settings.

Profile labels match canonical PNG facing directions for P2. Cameras use the returned coordinate system; the mesh was not normalized. Candidate_03 has a face on each opposite side and no coherent anatomical front/back; its labels identify the camera directions used for comparison.

[Open side-by-side comparison](../previews/raw/comparison.html). All seven angles are shown for all candidates; canonical images are included where available.

## QA matrix

PASS applies only to the individual criterion. T-POSE PASS means visible straight-arm pose and limb clearance, not certification of rig/deformation. TOPOLOGY FAIL means the mesh was not cleared for future rigging; boundaries alone are not treated as critical defects.

| Criterion | candidate_01 | candidate_02 | candidate_03 |
|---|---|---|---|
| IDENTITY | PASS | PASS | FAIL |
| FACE | PASS | PASS | FAIL |
| HAIR | PASS | PASS | FAIL |
| HEADBAND | PASS | PASS | FAIL |
| SCARF | PASS | PASS | FAIL |
| BODY SEPARATION | PASS | PASS | PASS |
| HANDS | PASS | PASS | FAIL |
| FEET | PASS | FAIL | FAIL |
| CLOTHING | FAIL | FAIL | FAIL |
| FRONT SILHOUETTE | PASS | PASS | FAIL |
| SIDE SILHOUETTE | PASS | FAIL | FAIL |
| BACK SILHOUETTE | FAIL | FAIL | FAIL |
| T-POSE | PASS | PASS | PASS |
| TOPOLOGY | FAIL | FAIL | FAIL |
| GAME CAMERA | PASS | FAIL | FAIL |
| **OVERALL / HARD GATES** | **FAIL** | **FAIL** | **FAIL** |

### candidate_01 — FAIL

Face retains correctly placed eyes, coherent nose and mouth, with minor texture softness. Hair is a readable blue lock mass; the cream band wraps behind the hair. Scarf retains one short posterior-left red tail, with relief from the back. Arms, legs, hands and boots are separate. The overhead render shows four fingers plus thumb per hand. T-pose and frontal/isometric identity read well.

**Hard rejection: incoherent back.** A second silver belt buckle appears at center back, together with front-style lower-jerkin center geometry absent from the canonical back. The invented buckle is visible in back, both profiles and 3q_back. No obvious large floating junk or arm-to-torso webbing was seen, but topology was not cleared.

This is the closest visual candidate, but **not approved or selected**.

### candidate_02 — FAIL

Face, blue hair, cream headband, single short red posterior-left scarf tail, hands and limb separation remain readable.

**Hard rejection: incoherent back and foot anatomy.** The model invents a rear buckle and oversized back buttons. One boot has a backwards toe and silver toe cap at the heel, producing an incorrect two-ended profile. These defects are visible in back, profiles, 3q_back and game camera.

More geometry did not fix the back and increased multi-face edges. No manual repair was attempted.

### candidate_03 — FAIL

**Hard rejection: doubled/deformed head and incoherent back.** A second face exists at the back of the head; another hair mass obscures an eye on the opposite face. Profiles show both faces simultaneously.

**Hard rejection: scarf and hair.** Scarf tails appear on opposite sides of the torso. A thin striped rectangular geometry artifact protrudes above the hair. The headband is distorted by the doubled head structure.

Hands show malformed/duplicated thumb geometry. Boot fronts/toe caps are duplicated toward the back. Clothing again has front/back buckle duplication. Arms and legs remain separate in T-pose, but the character is not rig-ready. Game-camera identity fails because the face is obscured by the broken head geometry.

## Topology diagnostics

GLB vertices include UV/normal splits. Diagnostics also weld coincident positions on an **in-memory copy only**, at height × 1e-7 tolerance, to avoid counting UV seams as physical holes. This copy was never saved or exported.

| Diagnostic after positional weld | candidate_01 | candidate_02 | candidate_03 |
|---|---:|---:|---:|
| Triangle faces | 21,862 | 26,162 | 18,193 |
| Boundary edges | 619 | 593 | 184 |
| Edges with more than two incident faces | 7 | 11 | 102 |
| Total non-manifold edges, including boundaries | 626 | 604 | 286 |
| Degenerate faces below height² × 1e-12 | 1 | 3 | 0 |
| Disconnected components | 37 | 36 | 77 |

Full component sizes and bounds are in mesh_stats.json. Some components are legitimate hair, scarf, clothing, buckles and buttons: component count alone does not prove floating junk, and open clothing borders can be intentional. Multi-face edges remain; none was certified clean for deformation. The independent visual hard failures already require regeneration. No rigging or deformation test was performed. No fused legs or critical arm-to-torso webbing was observed.

## Decision and hard stop

- Generated **3 of 3** allowed candidates.
- Consumed **110 + 110 + 50 = 270 credits**; remaining **730**, frozen **0**.
- Selected candidate: **none**. Visual ranking does not override a hard failure.
- `raw/Warrior_V3_RAW.glb`: **not created**. All candidate GLBs are retained in raw/candidates/.
- Stage 2: **PARTIAL**. No completion commit; changes remain in the working tree.
- No rig, animation, weapons, sockets or Godot integration. No fourth generation in this execution.


## SALVAGE candidate_01

**SALVAGE_SAFE. Cleanup aprovado; QA final PASS.** Revisão em 2026-09-05. Os três resultados Tripo originais continuam com os pareceres históricos FAIL acima. A aprovação aplica-se exclusivamente à cópia limpa do candidate_01. Nenhuma chamada Tripo, candidato adicional ou crédito gasto nesta recuperação.

Diagnóstico anterior à edição: [DIAGNOSIS.md](salvage_diagnostic/DIAGNOSIS.md). Inventário por grupo/aresta e classificação A/B: [TOPOLOGY_CLASSIFICATION.md](salvage_diagnostic/TOPOLOGY_CLASSIFICATION.md). Fonte única original preservada por SHA-256; nenhuma reconstrução estrutural.

| Defeito | Classe | Local / silhueta / riggability | Operação |
|---|---|---|---|
| Fivela, lingueta e passador traseiros | GEOMETRY_LOCAL | Centro posterior do cinto; saliência local; sem função anatômica | Removidos 280 triângulos; superfície do cinto existente preservada |
| Três botões frontais inventados nas costas | GEOMETRY_LOCAL + TEXTURE_ONLY | Centro das costas; sem efeito no contorno ou rig corporal | Removidos 66 triângulos e vestígios locais por UV |
| Aba sobreposta do cinto | TOPOLOGY_LOCAL / GEOMETRY_LOCAL | Cinto posterior lateral; artefato B | Removidas apenas 14 faces; eliminadas duas arestas multi-face |
| Ponta central extra na barra traseira | GEOMETRY_LOCAL | Pequena ponta entre painéis posteriores; sem alteração anatômica | Encurtada apenas região central estreita; painéis principais preservados |
| Vestígios de cor dos detalhes removidos | TEXTURE_ONLY | UVs locais de cinto/costas/barra | Reutilizados texels limpos de couro/calça da própria textura; imagem inteira intocada |
| Face colinear isolada | TOPOLOGY_LOCAL | Sobrancelha, área zero; não contribui à silhueta | Removida uma face; restante do rosto preservado |
| Componentes separados legítimos | A: superfície/acessório necessário | Olhos, sobrancelhas, lábios, cabelo, scarf, roupas e ferragens | Preservados; separação não foi confundida com floating junk |
| Contatos multi-face remanescentes | TOPOLOGY_LOCAL, A | Quatro arestas nos lábios; uma em ferragem de bota | Preservados para evitar alterar áreas protegidas; não são pontes entre membros |

Nenhum defeito STRUCTURAL identificado que exija reconstruir cabeça, tronco, cabelo, scarf, braços ou pernas. Foram removidas 361 faces no total; a união de faces removidas, movidas ou com UV alterado soma 572 (2,6164% do original). Sem remesh, decimate, smooth global ou normalização de orientação. Normais originais preservadas, exceto recálculo geométrico nas faces da pequena ponta ajustada. Nenhuma inversão nova detectada.

| Estatística | ORIGINAL | CLEANED serializado |
|---|---:|---:|
| Vértices GLB, incluindo separações UV/normais | 24.430 | 24.077 |
| Vértices por posição, diagnóstico somente | 11.257 | 11.052 |
| Triângulos | 21.862 | 21.501 |
| Arestas non-manifold incluindo bordas | 626 | 585 |
| Bordas abertas | 619 | 580 |
| Arestas com mais de duas faces | 7 | 5 |
| Faces degeneradas | 1 | 0 |
| Componentes por posição | 37 | 31 |
| Arestas soltas | 0 | 0 |
| Winding inconsistente em arestas manifold | 0 | 0 |
| Materiais | 1 | 1 |
| Textura base color | 2048×2048 | 2048×2048 |

O .blend de trabalho contém 23.951 vértices; a exportação separa vértices por atributos. A contagem topológica acima usa união por posição apenas numa cópia diagnóstica, nunca aplicada ao asset exportado. As 580 bordas são interfaces/bordas de peças, não 580 rasgos anatômicos. As cinco arestas multi-face A restantes estão documentadas individualmente. A malha não é watertight; o PASS de TOPOLOGY significa ausência de defeito crítico para este gate RAW corporal, não certificação de futura deformação facial. Nenhum rig foi feito ou testado.

### QA final e regressão

| Gate | Original | Cleaned | Evidência visual / conclusão |
|---|---|---|---|
| IDENTITY | PASS | PASS | Identidade Warrior_V3 preservada |
| FACE | PASS | PASS | Olhos/nariz/boca coerentes; sem regressão no detalhe frontal |
| HAIR | PASS | PASS | Massa azul e volume frontal/traseiro preservados |
| HEADBAND | PASS | PASS | Faixa presente e contínua sob cabelo |
| SCARF | PASS | PASS | Gola e uma cauda posterior esquerda preservadas |
| BODY SEPARATION | PASS | PASS | Braços livres do torso, pernas separadas |
| HANDS | PASS | PASS | Dedos distintos no detalhe superior; sem alteração |
| FEET | PASS | PASS | Botas completas e coerentes; sem alteração |
| CLOTHING | FAIL | PASS | Fivela frontal apenas; cinto traseiro simples; botões inventados removidos |
| FRONT SILHOUETTE | PASS | PASS | Contorno original preservado |
| SIDE SILHOUETTE | PASS | PASS | Apenas saliência traseira indevida removida |
| BACK SILHOUETTE | FAIL | PASS | Painéis coerentes com BACK canônico, ponta extra reduzida |
| T-POSE | PASS | PASS | Adequada à próxima fase de rig corporal |
| TOPOLOGY | FAIL | PASS | Artefatos B removidos; sem degeneradas; contatos A documentados |
| GAME CAMERA | PASS | PASS | Leitura isométrica preservada |

Todos os dez renders foram produzidos do GLB limpo reimportado por `tools/WarriorV3RawQA.py`, exatamente o pipeline dos candidatos originais, com a mesma câmera, iluminação e fundo. [Comparação original / cleaned / concept](../previews/raw/candidate_01_salvage_comparison.html). Referências canônicas front/back/left/right e turnaround confrontadas no diagnóstico; vistas correspondentes na comparação.

Sem regressão perceptível nas áreas protegidas. Comparação do GLB serializado confirmou 21.290 faces protegidas com posições e UVs iguais; variação máxima de vetor normal 0,0007054 por codificação do Blender. Nenhuma face ajustada invertida. SHA-256 da imagem incorporada idêntico antes/depois: não houve blur, upscale ou repintura global. A superfície local do cinto foi simplificada; mantém leitura contínua de couro.

Arquivos: `work/Warrior_V3_candidate_01_cleanup.blend`, `work/Warrior_V3_candidate_01_cleaned.glb`, `work/cleanup_operations.json`, `work/cleanup_verification.json` e renders em `../previews/raw/candidate_01_cleaned/`. Auditoria JSON preserva índices de faces, vértices ajustados, UVs e hashes.

Promoção aprovada para `Warrior_V3_RAW.glb`, cópia byte a byte do cleaned. Stage 2: **DONE_AND_PRESENT**. Sem rig, animações, equipamentos, sockets ou integração Godot.

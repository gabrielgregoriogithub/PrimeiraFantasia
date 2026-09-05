import json, hashlib, shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
B = ROOT / 'assets/characters/warrior_v3'
R = B / 'raw'
read = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))
v = read(R/'work/cleanup_verification.json')
assert v['critical_checks_pass']
src = R/'candidates/Warrior_V3_candidate_01.glb'
clean = R/'work/Warrior_V3_candidate_01_cleaned.glb'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(src) == v['original']['sha256']
assert sha(clean) == v['cleaned']['sha256']
views = ['front','back','left','right','3q_front','3q_back','isometric_game_camera','detail_head_front','detail_head_back','detail_hands_top']
for n in views:
    assert (B/'previews/raw/candidate_01_cleaned'/f'{n}.png').is_file()
d = read(R/'salvage_diagnostic/diagnosis.json')
names = {0:'corpo/jerkin/cinto/bracos',1:'calcas e botas',2:'cabelo',3:'cabeca e gola scarf',4:'cauda scarf',5:'fivela frontal',10:'fivela traseira',11:'ferragem bota',12:'sobrancelha',13:'sobrancelha',14:'boca',16:'olho',17:'olho',20:'labio',21:'labio',22:'fivela frontal',23:'fivela frontal',26:'lingueta traseira',27:'passador traseiro',28:'rebite braco',29:'botao frontal',30:'botao frontal',31:'botao frontal',32:'botao frontal',33:'botao traseiro',34:'botao traseiro',35:'botao traseiro',36:'rebite braco'}
removed = {10,26,27,33,34,35}
lines = ['# Inventario A/B de topologia — candidate_01', '', 'Coordenadas Blender, altura ~1; IDs referem-se ao diagnostico original. A = superficie/acessorio necessario; B = artefato indevido. Bordas abertas de montagem nao foram fechadas globalmente. Cada grupo abaixo tem limites exatos em diagnosis.json.', '', '| Grupo de borda | Componente | Local | A/B | Arestas | Acao |','|---|---|---|---|---:|---|']
for g in d['boundary_groups']:
    c=g['component']; action='Removido com detalhe indevido' if c in removed else 'Preservado; borda de superficie/peca necessaria'
    if c==0: action='Preservado exceto folha sobreposta de 14 faces do cinto (B); sem fechamento global'
    lines.append(f"| {g['id']} | {c} | {names.get(c,'ferragem bota')} | {'B' if c in removed else 'A (com excecao local B no cinto)' if c==0 else 'A'} | {g['edges']} | {action} |")
lines += ['', '| Aresta multi-face | Componente | Centro XYZ | A/B | Acao |','|---|---|---|---|---|']
for e in d['branch_edges']:
    c=e['component']; action='Removida a folha sobreposta do cinto' if c==0 else 'Preservada: contato de labios; reparo pode alterar rosto' if c==3 else 'Preservada: contato de duas folhas de ferragem; nao alterar pe'
    lines.append(f"| {e['edge']} | {c} | {e['center']} | {'B' if c==0 else 'A'} | {action} |")
lines += ['', 'As cinco arestas A restantes nao conectam bracos ao torso nem pernas entre si. O QA estatico nao identifica defeito estrutural de rig corporal. Deformacao facial/skinning nao foi testada: nenhum rig foi criado. A malha nao e watertight.']
(R/'salvage_diagnostic/TOPOLOGY_CLASSIFICATION.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
html = ['<!doctype html><html lang="pt-BR"><meta charset="utf-8"><title>Warrior V3 — Salvage</title><style>body{font:16px system-ui;background:#202225;color:#eee;margin:24px}section{margin-bottom:40px}.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:12px}img{width:100%}a{color:#8cf}figure{margin:0}figcaption{padding:8px}</style><h1>candidate_01: original / cleaned / concept</h1><p>SALVAGE_SAFE — QA PASS. Renders dos GLBs serializados pelo mesmo pipeline Blender. 21.862 → 21.501 triângulos. Textura original preservada. Referências 2D têm iluminação própria.</p>']
for n in views:
    ref = n if n in ['front','back','left','right','3q_front'] else 'back' if n in ['3q_back','detail_head_back'] else 'front'
    html.append(f'<section><h2>{n}</h2><div class="grid"><figure><img src="candidate_01/{n}.png"><figcaption>ORIGINAL</figcaption></figure><figure><img src="candidate_01_cleaned/{n}.png"><figcaption>CLEANED</figcaption></figure><figure><img src="../../concept/warrior_v3_{ref}.png"><figcaption>Concept {ref} — referência de design</figcaption></figure></div></section>')
html.append('<p><a href="../../raw/RAW_QA.md">RAW QA</a></p></html>')
(B/'previews/raw/candidate_01_salvage_comparison.html').write_text('\n'.join(html),encoding='utf-8')
report = '''

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
'''
qa = R/'RAW_QA.md'
old = qa.read_text(encoding='utf-8-sig')
old = old.replace('**Stage 2: PARTIAL. Three candidates generated; all FAIL. None promoted.**','**Stage 2: DONE_AND_PRESENT. candidate_01 recovered locally and promoted after RAW QA PASS. Original generation results below remain historical FAIL; see SALVAGE candidate_01.**')
qa.write_text(old+report,encoding='utf-8')
shutil.copyfile(clean,R/'Warrior_V3_RAW.glb')
assert sha(R/'Warrior_V3_RAW.glb')==sha(clean)
status=B/'STATUS.md'
s=status.read_text(encoding='utf-8-sig')
a=s.index('`STAGE 1'); z=s.index('\n\n',a)
s=s[:a]+'`STAGE 1 — DONE_AND_PRESENT`. `STAGE 2 — DONE_AND_PRESENT`: candidate_01 recuperado com cleanup local no Blender e aprovado nos gates RAW. `raw/Warrior_V3_RAW.glb` presente: 21.501 triângulos, 1 material, textura 2048×2048. Original intocado; recuperação sem créditos adicionais. Histórico Tripo: 270 créditos.'+s[z:]
s='\n'.join('| 2 — raw 3D mesh | DONE_AND_PRESENT | `raw/Warrior_V3_RAW.glb`; QA PASS na seção SALVAGE candidate_01 de `raw/RAW_QA.md`; dez renders e comparação antes/depois/concept. |' if line.startswith('| 2 ') else line for line in s.splitlines())+'\n'
a=s.index('## Próximo gate')
s=s[:a]+'''## Próximo gate

Stage 2 concluído após recuperação autorizada do candidate_01. Fivela e botões traseiros removidos; 2,62% das faces envolvidas. Permanecem cinco contatos multi-face necessários em lábios/ferragem, documentados no QA. Nenhuma deformação com rig foi testada. Parada após RAW QA: rig, animações, equipamentos/sockets e Godot não iniciados. Nenhum candidate_04; nenhum crédito adicional.
'''
status.write_text(s,encoding='utf-8')
print('PROMOTED '+sha(clean))

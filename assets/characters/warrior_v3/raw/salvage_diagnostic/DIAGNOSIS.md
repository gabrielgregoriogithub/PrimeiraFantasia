# SALVAGE candidate_01 — diagnóstico anterior à edição

Decisão: **SALVAGE_SAFE para operações locais e conservadoras**, ainda sujeito ao QA de regressão e à aprovação de todos os gates. Fonte única: Warrior_V3_candidate_01.glb. Nenhum candidato novo e nenhuma chamada Tripo.

Coordenadas Blender: +X frente, -X costas, Z vertical, altura aproximadamente 1 unidade. O GLB original não foi editado. diagnosis.json e local_regions.json foram calculados em cópias diagnósticas em memória.

| Item | Classe | Local aproximado | Silhueta | Riggability | Conduta local |
|---|---|---|---|---|---|
| Fivela traseira | GEOMETRY_LOCAL | centro do cinto, X=-0,083, Z=0,04; componente 10, 192 triângulos | pequena saliência indevida nos perfis | acessório sem papel anatômico | remover a peça; há cinto contínuo por baixo |
| Lingueta da fivela e passador | GEOMETRY_LOCAL | componentes 26 e 27; cinto traseiro | só o relevo indevido | sem papel anatômico | remover 50+38 triângulos |
| Aba de ponta do cinto | TOPOLOGY_LOCAL / GEOMETRY_LOCAL | X=-0,06, Y=-0,07, Z=0,04 | saliência local | sobreposição desnecessária | remover folha de 14 faces; explica 2 arestas com 3 faces |
| Botões traseiros | GEOMETRY_LOCAL + TEXTURE_ONLY | componentes 33–35, centro das costas Z=0,11–0,21 | não muda contorno externo | sem papel anatômico | remover 66 triângulos; corrigir somente vestígios locais de cor/UV |
| Vestígio de fivela na cor do cinto | TEXTURE_ONLY | superfície atrás da fivela | não | não | mapear somente a área traseira para couro limpo da própria textura |
| Ponta central extra na barra traseira | GEOMETRY_LOCAL | centro posterior da barra, Z aproximadamente -0,10 | pequeno detalhe indevido na barra | não exige remodelar tronco/pernas | limitar ao detalhe central, preservar painéis principais; abandonar ajuste se tocar forma boa |
| 37 componentes desconectados | mistura A necessária / B detalhe indevido | mapa completo em diagnosis.json | depende da peça | não são 37 fragmentos de lixo | manter olhos, sobrancelhas, boca, cabelo, scarf, corpo, calças/botas e ferragens legítimas |
| 4 arestas multi-face na boca | TOPOLOGY_LOCAL, A superfície necessária | X=0,063, Z=0,306; cantos da boca | sem mudança externa grande no original | contato/sobreposição local de superfícies; não certificar deformação facial | preservar: não remover lábios nem remodelar rosto para zerar contagem |
| 1 aresta multi-face em ferragem de bota | TOPOLOGY_LOCAL, A acessório necessário | X=-0,005, Y=0,12, Z=-0,417 | só ferragem | não está em joelho/tornozelo anatômico | preservar duas folhas legítimas que se encontram; não apagar por tamanho |
| 619 bordas abertas | TOPOLOGY_LOCAL / bordas de montagem A | 41 grupos registrados, pescoço, cintura, roupas, detalhes faciais e ferragens | predominantemente ocultas ou bordas das peças | não equivalem automaticamente a rasgos críticos | classificar por grupo; não fechar globalmente |
| 1 face degenerada | TOPOLOGY_LOCAL | componente 12, sobrancelha; área exatamente zero | nenhuma contribuição de área | sem papel estrutural | remover só a face colinear; manter todos os outros elementos faciais |
| Normais/winding | sem inversão inequívoca detectada | 0 arestas manifold com winding inconsistente | preservar aparência | sem correção global necessária | preservar normais de canto originais |

O inventário de componentes e grupos de bordas será preservado, incluindo classificação A/B e ações. A fronteira de 5% é um teto de segurança, não uma meta. As peças traseiras removíveis somam 360 triângulos; a face zero acrescenta 1. A região ampla de diagnóstico da barra contém somente 91 faces (0,42% do total), mas inclui bordas dos painéis principais: **não apagar essa seleção inteira**. Qualquer ajuste deve usar uma sub-região central mais estreita.

Nenhum diagnóstico exige remodelar cabeça, cabelo, braços, pernas ou proporções. As zonas protegidas conservarão posições, UVs e normais; a face de área zero não contribui à aparência. Não haverá remesh, decimate, smooth global nem reconstrução integral. Uma eventual limpeza ainda poderá ser rejeitada no QA final.

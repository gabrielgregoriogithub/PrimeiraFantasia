# Sprites dos Guardians

33 imagens estáticas (128x128) baixadas de
https://github.com/lucidtanooki/guardian_monsters
(`Assets/Images/Monsters/128x128/{id}_{form}.png`), uma por espécie/forma
listada em `guardians.json` (14 famílias, 33 formas no total).

**Autor:** Georg Eckert, 2015 ("FriendsWithMonsters" — nome antigo do projeto).

**Licença: CC-BY-SA-4.0** (ver `LICENSE.txt` nesta pasta, copiado do
repositório original) — **atenção**: é *ShareAlike*, não CC-BY-3.0 simples
como o README geral do repositório sugere. Isso significa:

- É obrigatório dar crédito ao autor original (Georg Eckert) em algum lugar
  visível do jogo/créditos.
- Qualquer versão modificada dessas imagens específicas (recorte, cor,
  edição) precisa continuar sob a mesma licença CC-BY-SA-4.0 se for
  redistribuída.
- **Isso NÃO "contamina" o código do jogo nem os outros assets** — ShareAlike
  em CC se aplica à obra derivada da imagem em si (ex.: uma versão editada
  do sprite do Fordin), não ao jogo inteiro que só a exibe. Ainda assim, se
  em algum momento vocês pretenderem fechar o código-fonte ou vender o jogo,
  vale uma checagem jurídica própria antes — isto aqui não é aconselhamento
  legal.

Cada monstro só tem UMA imagem estática (sem sprite sheet de andar/ataque)
— por isso o jogo usa a mesma imagem tanto como portrait de seleção quanto
como sprite parado em combate (ver `{key}_idle_down_1.png` e
`{key}_portrait.png`, arquivos idênticos).

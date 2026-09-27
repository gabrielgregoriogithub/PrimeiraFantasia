# PrimeiraFantasia — combate online por convite

O cliente continua sendo o projeto Godot da raiz e o servidor roda em um
processo separado. O GitHub Pages serve apenas os arquivos exportados do jogo;
ele não hospeda as salas.

## Rodar localmente

Na raiz do projeto, com Godot 4.7.2 disponível:

```text
godot --headless --path . --script res://server/online_server.gd -- --port=9080
```

Depois exporte o projeto para Web e sirva a pasta exportada por um servidor
HTTP local. Abra duas janelas apontando para a mesma URL. Em uma escolha
`CRIAR PARTIDA ONLINE`, copie o link exibido e abra-o na outra janela.

O endereço local padrão está em `project.godot`:

```ini
[online]
production=false
server_url="ws://127.0.0.1:9080"
```

Para publicar, altere somente a URL pública, sem credenciais:

```ini
[online]
production=true
server_url="wss://online.seu-dominio.example"
```

O servidor público precisa aceitar WebSocket seguro (`wss://`), manter a porta
do serviço acessível e encaminhar `Upgrade: websocket` no proxy reverso. Um
certificado TLS válido é obrigatório para o navegador quando o jogo estiver
em HTTPS no GitHub Pages.

## Fluxo implementado

- menu com `Criar partida online` e `Entrar em partida`;
- código de seis caracteres e link `?sala=ABC123`;
- sala limitada a exatamente dois jogadores;
- status de conexão, jogadores presentes, prontos e cópia do convite;
- reconexão pelo mesmo link/código durante a vida da sala, preservando o slot;
- servidor headless usando `GameState` e as regras atuais do projeto;
- movimento, ataque, fim de turno, habilidades, efeitos de área, invocações,
  voo, montagem/desmontagem e ações da Vestruz enviados como comandos ao
  servidor;
- o servidor valida o turno, o ator, o item, o alvo e a ação, resolve RNG uma
  única vez e envia snapshots para os dois clientes;
- o modo local não usa o endpoint online e permanece inalterado.

## Publicar no GitHub Pages

1. Exporte o projeto Godot como Web para uma pasta de publicação.
2. Configure o `server_url` com o endereço `wss://` real antes da exportação.
3. Publique a pasta exportada na branch/pasta configurada no GitHub Pages.
4. Execute o servidor `server/online_server.gd` separadamente, em uma VM,
   container ou serviço de hospedagem com TLS/proxy WebSocket.

Ainda falta configurar a hospedagem pública do servidor e substituir o
placeholder `wss://SEU_SERVIDOR_DE_PARTIDAS.example`; sem isso, o modo online
funciona localmente, mas não pela internet. O GitHub Pages sozinho não resolve
essa parte.

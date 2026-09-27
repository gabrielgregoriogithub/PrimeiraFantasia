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

## Hospedar o servidor de verdade (Render, plano grátis)

O `server/Dockerfile` empacota só o necessário para rodar o servidor
(`project.godot`, `autoload/`, `data/`, `online/`, `server/` — sem assets, sem
cenas), baixando o próprio Godot dentro da imagem. Passo a passo:

1. **Crie uma conta em https://render.com** (dá pra entrar direto com a conta
   do GitHub).
2. No painel, clique em **New +** → **Web Service**.
3. Escolha **Build and deploy from a Git repository** e conecte o repositório
   `gabrielgregoriogithub/PrimeiraFantasia` (autorize o Render a acessar sua
   conta do GitHub se ele pedir).
4. Na tela de configuração do serviço:
   - **Name**: qualquer nome, por exemplo `primeirafantasia-server`.
   - **Region**: a mais próxima de você (ex.: Ohio ou São Paulo, se disponível).
   - **Branch**: `main`.
   - **Runtime**: escolha **Docker**.
   - **Dockerfile Path**: `server/Dockerfile`.
   - **Docker Build Context Directory**: `.` (a raiz do repositório).
   - **Instance Type**: **Free**.
5. Clique em **Create Web Service**. O Render vai baixar o repositório,
   construir a imagem (baixa o Godot lá dentro, leva alguns minutos na
   primeira vez) e iniciar o container.
6. Acompanhe a aba **Logs** até aparecer a linha
   `PrimeiraFantasia online server ouvindo em ws://0.0.0.0:...` — é o sinal de
   que o servidor subiu. (O Render injeta a porta pela variável de ambiente
   `PORT`; o servidor já lê isso automaticamente.)
7. No topo da página do serviço, copie a URL pública, algo como
   `https://primeirafantasia-server.onrender.com`. Troque `https://` por
   `wss://` — esse é o seu `server_url`:
   `wss://primeirafantasia-server.onrender.com`.
8. Edite `project.godot` na raiz do projeto:

   ```ini
   [online]
   production=true
   server_url="wss://primeirafantasia-server.onrender.com"
   ```

9. Faça commit e *push* dessa mudança em `project.godot` para `main`. Isso
   dispara automaticamente o workflow `.github/workflows/publish-pages.yml`,
   que reexporta o jogo Web já com o novo `server_url` e publica no GitHub
   Pages — não precisa exportar manualmente.
10. Espere a aba **Actions** do repositório no GitHub terminar (ícone verde),
    depois abra `https://gabrielgregoriogithub.github.io/PrimeiraFantasia/`
    em duas abas/dispositivos diferentes: em uma clique **Criar partida
    online**, copie o link e abra na outra. Se prontos nos dois lados a
    partida deve começar.

**Sobre o plano grátis do Render**: o container "dorme" depois de ~15 minutos
sem conexões e leva uns 30-60s pra acordar na próxima tentativa (o primeiro
`Conectando ao servidor…` pode demorar um pouco nesse caso) — normal para uso
casual por convite, não para um servidor sempre ativo. Se isso incomodar,
qualquer outra hospedagem que rode um Dockerfile e exponha uma porta HTTP/WS
com TLS automático (Fly.io, Railway, um VPS com Caddy/nginx na frente) serve
do mesmo jeito; o que importa é o container rodar
`godot --headless --path /app --script res://server/online_server.gd` e ficar
acessível por `wss://`.

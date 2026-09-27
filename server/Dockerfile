# Imagem do processo de partidas online (server/online_server.gd).
#
# Build local, se quiser testar antes de hospedar:
#   docker build -t primeirafantasia-server -f server/Dockerfile .
#   docker run --rm -p 9080:9080 -e PORT=9080 primeirafantasia-server

FROM debian:bookworm-slim

ARG GODOT_RELEASE=4.7.2-stable

# Bibliotecas que o binário do Godot precisa em tempo de execução (mesmo
# headless): sem elas o processo falha ao subir (ex.: "libfontconfig.so.1:
# cannot open shared object file").
RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		curl unzip ca-certificates \
		libfontconfig1 libx11-6 libxcursor1 libxinerama1 libxi6 libxrandr2 \
		libxrender1 libxext6 libgl1 libglu1-mesa libasound2 libpulse0 \
	&& rm -rf /var/lib/apt/lists/*

# downloads.godotengine.org às vezes devolve a página de download (HTML) em
# vez do .zip para downloads automatizados fora do GitHub Actions; os
# releases do GitHub servem o binário de verdade de forma estável.
RUN set -eu; \
	url="https://github.com/godotengine/godot/releases/download/${GODOT_RELEASE}/Godot_v${GODOT_RELEASE}_linux.x86_64.zip"; \
	curl -fSL --retry 5 --retry-delay 3 --retry-connrefused "$url" -o /tmp/godot.zip; \
	test -s /tmp/godot.zip; \
	unzip -q /tmp/godot.zip -d /opt/godot; \
	chmod +x "/opt/godot/Godot_v${GODOT_RELEASE}_linux.x86_64"; \
	ln -s "/opt/godot/Godot_v${GODOT_RELEASE}_linux.x86_64" /usr/local/bin/godot; \
	rm /tmp/godot.zip

WORKDIR /app
# Copia o projeto inteiro (não só autoload/data/online/server): o GameState,
# Units, ScenarioManager etc. usam `class_name`, e o Godot só resolve esses
# nomes globais depois de importar o projeto pelo menos uma vez — o passo
# abaixo precisa do projeto completo (inclusive scenes/ e assets/) para isso
# funcionar do mesmo jeito que já funciona no workflow do GitHub Pages.
COPY . .

# Importa o projeto e constrói o cache de classes globais. Sem este passo,
# os autoloads (OnlineEndpoint, AudioEngine) falham ao carregar com erros do
# tipo "Identifier 'GameState' not declared in the current scope".
RUN godot --headless --path /app --editor --quit --display-driver headless --audio-driver Dummy || true

EXPOSE 9080
CMD ["godot", "--headless", "--path", "/app", "--script", "res://server/online_server.gd"]

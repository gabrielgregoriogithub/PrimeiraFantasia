# Imagem do processo de partidas online (server/online_server.gd).
# Não inclui assets/, scenes/, tests/ nem tools/: o servidor só roda a lógica
# de jogo (autoload/ + data/ + online/), sem tela nem áudio.
#
# Build local, se quiser testar antes de hospedar:
#   docker build -t primeirafantasia-server -f server/Dockerfile .
#   docker run --rm -p 9080:9080 -e PORT=9080 primeirafantasia-server

FROM debian:bookworm-slim

ARG GODOT_VERSION=4.7.2
ARG GODOT_RELEASE=4.7.2-stable

RUN apt-get update \
	&& apt-get install -y --no-install-recommends curl unzip ca-certificates \
	&& rm -rf /var/lib/apt/lists/*

RUN curl -fL "https://downloads.godotengine.org/${GODOT_VERSION}/Godot_v${GODOT_RELEASE}_linux.x86_64.zip" -o /tmp/godot.zip \
	&& unzip -q /tmp/godot.zip -d /opt/godot \
	&& chmod +x "/opt/godot/Godot_v${GODOT_RELEASE}_linux.x86_64" \
	&& ln -s "/opt/godot/Godot_v${GODOT_RELEASE}_linux.x86_64" /usr/local/bin/godot \
	&& rm /tmp/godot.zip

WORKDIR /app
COPY project.godot ./project.godot
COPY autoload ./autoload
COPY data ./data
COPY online ./online
COPY server ./server

EXPOSE 9080
CMD ["godot", "--headless", "--path", "/app", "--script", "res://server/online_server.gd"]

extends Node

## Processo separado do jogo. Execute na raiz do projeto:
## godot --headless --path . --script res://server/online_server.gd -- --port=9080
func _ready() -> void:
	var port := 9080
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="): port = int(arg.trim_prefix("--port="))
	# O autoload OnlineEndpoint já foi criado pelo project.godot; o servidor
	# apenas troca esse endpoint para o modo servidor.
	var endpoint: Node = get_node("/root/OnlineEndpoint")
	var err: Error = endpoint.start_server(port)
	if err != OK:
		push_error("Falha ao abrir o servidor WebSocket na porta %d: %s" % [port, error_string(err)])
		get_tree().quit(1)
		return
	print("PrimeiraFantasia online server ouvindo em ws://0.0.0.0:%d" % port)

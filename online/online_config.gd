class_name OnlineConfig
extends RefCounted

## Configuração pública do transporte online. Nenhum segredo deve ser colocado
## aqui: a autenticação da sala é feita pelo código curto e pelo servidor.
const DEV_SERVER_URL := "ws://127.0.0.1:9080"
const PROD_SERVER_URL := "wss://SEU_SERVIDOR_DE_PARTIDAS.example"
const DEFAULT_ROOM_LENGTH := 6

static func server_url() -> String:
	var production := bool(ProjectSettings.get_setting("online/production", false))
	var configured := String(ProjectSettings.get_setting("online/server_url", ""))
	if not configured.is_empty():
		return configured
	return PROD_SERVER_URL if production else DEV_SERVER_URL

static func room_from_url() -> String:
	if OS.has_feature("web") and ClassDB.class_exists("JavaScriptBridge"):
		var query = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('sala') || ''")
		return String(query).to_upper()
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--room="):
			return arg.trim_prefix("--room=").to_upper()
	return ""

static func invite_url(room_code: String) -> String:
	if OS.has_feature("web") and ClassDB.class_exists("JavaScriptBridge"):
		var value = JavaScriptBridge.eval("window.location.origin + window.location.pathname")
		return "%s?sala=%s" % [String(value).trim_suffix("/"), room_code]
	return "http://localhost:8060/?sala=%s" % room_code

static func copy_to_clipboard(value: String) -> void:
	DisplayServer.clipboard_set(value)
	if OS.has_feature("web") and ClassDB.class_exists("JavaScriptBridge"):
		JavaScriptBridge.eval("navigator.clipboard?.writeText(%s)" % JSON.stringify(value))

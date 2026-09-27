class_name CharacterAnchors2D
extends Node2D

## Pontos utilitários nomeados de um AdvancedCharacter2D — hoje (unit_token.gd)
## posições como "onde sai o projétil"/"onde acerta o dano" são offsets
## calculados na hora (`projectile_visual_origin`/`visual_impact_point`), não
## nós de verdade. Aqui viram Marker2D reais, filhos desta classe, pra
## qualquer sistema futuro (weapon trail, VFX, projétil) ler a posição global
## sem precisar recalcular nada.
##
## Posições em unidades de tile-local (pixels relativos ao personagem),
## pensadas pra uma sprite de ~64px de altura parada num tile — chamadores
## que usam sprites de outro tamanho podem reposicionar os Marker2D depois de
## `_ready()` sem quebrar a lista de nomes.

var head: Marker2D
var chest: Marker2D
var hand_left: Marker2D
var hand_right: Marker2D
var weapon_base: Marker2D
var weapon_tip: Marker2D
var cast_origin: Marker2D
var feet: Marker2D
var impact_origin: Marker2D
var ui_anchor: Marker2D

## Nome -> posição local default. Ordem não importa; só existe pra
## `_ready()` e os testes iterarem sem repetir a lista duas vezes.
const DEFAULT_POSITIONS := {
	"head": Vector2(0, -58),
	"chest": Vector2(0, -38),
	"hand_left": Vector2(-14, -34),
	"hand_right": Vector2(14, -34),
	"weapon_base": Vector2(16, -30),
	"weapon_tip": Vector2(30, -60),
	"cast_origin": Vector2(0, -44),
	"feet": Vector2(0, 0),
	"impact_origin": Vector2(0, -32),
	"ui_anchor": Vector2(0, -70),
}

func _ready() -> void:
	for anchor_name in DEFAULT_POSITIONS:
		var marker := Marker2D.new()
		marker.name = anchor_name
		marker.position = DEFAULT_POSITIONS[anchor_name]
		add_child(marker)
		set(anchor_name, marker)

## Devolve o Marker2D pelo nome (mesmas chaves de DEFAULT_POSITIONS) — útil
## pra código que só tem a string (ex.: vindo de um Resource/config) em vez
## do identificador direto.
func get_anchor(anchor_name: String) -> Marker2D:
	return get(anchor_name) as Marker2D

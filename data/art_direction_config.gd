extends RefCounted
class_name ArtDirectionConfig

## Direção de arte única: fantasia cartoon 2.5D. Os valores são sutis para
## harmonizar os assets existentes sem apagar suas cores próprias.
const PALETTE := {
	"ink": Color("25243a"), "ink_soft": Color("35364d"),
	"parchment": Color("ead7aa"), "parchment_light": Color("f6e9c5"),
	"gold": Color("d7a94c"), "gold_light": Color("ffe08a"),
	"move": Color("4ca7e8"), "attack": Color("ed635f"),
	"heal": Color("68d890"), "buff": Color("c58ae8"),
	"debuff": Color("e18758"), "objective": Color("f2c65d"),
	"ally": Color("62b6ef"), "enemy": Color("e66b70"),
	"fire_core": Color("fff0ad"), "fire_mid": Color("ffad3d"), "fire_edge": Color("e95432"),
	"ice_core": Color("e8fbff"), "ice_mid": Color("7fd4ee"), "ice_shadow": Color("3978b8"),
	"lightning_core": Color("f4fdff"), "lightning_glow": Color("72d7f2"),
	"poison": Color("86c951"), "healing": Color("79dfa0"),
}

const GLOBAL := {
	"character_saturation": 1.08, "character_contrast": 1.06,
	"environment_saturation": 0.92, "environment_contrast": 0.94,
	"outline_strength": 0.31, "shadow_opacity": 0.82,
	"ui_shadow_strength": 0.42, "vfx_brightness": 0.94,
	"light_direction": Vector2(-0.62, -0.78),
}

const DEFAULT_BIOME := {
	"ambient_tint": Color(0.16, 0.20, 0.25, 0.035),
	"environment_tint": Color("f2f0e8"), "shadow_tint": Color("292a45"),
	"water_tint": Color("65b8ca"), "background_saturation": 0.92,
	"ambient_particles": "dust", "ambient_light": 0.92,
}

const BIOMES := {
	"field": {"ambient_tint":Color(0.10,0.25,0.16,0.045),"environment_tint":Color("eef3dc"),"shadow_tint":Color("263b3a"),"water_tint":Color("65bdc9"),"background_saturation":0.90,"ambient_particles":"leaves","ambient_light":0.98},
	"village": {"ambient_tint":Color(0.34,0.20,0.08,0.045),"environment_tint":Color("fff0d2"),"shadow_tint":Color("3c3040"),"water_tint":Color("69b8c5"),"background_saturation":0.92,"ambient_particles":"dust","ambient_light":1.0},
	"forest": {"ambient_tint":Color(0.06,0.22,0.16,0.065),"environment_tint":Color("dcebd9"),"shadow_tint":Color("263b42"),"water_tint":Color("58aeb9"),"background_saturation":0.88,"ambient_particles":"leaves","ambient_light":0.93},
	"lua_valley": {"ambient_tint":Color(0.08,0.18,0.24,0.055),"environment_tint":Color("dcecf0"),"shadow_tint":Color("27344d"),"water_tint":Color("55afc7"),"background_saturation":0.90,"ambient_particles":"mist","ambient_light":0.94},
	"tower": {"ambient_tint":Color(0.11,0.12,0.20,0.075),"environment_tint":Color("dfe3eb"),"shadow_tint":Color("2d2945"),"water_tint":Color("598da5"),"background_saturation":0.84,"ambient_particles":"dust","ambient_light":0.88},
	"volcanic": {"ambient_tint":Color(0.38,0.09,0.025,0.065),"environment_tint":Color("f0d8c4"),"shadow_tint":Color("3e2636"),"water_tint":Color("577e91"),"background_saturation":0.87,"ambient_particles":"embers","ambient_light":0.90},
}

static func biome_for(scenario_id: String) -> Dictionary:
	if scenario_id in ["tower_floor_3", "tower_floor_4"]: return BIOMES["volcanic"].duplicate(true)
	if scenario_id.begins_with("tower"): return BIOMES["tower"].duplicate(true)
	return BIOMES.get(scenario_id, DEFAULT_BIOME).duplicate(true)

static func make_ui_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 16
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("2f3045e8"); normal.border_color = PALETTE["gold"]
	normal.set_border_width_all(2); normal.set_corner_radius_all(7)
	normal.shadow_color = Color(PALETTE["ink"], float(GLOBAL["ui_shadow_strength"])); normal.shadow_size = 4
	normal.set_content_margin_all(7)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("41435c"); hover.border_color = PALETTE["gold_light"]
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("232438"); pressed.border_color = PALETTE["objective"]
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("3435449a"); disabled.border_color = Color("77798a")
	for pair in [["normal",normal],["hover",hover],["pressed",pressed],["focus",hover],["disabled",disabled]]:
		theme.set_stylebox(pair[0], "Button", pair[1])
	theme.set_color("font_color", "Button", PALETTE["parchment_light"])
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", PALETTE["gold_light"])
	theme.set_color("font_disabled_color", "Button", Color("9a9baa"))
	return theme

class_name AnimalSpriteCatalog
extends RefCounted

## Bichos do SPD (spd_*) usam folhas únicas com regiões auditadas
## visualmente ([x, y, largura, altura] via _r()); os cinco humanoides da
## Torre (tower_*) usam pastas com um PNG recortado por quadro — ver
## _folder_spec() mais abaixo. Em ambos os casos UnitToken ancora a caixa
## pela base, então frames com dimensões diferentes não fazem os pés saltarem.
const SHEET_ROOT := "res://assets/enemies/animals/"

static func _r(x: int, y: int, w: int, h: int) -> Array: return [x,y,w,h]

static func build() -> Dictionary:
	var rat_idle_down := [_r(58,57,112,153), _r(205,57,112,153)]
	var rat_idle_up := [_r(345,57,171,153)]
	var rat_idle_side := [_r(535,57,171,153), _r(728,57,181,153)]
	var rat_walk_down := [_r(54,229,116,158), _r(204,229,143,158)]
	var rat_walk_up := [_r(405,229,127,158), _r(585,229,116,158)]
	var rat_walk_side := [_r(742,229,191,158), _r(940,229,196,158)]
	var rat_attack := []
	for x in [25,165,305,445,585,725,865,1005,1145,1285,1425,1565,1705]: rat_attack.append(_r(x,580,176,168))

	var snake_idle_down := [_r(20,74,91,145),_r(108,74,92,145),_r(200,74,91,145),_r(298,74,102,145)]
	var snake_idle_up := [_r(418,74,96,145),_r(514,74,96,145),_r(613,74,96,145),_r(707,74,94,145)]
	var snake_idle_side := [_r(800,74,122,145),_r(912,74,122,145),_r(1030,74,145,145),_r(1180,74,145,145)]
	var snake_walk_down := [_r(18,255,98,132),_r(117,255,104,132)]
	var snake_walk_up := [_r(445,255,110,132),_r(565,255,104,132)]
	var snake_walk_side := [_r(810,255,130,132),_r(944,255,134,132)]
	var snake_attack := []
	for x in [18,128,238,348,458,568,678,788,898,1008,1118,1228,1338,1448,1558]: snake_attack.append(_r(x,638,114,155))

	var gnoll_attack := [_r(520,505,220,256),_r(755,505,250,256),_r(990,505,205,256),_r(1170,505,210,256)]
	var slime_attack := [_r(430,485,160,190),_r(595,485,175,190),_r(775,485,305,190),_r(1065,485,220,190),_r(1275,485,115,190),_r(1380,485,155,190),_r(1530,485,170,190),_r(1690,485,165,190),_r(1855,485,160,190)]
	var goo_attack := [_r(375,500,130,165),_r(495,500,135,165),_r(625,500,140,165),_r(760,500,290,165),_r(1015,500,220,165),_r(1215,500,220,165),_r(1420,500,205,165),_r(1620,500,145,165),_r(1765,500,135,165),_r(1895,500,140,165)]

	return {
		"spd_rat": {"sheet":"rat.png","scale":0.62,"bar_y":39.0,"impact_y":-22.0,"shadow":[23.0,9.0],"anims":{
			"idle_down":[rat_idle_down,2.0],"idle_up":[rat_idle_up,1.0],"idle_side":[rat_idle_side,2.0],
			"walk_down":[rat_walk_down,8.0],"walk_up":[rat_walk_up,8.0],"walk_side":[rat_walk_side,9.0],
			"attack":[rat_attack,14.0],"hit":[[_r(354,410,172,153)],8.0],"death":[[_r(54,410,260,153)],7.0],"contact":8}},
		"spd_snake": {"sheet":"snake.png","scale":0.58,"bar_y":39.0,"impact_y":-25.0,"shadow":[20.0,7.0],"anims":{
			"idle_down":[snake_idle_down,3.0],"idle_up":[snake_idle_up,3.0],"idle_side":[snake_idle_side,4.0],
			"walk_down":[snake_walk_down,8.0],"walk_up":[snake_walk_up,8.0],"walk_side":[snake_walk_side,9.0],
			"attack":[snake_attack,14.0],"hit":[[_r(18,395,140,135)],8.0],"death":[[_r(18,540,235,90)],7.0],"contact":8}},
		"spd_gnoll": {"sheet":"gnoll.png","scale":0.42,"bar_y":39.0,"impact_y":-43.0,"shadow":[30.0,10.0],"anims":{
			"idle_up":[[_r(0,0,256,256)],1.0],"idle_left":[[_r(256,0,256,256)],1.0],"idle_down":[[_r(512,0,256,256)],1.0],"idle_right":[[_r(768,0,256,256)],1.0],
			"walk_up":[[_r(0,256,256,256),_r(256,256,256,256)],7.0],"walk_left":[[_r(512,256,256,256),_r(768,256,256,256)],8.0],"walk_down":[[_r(1024,256,256,256),_r(1280,256,256,256)],7.0],"walk_right":[[_r(1536,256,256,256),_r(1792,256,256,256)],8.0],
			"attack":[gnoll_attack,10.0],"hit":[[_r(0,512,230,256)],8.0],"death":[[_r(230,512,300,256)],6.0],"contact":2}},
		"spd_slime": {"sheet":"slime.png","scale":0.64,"bar_y":39.0,"impact_y":-23.0,"shadow":[25.0,8.0],"anims":{
			"idle_up":[[_r(320,120,155,130)],1.0],"idle_left":[[_r(515,120,155,130)],1.0],"idle_down":[[_r(700,120,160,130)],1.0],"idle_right":[[_r(890,120,160,130)],1.0],
			"walk_up":[[_r(130,300,155,135),_r(290,300,155,135)],7.0],"walk_left":[[_r(495,300,165,135),_r(670,300,165,135)],8.0],"walk_down":[[_r(885,300,165,135),_r(1070,300,160,135)],7.0],"walk_right":[[_r(1260,300,155,135),_r(1410,300,155,135)],8.0],
			"attack":[slime_attack,11.0],"hit":[[_r(30,485,195,190)],8.0],"death":[[_r(230,485,185,190)],6.0],"contact":3}},
		"spd_goo": {"sheet":"goo.png","scale":0.72,"bar_y":71.0,"impact_y":-42.0,"shadow":[54.0,16.0],"anims":{
			"idle_up":[[_r(265,130,140,120)],1.0],"idle_left":[[_r(450,130,145,120)],1.0],"idle_down":[[_r(615,130,130,120)],1.0],"idle_right":[[_r(770,130,140,120)],1.0],
			"walk_up":[[_r(115,315,140,125),_r(255,315,145,125)],7.0],"walk_left":[[_r(455,315,145,125),_r(595,315,150,125)],8.0],"walk_down":[[_r(790,315,155,125),_r(955,315,150,125)],7.0],"walk_right":[[_r(1155,315,145,125),_r(1295,315,145,125)],8.0],
			"attack":[goo_attack,11.0],"hit":[[_r(35,500,170,165)],8.0],"death":[[_r(205,500,165,165)],6.0],"contact":4}},
		"tower_zombie": _folder_spec("zombie", {
			"idle_down":[["idle_front.png"],2.0],"idle_up":[["idle_back.png"],2.0],"idle_left":[["idle_left.png"],2.0],"idle_right":[["idle_right.png"],2.0],
			"walk_down":[["walk_front.png"],7.0],"walk_up":[["walk_back.png"],7.0],"walk_left":[["walk_left.png"],8.0],"walk_right":[["walk_right.png"],8.0],
			"attack":[["attack_1.png","attack_2.png"],10.0],"hit":[["hit.png"],8.0],"death":[["death.png"],7.0]},
			# Pedido do usuário: o cadáver (death.png, recorte bem largo/baixo)
			# ficava grande demais sobre o tile — encolhe só esse quadro.
			{"death.png": 0.62}),
		"tower_ghost": _folder_spec("fantasma", {
			"idle_down":[["idle_front_1.png","idle_front_2.png"],3.0],"idle_left":[["idle_left_1.png","idle_left_2.png"],3.0],"idle_right":[["idle_right_1.png","idle_right_2.png"],3.0],
			"walk_down":[["walk_front_1.png","walk_front_2.png"],7.0],"walk_left":[["walk_left_1.png","walk_left_2.png"],8.0],"walk_right":[["walk_right_1 - Copia.png","walk_right_2 - Copia.png"],8.0],
			"attack":[["attack.png"],10.0],"hit":[["hit.png"],8.0],"death":[["death.png"],7.0]}),
		"tower_skeleton": _folder_spec("esqueleto", {
			# O esqueleto não possui mais PNGs exclusivos de idle: reutiliza os
			# dois frames direcionais de caminhada para continuar se movendo parado.
			"idle_down":[["walk_front_1.png","walk_front_2.png"],3.0],"idle_up":[["walk_back_1.png","walk_back_2.png"],3.0],"idle_left":[["walk_left_1.png","walk_left_2.png"],3.0],"idle_right":[["walk_right_1.png","walk_right_2.png"],3.0],
			"walk_down":[["walk_front_1.png","walk_front_2.png"],7.0],"walk_up":[["walk_back_1.png","walk_back_2.png"],7.0],"walk_left":[["walk_left_1.png","walk_left_2.png"],8.0],"walk_right":[["walk_right_1.png","walk_right_2.png"],8.0],
			"attack":[["attack_1.png","attack_2.png","attack_3.png"],10.0],"hit":[["hit.png"],8.0],"death":[["death.png"],7.0]}),
		"tower_lava_human": _folder_spec("lava humana", {
			"idle_down":[["idle_front.png"],2.0],"idle_up":[["idle_back.png"],2.0],"idle_left":[["idle_left.png"],2.0],"idle_right":[["idle_right_2.png"],2.0],
			"walk_down":[["walk_front_1.png","walk_front_2.png"],7.0],"walk_up":[["walk_back_1.png","walk_back_2.png"],7.0],"walk_left":[["walk_left_1.png"],8.0],"walk_right":[["walk_right_1.png","wlak_right_2.png"],8.0],
			"attack":[["attack.png"],10.0],"hit":[["hit.png"],8.0],"death":[["death.png"],7.0]}),
		"tower_living_fire": _folder_spec("fogo vivo", {
			"idle_down":[["idle_front.png"],3.0],"idle_up":[["idle_back.png"],2.0],"idle_left":[["idle_left.png"],2.0],"idle_right":[["idle_right.png"],2.0],
			"walk_down":[["walk_front_1.png"],7.0],"walk_up":[["walk_back.png"],7.0],"walk_left":[["walk_left_1.png","walk_left_2.png"],8.0],"walk_right":[["walk_right_1.png","walk_right_2.png"],8.0],
			"attack":[["attack_1.png","attack_2.png"],10.0],"hit":[["hit.png"],8.0],"death":[["death.png"],6.0]}),
		# Pedido do usuário: Demônio das Chamas. Pasta sem PNGs de idle (só
		# attack_1/2, hit, death, walk_front/back/left/right_1/2) — mesmo
		# truque do tower_salamander/troll/orc/xama: idle reaproveita os 2
		# quadros de walk parado por direção. "cast" reaproveita os quadros de
		# ataque (Raio de Fogo/Bola de Fogo/Flecha de Fogo/Invocar Fogo Vivo
		# usam a mesma pose), igual tower_salamander.
		"flame_demon": _folder_spec("demonio das chamas", {
			"idle_down":[["walk_front_1.png","walk_front_2.png"],3.0],"idle_up":[["walk_back_1.png","walk_back_2.png"],3.0],"idle_left":[["walk_left_1.png","walk_left_2.png"],3.0],"idle_right":[["walk_right_1.png","walk_right_2.png"],3.0],
			"walk_down":[["walk_front_1.png","walk_front_2.png"],7.0],"walk_up":[["walk_back_1.png","walk_back_2.png"],7.0],"walk_left":[["walk_left_1.png","walk_left_2.png"],8.0],"walk_right":[["walk_right_1.png","walk_right_2.png"],8.0],
			"attack":[["attack_1.png","attack_2.png"],10.0],"cast":[["attack_1.png","attack_2.png"],10.0],"hit":[["hit.png"],8.0],"death":[["death.png"],6.0]}),
		# Pedido do usuário: Vampiro. Pasta sem PNGs de idle (só attack_1/2,
		# hit, death, walk_front/back/left/right_1/2) — mesmo truque de
		# reaproveitar os 2 quadros de walk parado por direção.
		"vampire": _folder_spec("vampiro", {
			"idle_down":[["walk_front_1.png","walk_front_2.png"],3.0],"idle_up":[["walk_back_1.png","walk_back_2.png"],3.0],"idle_left":[["walk_left_1.png","walk_left_2.png"],3.0],"idle_right":[["walk_right_1.png","walk_right_2.png"],3.0],
			"walk_down":[["walk_front_1.png","walk_front_2.png"],7.0],"walk_up":[["walk_back_1.png","walk_back_2.png"],7.0],"walk_left":[["walk_left_1.png","walk_left_2.png"],8.0],"walk_right":[["walk_right_1.png","walk_right_2.png"],8.0],
			"attack":[["attack_1.png","attack_2.png"],10.0],"hit":[["hit.png"],8.0],"death":[["death.png"],6.0]},
			# Pedido do usuário: cadáver do Vampiro "muito grande" — death.png
			# (636x312) é bem mais baixo e largo que os quadros de walk
			# (~360x500), então a normalização automática por altura
			# (DISPLAY_HEIGHT/altura, ver UnitToken._apply_animal_texture)
			# infla a largura do cadáver bem além do resto do elenco. Mesmo
			# mecanismo/cálculo já usado por tower_zombie/xama/goblin abaixo
			# (frame_scale_files) — 0.38 iguala a largura renderizada do
			# cadáver à largura renderizada do walk_front_1.
			{"death.png": 0.38}),
		# Forma de morcego (Virar Morcego, transformação temporária do Vampiro
		# — ver GameState.cast_vampire_bat_form/UnitToken._visual_sprite_key
		# — e Invocar Morcegos, unidade nova "Morcego Vampiro"). Pasta só com
		# 4 direções x 2 quadros (front/back/left/right_1/2, SEM prefixo
		# "walk_" e sem attack/hit/death dedicados) — reaproveita os mesmos
		# pares direcionais pra walk/idle/attack/hit/death, mesma ideia do
		# tower_salamander (sem idle) levada adiante pra também cobrir ações
		# que a pasta não tem arte própria.
		# Pedido do usuário: pasta atualizada com attack_1/2.png, hit.png e
		# death.png dedicados pro morcego (antes só tinha os 4 pares
		# direcionais, sem arte própria de ataque/dano/morte — por isso a
		# versão anterior reaproveitava front_1.png pra essas 3 ações).
		"vampire_bat": _folder_spec("vampiro/morcego", {
			"idle_down":[["front_1.png","front_2.png"],4.0],"idle_up":[["back_1.png","back_2.png"],4.0],"idle_left":[["left_1.png","left_2.png"],4.0],"idle_right":[["right_1.png","right_2.png"],4.0],
			"walk_down":[["front_1.png","front_2.png"],10.0],"walk_up":[["back_1.png","back_2.png"],10.0],"walk_left":[["left_1.png","left_2.png"],11.0],"walk_right":[["right_1.png","right_2.png"],11.0],
			"attack":[["attack_1.png","attack_2.png"],10.0],"hit":[["hit.png"],8.0],"death":[["death.png"],6.0]},
			# Pedido do usuário: o Morcego "ficou enorme" — os 12 recortes desta
			# pasta variam MUITO de altura entre si (192px a 618px pro mesmo
			# bicho), e a normalização automática por altura (DISPLAY_HEIGHT/
			# altura) infla desproporcionalmente qualquer quadro mais baixo
			# (ex.: front/back/left/right, cortados sem as pernas, acabam bem
			# mais largos na tela que attack/hit/death, que mostram o corpo
			# inteiro). Reduz TODOS os quadros pelo mesmo fator (0.65, mesma
			# ordem de grandeza do frame_scale já usado pros cadáveres largos
			# abaixo) — encolhe o bicho inteiro sem mudar a proporção relativa
			# já existente entre eles.
			{
				"front_1.png": 0.65, "front_2.png": 0.65, "back_1.png": 0.65, "back_2.png": 0.65,
				"left_1.png": 0.65, "left_2.png": 0.65, "right_1.png": 0.65, "right_2.png": 0.65,
				"attack_1.png": 0.65, "attack_2.png": 0.65, "hit.png": 0.65, "death.png": 0.65,
			}),
		# Pedido do usuário: Lich. Mesma pasta sem PNGs de idle (attack_1/2,
		# hit, death, walk_front/back/left/right_1/2) do Demônio das
		# Chamas/Vampiro — reaproveita os 2 quadros de walk parado por direção.
		"lich": _folder_spec("lich", {
			"idle_down":[["walk_front_1.png","walk_front_2.png"],3.0],"idle_up":[["walk_back_1.png","walk_back_2.png"],3.0],"idle_left":[["walk_left_1.png","walk_left_2.png"],3.0],"idle_right":[["walk_right_1.png","walk_right_2.png"],3.0],
			"walk_down":[["walk_front_1.png","walk_front_2.png"],7.0],"walk_up":[["walk_back_1.png","walk_back_2.png"],7.0],"walk_left":[["walk_left_1.png","walk_left_2.png"],8.0],"walk_right":[["walk_right_1.png","walk_right_2.png"],8.0],
			"attack":[["attack_1.png","attack_2.png"],10.0],"cast":[["attack_1.png","attack_2.png"],10.0],"hit":[["hit.png"],8.0],"death":[["death.png"],6.0]},
			# Pedido do usuário: cadáver do Lich "muito grande" — mesma causa e
			# mesmo cálculo do Vampiro acima (death.png 402x204 bem mais baixo
			# que os quadros de walk ~300x570; 0.28 iguala a largura
			# renderizada do cadáver à do walk_front_1).
			{"death.png": 0.28}),
		# Pedido do usuário: Dragão Vermelho. Mesma pasta sem PNGs de idle do
		# Demônio das Chamas/Vampiro/Lich — reaproveita os 2 quadros de walk
		# parado por direção. Nome de arquivo real tem "F" maiúsculo só no 1º
		# quadro de walk_front ("walk_Front_1.png", walk_front_2.png em
		# minúsculo) — preservado literalmente, mesma ideia do "wlak_right_2.png"
		# já reaproveitado como está em "lava humana" (não corrigir o typo do
		# arquivo, só referenciá-lo do jeito que existe).
		"dragon": _folder_spec("dragão", {
			"idle_down":[["walk_Front_1.png","walk_front_2.png"],3.0],"idle_up":[["walk_back_1.png","walk_back_2.png"],3.0],"idle_left":[["walk_left_1.png","walk_left_2.png"],3.0],"idle_right":[["walk_right_1.png","walk_right_2.png"],3.0],
			"walk_down":[["walk_Front_1.png","walk_front_2.png"],7.0],"walk_up":[["walk_back_1.png","walk_back_2.png"],7.0],"walk_left":[["walk_left_1.png","walk_left_2.png"],8.0],"walk_right":[["walk_right_1.png","walk_right_2.png"],8.0],
			"attack":[["attack_1.png","attack_2.png"],10.0],"cast":[["attack_1.png","attack_2.png"],10.0],"hit":[["hit.png"],8.0],"death":[["death.png"],6.0]}),
		"tower_salamander": _folder_spec("salamandra", {
			# O pack não traz idle separado; os dois frames de caminhada mantêm
			# a Salamandra viva e respirando em todas as direções quando parada.
			"idle_down":[["walk_front_1.png","walk_front_2.png"],3.0],"idle_up":[["walk_back_1.png","walk_back_2.png"],3.0],"idle_left":[["walk_left_1.png","walk_left_2.png"],3.0],"idle_right":[["walk_right_1.png","walk_right_2.png"],3.0],
			"walk_down":[["walk_front_1.png","walk_front_2.png"],7.0],"walk_up":[["walk_back_1.png","walk_back_2.png"],7.0],"walk_left":[["walk_left_1.png","walk_left_2.png"],8.0],"walk_right":[["walk_right_1.png","walk_right_2.png"],8.0],
			"attack":[["attack_1.png","attack_2.png"],10.0],"cast":[["attack_1.png","attack_2.png"],10.0],"hit":[["hit.png"],8.0],"death":[["death.png"],6.0]}),
		"bardo": _hero_folder_spec("bardo", {
			"idle_down":[["walk_front_1.png","walk_front_2.png"],3.0],"idle_up":[["walk_back_1.png","walk_back_2.png"],3.0],"idle_left":[["walk_left_1.png","walk_left_2.png"],3.0],"idle_right":[["walk_right_1.png","walk_right_2.png"],3.0],
			"walk_down":[["walk_front_1.png","walk_front_2.png"],7.0],"walk_up":[["walk_back_1.png","walk_back_2.png"],7.0],"walk_left":[["walk_left_1.png","walk_left_2.png"],8.0],"walk_right":[["walk_right_1.png","walk_right_2.png"],8.0],
			"attack":[["attack_2.png"],10.0],"crossbow":[["attack_2.png"],10.0],"cast":[["attack_1.png"],8.0],"hit":[["hit.png"],8.0],"death":[["death.png"],6.0]},
			# Pedido do usuário: o cadáver do Bardo ficava "muito pequeno" na
			# tela comparado a andar/atacar/parado. Causa: `_apply_animal_texture`
			# escala esse PNG (arquivo próprio por ação, canvas quadrado igual em
			# TODOS os frames do personagem) por DISPLAY_HEIGHT/altura DO CANVAS —
			# não da altura do desenho visível dentro dele. Como death.png é um
			# recorte deitado, o goblin/bardo/etc. ocupa bem menos altura de
			# canvas que de pé, então o mesmo scale_factor (igual pra todo frame)
			# renderiza o cadáver bem menor na tela. 1.17 iguala a ÁREA visual
			# renderizada do cadáver à da pose de pé (walk_front_1) — mesmo
			# cálculo aplicado a Goblin/Xamã/Orc/Troll/Arqueiro/Maga/Químico abaixo.
			{"death.png": 1.17}),
		# Pedido do usuário: Monge. A arte veio sem quadros laterais (só
		# front_walk/back_walk), então esquerda/direita caem no par frontal e
		# são espelhados automaticamente (_animal_directional_key +
		# _animal_should_flip em UnitToken), mesmo caminho já usado por quem
		# não tem arte de lado. Cada ação tem sua própria chave: "soco" para
		# Soco/Rajada de Golpes, "chute" e "voadora" para o Chute do Dragão
		# (ver "spriteAction" em weapons.gd/spells.gd e
		# UnitToken.play_attack), "cast" para as habilidades sem alvo.
		"monge": _hero_folder_spec("Monge", {
			"idle_down":[["front_walk_1.png","front_walk_2.png"],3.0],"idle_up":[["back_walk_1.png","back_walk_2.png"],3.0],
			"walk_down":[["front_walk_1.png","front_walk_2.png"],7.0],"walk_up":[["back_walk_1.png","back_walk_2.png"],7.0],
			"attack":[["attack_soco_1.png","attack_soco_2.png","attack_soco_3.png"],10.0],
			"soco":[["attack_soco_1.png","attack_soco_2.png","attack_soco_3.png"],10.0],
			"chute":[["attack_chute_1.png","attack_chute_2.png","attack_chute_3.png"],10.0],
			"voadora":[["voadora.png"],6.0],
			"cast":[["attack_soco_1.png"],8.0],"hit":[["hit.png"],8.0],"death":[["death.png"],6.0]},
			# Mesmo ajuste de área do cadáver do Bardo/Arqueiro/Maga: death.png
			# é um recorte deitado no mesmo canvas quadrado dos outros quadros,
			# então sem isso o corpo renderiza bem menor que a pose de pé.
			{"death.png": 1.13}),
		# Pedido do usuário: Samurai (arte aprovada). idle_front.png é a pose
		# parada de frente; para cima/esquerda/direita a pose parada reaproveita
		# o 1º quadro de caminhada da direção (mesmo truque do Arqueiro/Maga).
		# "attack" = saque (windup) + corte com o arco de energia; "bow" e
		# "cast" mostram só o saque (o Samurai não tem arte de arco: o tiro
		# usa a pose de saque da katana); "hit"/"death" têm arte própria.
		"samurai": _hero_folder_spec("samurai", {
			"idle_down":[["walk_south_1.png","walk_south_2.png"],3.0],"idle_up":[["walk_north_1.png","walk_north_2.png"],3.0],"idle_left":[["walk_west_1.png","walk_west_2.png"],3.0],"idle_right":[["walk_east_1.png","walk_east_2.png"],3.0],
			"walk_down":[["walk_south_1.png","walk_south_2.png"],7.0],"walk_up":[["walk_north_1.png","walk_north_2.png"],7.0],"walk_left":[["walk_west_1.png","walk_west_2.png"],8.0],"walk_right":[["walk_east_1.png","walk_east_2.png"],8.0],
			"attack":[["attack_sword_1_windup.png","attack_sword_2_slash_fx.png"],10.0],
			"bow":[["attack_sword_1_windup.png"],8.0],"cast":[["attack_sword_1_windup.png"],8.0],
			"hit":[["hit_1_impact.png"],8.0],"death":[["death_1.png"],6.0]},
			# Mesmo ajuste de área do cadáver do Bardo/Arqueiro/Monge: o corpo
			# deitado ocupa bem menos do canvas quadrado que a pose de pé.
			{"death_1.png": 1.15}),
		# Pedido do usuário: Vestruz (arte aprovada, sem retrato próprio: usa o
		# 1º quadro de caminhada de frente). Idle reaproveita os quadros de
		# caminhada. "attack" = coice (Coice Veloz/Disparada); "cuspe" e "cast"
		# = 1º quadro de ataque (cabeça/pescoço armados).
		"vestruz": _vestruz_spec(),
		"arqueiro": _hero_folder_spec("arqueiro", {
			# Pedido do usuário: apagou os PNGs antigos de idle prefixados
			# (arqueiro_idle_*) — reaproveita os 2 quadros de walk parado no
			# lugar, mesmo truque já usado em "bardo"/tower_skeleton/tower_salamander.
			"idle_down":[["walk_front_1.png","walk_front_2.png"],3.0],"idle_up":[["walk_back_1.png","walk_back_2.png"],3.0],"idle_left":[["walk_left_1.png","walk_left_2.png"],3.0],"idle_right":[["walk_right_1.png","walk_right_2.png"],3.0],
			"walk_down":[["walk_front_1.png","walk_front_2.png"],7.0],"walk_up":[["walk_back_1.png","walk_back_2.png"],7.0],"walk_left":[["walk_left_1.png","walk_left_2.png"],8.0],"walk_right":[["walk_right_1.png","walk_right_2.png"],8.0],
			"attack":[["attack_1.png","attack_2.png"],10.0],"hit":[["hit.png"],8.0],"death":[["arqueiro_death.png"],6.0]},
			# Mesmo ajuste de área do Bardo acima, aplicado ao cadáver do Arqueiro.
			{"arqueiro_death.png": 1.28}),
		# Pedido do usuário: arte nova da Maga (attack_1.png = conjuração cheia
		# nova, walk_front/back/left/right_1/2.png em pares) substituindo o
		# antigo conjunto prefixado "mago_*" pra ataque/caminhada — idle,
		# attack_2 (impacto/liberação) e o cadáver continuam nos arquivos
		# antigos, que não mudaram.
		"mago": _hero_folder_spec("mago", {
			# Pedido do usuário: apagou os PNGs antigos de idle prefixados
			# (mago_idle_*) — reaproveita os 2 quadros de walk parado no lugar,
			# mesmo truque já usado em "bardo"/tower_skeleton/tower_salamander.
			"idle_down":[["walk_front_1.png","walk_front_2.png"],3.0],"idle_up":[["walk_back_1.png","walk_back_2.png"],3.0],"idle_left":[["walk_left_1.png","walk_left_2.png"],3.0],"idle_right":[["walk_right_1.png","walk_right_2.png"],3.0],
			"walk_down":[["walk_front_1.png","walk_front_2.png"],7.0],"walk_up":[["walk_back_1.png","walk_back_2.png"],7.0],"walk_left":[["walk_left_1.png","walk_left_2.png"],8.0],"walk_right":[["walk_right_1.png","walk_right_2.png"],8.0],
			"attack":[["attack_1.png","attack_2.png"],10.0],"hit":[["mago_hit_1.png"],8.0],"death":[["mago_death_6.png"],6.0]},
			# Mesmo ajuste de área do Bardo/Arqueiro acima, aplicado ao cadáver da Maga.
			{"mago_death_6.png": 1.27}),
		# Pedido do usuário: arte nova do Químico inteira (attack_1/2.png,
		# hit.png, death.png, walk_front/back/left/right_1/2.png em pares)
		# substituindo o antigo conjunto prefixado "quimico_*" pra ataque/dano/
		# morte/caminhada — só idle e retrato continuam nos arquivos antigos,
		# que não mudaram.
		"quimico": _hero_folder_spec("quimico", {
			"idle_down":[["quimico_idle_front_1.png"],2.0],"idle_up":[["quimico_idle_back_1.png"],2.0],"idle_left":[["quimico_idle_left_1.png"],2.0],"idle_right":[["quimico_idle_right_1.png"],2.0],
			"walk_down":[["walk_front_1.png","walk_front_2.png"],7.0],"walk_up":[["walk_back_1.png","walk_back_2.png"],7.0],"walk_left":[["walk_left_1.png","walk_left_2.png"],8.0],"walk_right":[["walk_right_1.png","walk_right_2.png"],8.0],
			"attack":[["attack_1.png","attack_2.png"],10.0],"hit":[["hit.png"],8.0],"death":[["death.png"],6.0]},
			# Mesmo ajuste de área do Bardo/Arqueiro/Maga acima, aplicado ao
			# cadáver do Químico.
			{"death.png": 1.04}),
		# Pedido do usuário: arte nova do Troll inteira (attack_1/2.png,
		# hit.png, death.png, walk_front/back/left/right_1/2.png em pares) —
		# apagou os PNGs antigos de idle prefixados (troll_idle_*) junto, então
		# idle reaproveita os 2 quadros de walk parado, mesmo truque do
		# Arqueiro/Maga. Só o retrato continua no arquivo antigo (troll_portrait.png).
		"troll": _enemy_folder_spec("troll", {
			"idle_down":[["walk_front_1.png","walk_front_2.png"],3.0],"idle_up":[["walk_back_1.png","walk_back_2.png"],3.0],"idle_left":[["walk_left_1.png","walk_left_2.png"],3.0],"idle_right":[["walk_right_1.png","walk_right_2.png"],3.0],
			"walk_down":[["walk_front_1.png","walk_front_2.png"],7.0],"walk_up":[["walk_back_1.png","walk_back_2.png"],7.0],"walk_left":[["walk_left_1.png","walk_left_2.png"],8.0],"walk_right":[["walk_right_1.png","walk_right_2.png"],8.0],
			"attack":[["attack_1.png","attack_2.png"],10.0],"hit":[["hit.png"],8.0],"death":[["death.png"],6.0]},
			# Mesmo ajuste de área (ver Goblin abaixo) aplicado ao cadáver do Troll.
			{"death.png": 1.28}),
		# Pedido do usuário: arte nova da Xamã inteira (attack_1/2.png, hit.png,
		# death.png, portrait.png e walk_front/back/left/right_1/2.png em
		# pares) — sem PNGs de idle (nem antigos nem novos), reaproveita os 2
		# quadros de walk parado, mesmo truque do Arqueiro/Maga/Troll.
		"xama": _enemy_folder_spec("xama", {
			"idle_down":[["walk_front_1.png","walk_front_2.png"],3.0],"idle_up":[["walk_back_1.png","walk_back_2.png"],3.0],"idle_left":[["walk_left_1.png","walk_left_2.png"],3.0],"idle_right":[["walk_right_1.png","walk_right_2.png"],3.0],
			"walk_down":[["walk_front_1.png","walk_front_2.png"],7.0],"walk_up":[["walk_back_1.png","walk_back_2.png"],7.0],"walk_left":[["walk_left_1.png","walk_left_2.png"],8.0],"walk_right":[["walk_right_1.png","walk_right_2.png"],8.0],
			"attack":[["attack_1.png","attack_2.png"],10.0],"cast":[["attack_1.png","attack_2.png"],10.0],"hit":[["hit.png"],8.0],"death":[["death.png"],6.0]},
			# Pedido do usuário: a correção anterior (0.48, pedida quando o
			# cadáver "ocupava 2 quadrados horizontais") superestimou o quanto
			# encolher — `_apply_animal_texture` já escala este PNG (canvas
			# quadrado igual em todo frame do personagem) por DISPLAY_HEIGHT/
			# altura DO CANVAS, não da altura do desenho visível; como death.png
			# é um recorte deitado, ocupa bem menos altura de canvas que a Xamã
			# de pé, então 0.48 encolhia o cadáver bem abaixo do resto do elenco
			# ("muito pequeno"). 1.26 iguala a ÁREA visual renderizada do cadáver
			# à da pose de pé (walk_front_1) — mesmo cálculo do Goblin/Orc/Troll/
			# Bardo/Arqueiro/Maga/Químico.
			{"death.png": 1.26}),
		# Pedido do usuário: arte nova do Orc inteira (attack_1/2.png, hit.png,
		# death.png, portrait.png e walk_front/back/left/right_1/2.png em
		# pares) — sem PNGs de idle, reaproveita os 2 quadros de walk parado,
		# mesmo truque da Xamã/Arqueiro/Maga/Troll.
		"orc": _enemy_folder_spec("orc", {
			"idle_down":[["walk_front_1.png","walk_front_2.png"],3.0],"idle_up":[["walk_back_1.png","walk_back_2.png"],3.0],"idle_left":[["walk_left_1.png","walk_left_2.png"],3.0],"idle_right":[["walk_right_1.png","walk_right_2.png"],3.0],
			"walk_down":[["walk_front_1.png","walk_front_2.png"],7.0],"walk_up":[["walk_back_1.png","walk_back_2.png"],7.0],"walk_left":[["walk_left_1.png","walk_left_2.png"],8.0],"walk_right":[["walk_right_1.png","walk_right_2.png"],8.0],
			"attack":[["attack_1.png","attack_2.png"],10.0],"hit":[["hit.png"],8.0],"death":[["death.png"],6.0]},
			# Mesmo ajuste de área (ver Goblin abaixo) aplicado ao cadáver do Orc.
			{"death.png": 1.05}),
		# Pedido do usuário: arte nova do Goblin inteira (attack_1/2.png,
		# hit.png, death.png e walk_front/back_1/2.png + walk_left/right só com
		# 1 quadro cada, sem par "_2" — diferente dos outros, então idle/walk
		# de esquerda/direita ficam com 1 frame só mesmo, não 2). Só o retrato
		# continua no arquivo antigo (goblin_portrait.png).
		"goblin": _enemy_folder_spec("goblin", {
			"idle_down":[["walk_front_1.png","walk_front_2.png"],3.0],"idle_up":[["walk_back_1.png","walk_back_2.png"],3.0],"idle_left":[["walk_left_1.png"],2.0],"idle_right":[["walk_right_1.png"],2.0],
			"walk_down":[["walk_front_1.png","walk_front_2.png"],7.0],"walk_up":[["walk_back_1.png","walk_back_2.png"],7.0],"walk_left":[["walk_left_1.png"],7.0],"walk_right":[["walk_right_1.png"],7.0],
			"attack":[["attack_1.png","attack_2.png"],10.0],"hit":[["hit.png"],8.0],"death":[["death.png"],6.0]},
			# Pedido do usuário: a correção anterior (0.46, pedida quando o
			# cadáver "ocupava 3 quadrados horizontais") superestimou o quanto
			# encolher. Causa raiz: `_apply_animal_texture` escala este PNG
			# (arquivo próprio por ação, canvas 512x512 igual em TODOS os frames
			# do Goblin) por DISPLAY_HEIGHT/altura DO CANVAS — não da altura do
			# desenho visível dentro dele. death.png é um recorte deitado
			# (goblin caído, ocupando só ~187px de altura de um canvas de
			# 512px, contra ~433px de pé), então o MESMO scale_factor usado pra
			# todo frame já renderiza o cadáver bem menor na tela antes mesmo de
			# qualquer frame_scale — 0.46 em cima disso encolhia ainda mais,
			# virando "muito pequeno". 1.37 iguala a ÁREA visual renderizada do
			# cadáver à da pose de pé (walk_front_1) em vez de só minimizar a
			# largura.
			{"death.png": 1.37}),
		# Pedido do usuário: Kobold (Goblinoides) — attack_1/2.png, hit.png
		# (já com o clarão de impacto desenhado), death.png, portrait.png e
		# walk_front/back/left/right_1/2.png em pares (pés/braços alternando).
		# Os recortes originais foram normalizados pro mesmo padrão do Goblin
		# (canvas 512x512, escala única, pés na mesma linha de base; originais
		# em _asset_backups_20260930_kobold/). Sem PNGs de idle: reaproveita
		# os 2 quadros de walk parado, mesmo truque do Orc/Xamã/Troll.
		"kobold": _enemy_folder_spec("kobold", {
			"idle_down":[["walk_front_1.png","walk_front_2.png"],3.0],"idle_up":[["walk_back_1.png","walk_back_2.png"],3.0],"idle_left":[["walk_left_1.png","walk_left_2.png"],3.0],"idle_right":[["walk_right_1.png","walk_right_2.png"],3.0],
			"walk_down":[["walk_front_1.png","walk_front_2.png"],7.0],"walk_up":[["walk_back_1.png","walk_back_2.png"],7.0],"walk_left":[["walk_left_1.png","walk_left_2.png"],8.0],"walk_right":[["walk_right_1.png","walk_right_2.png"],8.0],
			"attack":[["attack_1.png","attack_2.png"],10.0],"hit":[["hit.png"],8.0],"death":[["death.png"],6.0]}),
		# Pedido do usuário: Troncus (homem-árvore 2x2 dos Goblinoides) — mesmo
		# conjunto de arquivos do Kobold. Normalizado pro padrão do Troll
		# (canvas quadrado, escala única, pés na mesma linha; walk_left_2/
		# walk_right_2 vieram em outra resolução e foram igualados ao par;
		# originais em _asset_backups_20260930_troncus/). Idle = os 2 quadros
		# de walk de cada direção (pedido do usuário, igual ao Kobold).
		# death.png: 1.23 iguala a área visual do cadáver à pose de pé.
		"troncus": _enemy_folder_spec("troncus", {
			"idle_down":[["walk_front_1.png","walk_front_2.png"],3.0],"idle_up":[["walk_back_1.png","walk_back_2.png"],3.0],"idle_left":[["walk_left_1.png","walk_left_2.png"],3.0],"idle_right":[["walk_right_1.png","walk_right_2.png"],3.0],
			"walk_down":[["walk_front_1.png","walk_front_2.png"],7.0],"walk_up":[["walk_back_1.png","walk_back_2.png"],7.0],"walk_left":[["walk_left_1.png","walk_left_2.png"],8.0],"walk_right":[["walk_right_1.png","walk_right_2.png"],8.0],
			"attack":[["attack_1.png","attack_2.png"],10.0],"hit":[["hit.png"],8.0],"death":[["death.png"],6.0]},
			{"death.png": 1.23}),
		# Pedido do usuário: Lobo dos Goblinoides — walk_*_1/2 nas 4 direções,
		# attack_1/2, hit, death e portrait. Walk e idle usam as MESMAS
		# texturas. Attack/
		# hit/death só existem de perfil (virados pra direita): espelhados
		# automaticamente quando o lobo olha pra esquerda (_animal_should_flip).
		# Idle = a pose _1 de cada direção (parada); walk alterna _1/_2.
		# Normalizado (canvas 512, uma escala por vista, pés na mesma linha;
		# originais em _asset_backups_20260930_lobo/). As 3 imagens "Imagem do
		# ChatGPT ..." da pasta não são usadas.
		"lobo": _enemy_folder_spec("lobo", {
			"idle_down":[["walk_front_1.png"],2.0],"idle_up":[["walk_back_1.png"],2.0],"idle_left":[["walk_left_1.png"],2.0],"idle_right":[["walk_right_1.png"],2.0],
			"walk_down":[["walk_front_1.png","walk_front_2.png"],8.0],"walk_up":[["walk_back_1.png","walk_back_2.png"],8.0],"walk_left":[["walk_left_1.png","walk_left_2.png"],9.0],"walk_right":[["walk_right_1.png","walk_right_2.png"],9.0],
			"attack":[["attack_1.png","attack_2.png"],10.0],"hit":[["hit.png"],8.0],"death":[["death.png"],6.0]}),
		# Pedido do usuário: Guardian Buttereye (assets/enemies/guardians/
		# buttereye) ganhou attack_1/2.png, hit.png, death.png e
		# walk_front/back/left/right_1/2.png — sem PNGs de idle, reaproveita
		# os 2 quadros de walk parado por direção, mesmo truque do
		# Goblin/Orc/Xamã/Troll acima. Arquivo real do 1º quadro de walk_left
		# tem o nome com "letf" trocado ("walk_letf_1.png"), não
		# "walk_left_1.png" — preservado literalmente, mesma ideia do
		# "wlak_right_2.png" já reaproveitado como está em "lava humana" (não
		# corrigir o typo do arquivo, só referenciá-lo do jeito que existe).
		# Retrato continua no arquivo antigo prefixado (buttereye_portrait.png,
		# ver SpriteManifest.SPRITE_MANIFEST).
		"buttereye": _enemy_folder_spec("guardians/buttereye", {
			"idle_down":[["walk_front_1.png","walk_front_2.png"],3.0],"idle_up":[["walk_back_1.png","walk_back_2.png"],3.0],"idle_left":[["walk_letf_1.png","walk_left_2.png"],3.0],"idle_right":[["walk_right_1.png","walk_right_2.png"],3.0],
			"walk_down":[["walk_front_1.png","walk_front_2.png"],7.0],"walk_up":[["walk_back_1.png","walk_back_2.png"],7.0],"walk_left":[["walk_letf_1.png","walk_left_2.png"],8.0],"walk_right":[["walk_right_1.png","walk_right_2.png"],8.0],
			"attack":[["attack_1.png","attack_2.png"],10.0],"hit":[["hit.png"],8.0],"death":[["death.png"],6.0]}),
	}

## Igual a _hero_folder_spec, mas pra inimigos base fora da pasta
## assets/enemies/animals/ (Torre) — pasta própria em assets/enemies/<chave>/,
## mesmo padrão de SpriteManifest.SPRITE_MANIFEST pros inimigos "de campo"
## (Goblin/Orc/Xamã/Fada/Troll).
## `frame_scale_files` é opcional: {nome_do_arquivo: multiplicador}, mesmo
## mecanismo de _folder_spec — usado quando um recorte específico (ex.:
## cadáver bem largo) fica desproporcional ao resto do elenco (ver
## UnitToken._apply_animal_texture).
static func _enemy_folder_spec(folder: String, anims_files: Dictionary, frame_scale_files: Dictionary = {}) -> Dictionary:
	var root := "res://assets/enemies/" + folder + "/"
	var anims := {}
	for action_key: String in anims_files:
		var entry: Array = anims_files[action_key]
		var paths: Array = []
		for file_name: String in entry[0]: paths.append(root + file_name)
		anims[action_key] = [paths, entry[1]]
	var frame_scale := {}
	for file_name: String in frame_scale_files:
		frame_scale[root + file_name] = frame_scale_files[file_name]
	return {"folder":folder,"bar_y":46.0,"impact_y":-38.0,"shadow":[27.0,9.0],"portrait":root+"portrait.png","anims":anims,"frame_scale":frame_scale}

static func _vestruz_spec() -> Dictionary:
	var spec := _hero_folder_spec("vestruz", {
		"idle_down":[["walk_front_1.png","walk_front_2.png"],3.0],"idle_up":[["walk_back_1.png","walk_back_2.png"],3.0],"idle_left":[["walk_left_1.png","walk_left_2.png"],3.0],"idle_right":[["walk_right_1.png","walk_right_2.png"],3.0],
		"walk_down":[["walk_front_1.png","walk_front_2.png"],7.0],"walk_up":[["walk_back_1.png","walk_back_2.png"],7.0],"walk_left":[["walk_left_1.png","walk_left_2.png"],8.0],"walk_right":[["walk_right_1.png","walk_right_2.png"],8.0],
		"attack":[["attack_1.png","attack_2.png"],10.0],"cuspe":[["attack_1.png"],8.0],"cast":[["attack_1.png"],8.0],
		"hit":[["hit.png"],8.0],"death":[["death.png"],6.0]},
		{"death.png": 1.2})
	spec["portrait"] = "res://assets/heroes/vestruz/walk_front_1.png"
	return spec

static func _hero_folder_spec(folder: String, anims_files: Dictionary, frame_scale_files: Dictionary = {}) -> Dictionary:
	var root := "res://assets/heroes/" + folder + "/"
	var anims := {}
	for action_key: String in anims_files:
		var entry: Array = anims_files[action_key]
		var paths: Array = []
		for file_name: String in entry[0]: paths.append(root + file_name)
		anims[action_key] = [paths, entry[1]]
	var frame_scale := {}
	for file_name: String in frame_scale_files:
		frame_scale[root + file_name] = frame_scale_files[file_name]
	return {"folder":folder,"bar_y":46.0,"impact_y":-38.0,"shadow":[27.0,9.0],"portrait":root+"portrait.png","anims":anims,"frame_scale":frame_scale}

## Os cinco inimigos humanoides da Torre (Zumbi/Fantasma/Esqueleto/Lava
## Humana/Fogo Vivo) vieram como PNGs individuais já recortados por ação, não
## uma folha única com grade regular — cada quadro aqui é o CAMINHO do
## arquivo, não um retângulo. UnitToken._animal_frame_texture() carrega o
## arquivo direto e ancora pela altura real de cada textura (ver offset em
## _apply_animal_texture), então tamanhos de recorte diferentes por ação não
## quebram o alinhamento dos pés como quebrariam numa grade fixa.
## `frame_scale_files` é opcional: {nome_do_arquivo: multiplicador}, aplicado
## em cima da escala automática (DISPLAY_HEIGHT/altura) só naquele quadro
## específico — usado quando um recorte específico (ex.: cadáver bem largo)
## fica desproporcional ao resto do elenco (ver UnitToken._apply_animal_texture).
static func _folder_spec(folder: String, anims_files: Dictionary, frame_scale_files: Dictionary = {}) -> Dictionary:
	var anims := {}
	for action_key: String in anims_files:
		var entry: Array = anims_files[action_key]
		var paths: Array = []
		for file_name: String in entry[0]: paths.append(SHEET_ROOT + folder + "/" + file_name)
		anims[action_key] = [paths, entry[1]]
	var frame_scale := {}
	for file_name: String in frame_scale_files:
		frame_scale[SHEET_ROOT + folder + "/" + file_name] = frame_scale_files[file_name]
	return {"folder":folder,"bar_y":46.0,"impact_y":-38.0,"shadow":[27.0,9.0],"portrait":SHEET_ROOT + folder + "/portrait.png","anims":anims,"frame_scale":frame_scale}

static func spec(sprite_key: String) -> Dictionary:
	return build().get(sprite_key, {})

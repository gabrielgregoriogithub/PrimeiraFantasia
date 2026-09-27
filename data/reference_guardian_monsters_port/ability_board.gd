class_name AbilityBoardDraft
extends RefCounted

## Porte de Node.kt / Edge.kt / AbilityGraph.kt (guardian_monsters, Apache 2.0):
## GuardianMonsters/guardians/src/.../guardians/abilities/{Node,Edge,AbilityGraph}.kt
##
## Ideia: um grafo de nós num tabuleiro. Ativar um nó habilita seus vizinhos
## (que passam a poder ser ativados); cada nó pode conceder uma spell, uma
## arma ou uma "metamorfose" (troca de forma/classe). No original é usado
## para progressão de monstros por nível; aqui está genérico o bastante para
## encaixar em spells/weapons de `Spells.gd`/`Weapons.gd` caso vocês criem
## um sistema de progressão de personagem entre partidas.

enum NodeType { EMPTY, SPELL, WEAPON, METAMORPHOSIS }
enum NodeState { DISABLED, ENABLED, ACTIVE }


class AbilityNode:
	extends RefCounted
	var id: int
	var x: int
	var y: int
	var type: AbilityBoardDraft.NodeType = AbilityBoardDraft.NodeType.EMPTY
	var state: AbilityBoardDraft.NodeState = AbilityBoardDraft.NodeState.DISABLED
	## chave da spell/weapon concedida (ver Spells.build()/Weapons.build()),
	## vazio se o nó não concede nada (ex.: nó "de passagem" no tabuleiro).
	var grants_key: String = ""

	func _init(p_id: int, p_x: int, p_y: int) -> void:
		id = p_id
		x = p_x
		y = p_y

	func is_active() -> bool:
		return state == AbilityBoardDraft.NodeState.ACTIVE

	func is_enabled() -> bool:
		return state == AbilityBoardDraft.NodeState.ENABLED

	func activate() -> void:
		state = AbilityBoardDraft.NodeState.ACTIVE

	func enable() -> void:
		if state != AbilityBoardDraft.NodeState.ACTIVE:
			state = AbilityBoardDraft.NodeState.ENABLED


class AbilityEdge:
	extends RefCounted
	var from_id: int
	var to_id: int

	func _init(p_from_id: int, p_to_id: int) -> void:
		from_id = p_from_id
		to_id = p_to_id

	func connects(node_id: int) -> bool:
		return from_id == node_id or to_id == node_id

	func other_end(node_id: int) -> int:
		return to_id if from_id == node_id else from_id


class AbilityGraph:
	extends RefCounted
	var nodes: Dictionary = {}      # int id -> AbilityNode
	var edges: Array = []           # Array[AbilityEdge]
	var learnt_spells: Array = []   # Array[String] (chaves de Spells.build())
	var learnt_weapons: Array = []  # Array[String] (chaves de Weapons.build())

	func add_node(node: AbilityNode) -> void:
		nodes[node.id] = node

	func add_edge(from_id: int, to_id: int) -> void:
		edges.append(AbilityEdge.new(from_id, to_id))

	## Ativa um nó (deve estar ENABLED ou ser o nó raiz) e libera os vizinhos.
	func activate_node(node_id: int) -> void:
		var node: AbilityNode = nodes[node_id]
		node.activate()
		_enable_neighbors(node_id)

		match node.type:
			NodeType.SPELL:
				if node.grants_key != "" and node.grants_key not in learnt_spells:
					learnt_spells.append(node.grants_key)
			NodeType.WEAPON:
				if node.grants_key != "" and node.grants_key not in learnt_weapons:
					learnt_weapons.append(node.grants_key)
			_:
				pass

	func is_node_enabled(node_id: int) -> bool:
		return nodes[node_id].is_enabled()

	func _enable_neighbors(node_id: int) -> void:
		for edge in edges:
			if edge.connects(node_id):
				nodes[edge.other_end(node_id)].enable()

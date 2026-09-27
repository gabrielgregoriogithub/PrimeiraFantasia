class_name AnimationProfile
extends Resource

## Dados de "personalidade" de animação de um AdvancedCharacter2D — cada
## personagem aponta pra um preset (.tres) diferente em vez de ter esses
## números espalhados em código, ao contrário de CharacterVisualController.
## PROFILES (dict hardcoded) — aqui dá pra editar pelo Inspector e reaproveitar
## entre personagens sem tocar em script nenhum.
##
## Nenhum destes campos é lido ainda nesta etapa (fundação): o
## AnimationController que vai consumi-los entra na Fase 3. Esta classe é só
## o container de dados + defaults razoáveis.

@export_group("Idle")
@export var idle_speed: float = 1.0
@export var idle_amplitude: float = 1.0
@export var body_bob: float = 1.0
@export var head_bob: float = 1.0
@export var breathing_strength: float = 1.0

@export_group("Movement")
@export var movement_weight: float = 1.0

@export_group("Attack")
@export var anticipation_duration: float = 0.12
@export var attack_speed: float = 1.0
@export var recovery_duration: float = 0.18

@export_group("Hit Feedback")
@export var recoil_strength: float = 1.0
@export var hit_stop_duration: float = 0.06
@export var camera_shake_strength: float = 1.0

@export_group("Secondary Motion")
@export var secondary_motion_strength: float = 1.0

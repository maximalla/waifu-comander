class_name Skill
extends Resource

enum TargetType {ENEMY, ALLY, SELF}

@export var skill_name: String
@export var icon: Texture2D
@export var ap_cost: int
@export var range: int
@export var base_damage: int
@export var max_cooldown: int
@export var target_type: TargetType

var current_cooldown: int = 0
extends CharacterBody3D
class_name ActorBase

signal health_changed(current_health: float, maximum_health: float)
signal damaged(amount: float, source: Node)
signal died(source: Node)

enum Faction {
	NEUTRAL,
	ALLIED,
	ENEMY
}

@export var actor_id: StringName = &""
@export var faction: Faction = Faction.NEUTRAL
@export_range(1.0, 100000.0, 1.0, "or_greater")
var max_health: float = 100.0

var current_health: float = 100.0
var is_alive: bool = true


func _ready() -> void:
	current_health = max_health
	is_alive = true
	health_changed.emit(current_health, max_health)


func apply_damage(amount: float, source: Node = null) -> bool:
	if not is_alive:
		return false

	if amount <= 0.0:
		return false

	var previous_health: float = current_health
	current_health = maxf(current_health - amount, 0.0)

	if is_equal_approx(previous_health, current_health):
		return false

	damaged.emit(amount, source)
	health_changed.emit(current_health, max_health)

	if current_health <= 0.0:
		is_alive = false
		died.emit(source)

	return true


func restore_health(amount: float) -> bool:
	if not is_alive or amount <= 0.0:
		return false

	var previous_health: float = current_health
	current_health = minf(current_health + amount, max_health)

	if is_equal_approx(previous_health, current_health):
		return false

	health_changed.emit(current_health, max_health)
	return true


func is_friendly_to(other: ActorBase) -> bool:
	if other == null:
		return false

	if faction == Faction.NEUTRAL:
		return false

	return faction == other.faction


func is_hostile_to(other: ActorBase) -> bool:
	if other == null:
		return false

	if faction == Faction.NEUTRAL or other.faction == Faction.NEUTRAL:
		return false

	return faction != other.faction
  

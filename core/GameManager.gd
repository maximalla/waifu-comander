extends Node

var player_roster: Array[PackedScene] = []
var enemy_roster: Array[PackedScene] = []
var is_sandbox_mode: bool = false

# Тимчасово додамо сюди дефолтні шляхи для швидкого старту
const ARCHER_PATH = "res://entities/units/Archer.tscn"
const WARRIOR_PATH = "res://entities/units/Warrior.tscn"

func load_default_rosters():
    var archer = load(ARCHER_PATH)
    var warrior = load(WARRIOR_PATH)
    player_roster = [archer, archer, warrior]
    enemy_roster = [archer, warrior]
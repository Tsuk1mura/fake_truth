class_name Hitbox
extends Area2D

signal hit(hurtbox)


func _init() -> void:
	area_entered.connect(on_area_entered)

func on_area_entered(hurtbox:Hurtbox) -> void:
	hit.emit(hurtbox)
	hurtbox.hurt.emit(self)

# TagComponent.gd
extends Node
class_name TagComponent #物品标签

var tags: Array[String] = []

func add_tag(tag: String) -> void:
	if not tags.has(tag):
		tags.append(tag)

func remove_tag(tag: String) -> void:
	tags.erase(tag)

func has_tag(tag: String) -> bool:
	return tags.has(tag)

func has_any(tag_list: Array) -> bool:
	for t in tag_list:
		if tags.has(t):
			return true
	return false

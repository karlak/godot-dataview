@tool
extends EditorPlugin


func _enter_tree():
	add_custom_type("DataView", "Control", preload("dataview.gd"), preload("icon-16x16.png"))
	pass


func _exit_tree():
	remove_custom_type("DataView")
	pass

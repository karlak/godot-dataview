@tool
extends EditorPlugin


func loadSvgIcon(path, size):
	var img = Image.new()
	img.load_svg_from_buffer(FileAccess.get_file_as_bytes(path), float(size) / load(path).get_size().x)
	return ImageTexture.create_from_image(img)

func _enter_tree():
	add_custom_type("DataView", "Control", preload("dataview.gd"), loadSvgIcon("res://icon.svg", 16))
	pass


func _exit_tree():
	remove_custom_type("DataView")
	pass

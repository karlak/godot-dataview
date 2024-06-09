@tool
class_name Dataview
extends Control

const MAX_SINT32_VALUE: int = 2 ** 31 - 1
const DataviewContent := preload("dataview_content.gd")

# Props
@export var data_provider: Node = null: set = set_data_provider
@export var column_sizes: Array[int] = []: set = set_column_sizes, get = get_column_sizes

# Children
var _v_scrollbar: VScrollBar = VScrollBar.new()
var _h_scrollbar: HScrollBar = HScrollBar.new()
var _content_control: DataviewContent = null

# Theme
const DEFAULT_THEME: Theme = preload ("dataview_default.tres")
const THEME_KEYS := [
	"stylebox_panel",
	"stylebox_header",
	"stylebox_header_bar",
	"stylebox_data",
	"stylebox_data_selected",
	"font_size_default",
	"font_default",
	"color_header_font",
	"color_data_font",
	"constant_margin_scrollbar",
]
var _theme_cache := {}


func _theme_load():
	for key:String in THEME_KEYS:
		if key.begins_with("stylebox_"):
			var name = key.trim_prefix("stylebox_")
			if has_theme_stylebox(name, "DataView"): _theme_cache[key] = get_theme_stylebox(name, "DataView")
			else: _theme_cache[key] = DEFAULT_THEME.get_stylebox(name, "DataView")
			continue
		if key.begins_with("color_"):
			var name = key.trim_prefix("color_")
			if has_theme_color(name, "DataView"): _theme_cache[key] = get_theme_color(name, "DataView")
			else: _theme_cache[key] = DEFAULT_THEME.get_color(name, "DataView")
			continue
		if key.begins_with("constant_"):
			var name = key.trim_prefix("constant_")
			if has_theme_constant(name, "DataView"): _theme_cache[key] = get_theme_constant(name, "DataView")
			else: _theme_cache[key] = DEFAULT_THEME.get_constant(name, "DataView")
			continue
		if key.begins_with("font_size_"):
			var name = key.trim_prefix("font_size_")
			if has_theme_font_size(name, "DataView"): _theme_cache[key] = get_theme_font_size(name, "DataView")
			else: _theme_cache[key] = DEFAULT_THEME.get_font_size(name, "DataView") #get_theme_default_font_size()
			continue
		if key.begins_with("font_"):
			var name = key.trim_prefix("font_")
			if has_theme_font(name, "DataView"): _theme_cache[key] = get_theme_font(name, "DataView")
			else: _theme_cache[key] = DEFAULT_THEME.get_font(name, "DataView")
			continue
	
	_content_control._row_height = int(_theme_cache.font_size_default * 1.618)
	_content_control._text_offset_y = _content_control._row_height / 2 + _theme_cache.font_size_default / 2

	_content_control.refresh_theme(_theme_cache)

func _init():
	_v_scrollbar.rounded = true
	_v_scrollbar.name = "_v_scroll"
	_h_scrollbar.name = "_h_scroll"
	add_child(_v_scrollbar, false, INTERNAL_MODE_BACK)
	add_child(_h_scrollbar, false, INTERNAL_MODE_BACK)

	_content_control = DataviewContent.new(self)
	_content_control.name = "_dataview_content"
	add_child(_content_control, false, INTERNAL_MODE_FRONT)

	clip_contents = true

func _ready():
	_theme_load()
	_refresh_view()

func _draw():
	draw_style_box(_theme_cache.stylebox_panel, Rect2(Vector2(), size))

func _notification(what):
	match what:
		NOTIFICATION_RESIZED:
			# _refresh_view()
			pass
		NOTIFICATION_THEME_CHANGED:
			_theme_load()
			_refresh_view()
			queue_redraw()

func _refresh_view():
	var _size = size
	_size -= _theme_cache.stylebox_panel.get_minimum_size()

	# _h_scrollbar.visible = _content_control._width_content > _content_control.size.x

	var h_height := _h_scrollbar.get_combined_minimum_size().y if _h_scrollbar.visible else 0
	var v_width := _v_scrollbar.get_combined_minimum_size().x if _v_scrollbar.visible else 0
	
	var lmar = _theme_cache.stylebox_panel.get_margin(SIDE_RIGHT) if is_layout_rtl() else _theme_cache.stylebox_panel.get_margin(SIDE_LEFT)
	var rmar = _theme_cache.stylebox_panel.get_margin(SIDE_LEFT) if is_layout_rtl() else _theme_cache.stylebox_panel.get_margin(SIDE_RIGHT)

	_h_scrollbar.set_anchor_and_offset(SIDE_LEFT, ANCHOR_BEGIN, lmar)
	_h_scrollbar.set_anchor_and_offset(SIDE_RIGHT, ANCHOR_END, -rmar - v_width)
	_h_scrollbar.set_anchor_and_offset(SIDE_TOP, ANCHOR_END, -h_height - _theme_cache.stylebox_panel.get_margin(SIDE_BOTTOM))
	_h_scrollbar.set_anchor_and_offset(SIDE_BOTTOM, ANCHOR_END, -_theme_cache.stylebox_panel.get_margin(SIDE_BOTTOM))

	_v_scrollbar.set_anchor_and_offset(SIDE_LEFT, ANCHOR_END, -v_width - rmar)
	_v_scrollbar.set_anchor_and_offset(SIDE_RIGHT, ANCHOR_END, -rmar)
	_v_scrollbar.set_anchor_and_offset(SIDE_TOP, ANCHOR_BEGIN, _theme_cache.stylebox_panel.get_margin(SIDE_TOP))
	_v_scrollbar.set_anchor_and_offset(SIDE_BOTTOM, ANCHOR_END, -h_height - _theme_cache.stylebox_panel.get_margin(SIDE_BOTTOM))

	_content_control.set_anchor_and_offset(SIDE_LEFT, ANCHOR_BEGIN, lmar)
	_content_control.set_anchor_and_offset(SIDE_RIGHT, ANCHOR_END, -rmar - v_width - _theme_cache.constant_margin_scrollbar)
	_content_control.set_anchor_and_offset(SIDE_TOP, ANCHOR_BEGIN, _theme_cache.stylebox_panel.get_margin(SIDE_TOP))
	_content_control.set_anchor_and_offset(SIDE_BOTTOM, ANCHOR_END, -h_height - _theme_cache.stylebox_panel.get_margin(SIDE_BOTTOM))
	pass

func set_data_provider(dp):
	data_provider = dp
	_content_control.set_data_provider(dp)
	pass

func set_column_sizes(sizes):
	column_sizes = sizes
	_content_control.set_column_sizes(sizes.duplicate())

func get_column_sizes():
	return column_sizes

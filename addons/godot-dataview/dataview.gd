@tool
class_name DataView
extends Control

const DATA_VIEW_DEFAULT = preload("res://addons/godot-dataview/dataview_default.tres")
const PHI = 1.618

@export var data_provider: Node = null: set = set_data_provider
@export var col_sizes: Array[int] = []: set = set_col_sizes

var stylebox_panel: StyleBox = DATA_VIEW_DEFAULT.get_stylebox("panel", "DataView")

var has_valid_data_provider: bool = false
var _v_scrollbar: VScrollBar = VScrollBar.new()
var _h_scrollbar: HScrollBar = HScrollBar.new()
var clipping_container: DataDisplay = null


class DataDisplay extends Control:
	var _v_scrollbar: VScrollBar = VScrollBar.new()
	var _h_scrollbar: HScrollBar = HScrollBar.new()
	
	var data_provider: Node = null
	var col_sizes: Array[int] = []
	
	var _width_content: float = 0
	var _row_height: int = 30
	var _row_start_index: int = 0
	var _row_count: int = 0
	var _selection: R2i = R2i.new(0,0,1,1)
	var _transform: Vector2 = Vector2()
	
	var _stylebox_tmp: StyleBox = DATA_VIEW_DEFAULT.get_stylebox("tmp", "DataView")
	
	var _stylebox_header: StyleBox = DATA_VIEW_DEFAULT.get_stylebox("header_bar", "DataView")
	var _stylebox_data_cell: StyleBox = DATA_VIEW_DEFAULT.get_stylebox("data_cell", "DataView")
	var _stylebox_data_cell_selected: StyleBox = DATA_VIEW_DEFAULT.get_stylebox("data_cell_selected", "DataView")
	
	var _header_font_color: Color = DATA_VIEW_DEFAULT.get_color("header_font_color", "DataView")
	
	var _cell_gap_h: int = DATA_VIEW_DEFAULT.get_constant("cell_gap_h", "DataView")
	var _cell_gap_v: int = DATA_VIEW_DEFAULT.get_constant("cell_gap_v", "DataView")
	var _cell_margin_h: int = DATA_VIEW_DEFAULT.get_constant("cell_margin_h", "DataView")
	
	var _font_default: Font = DATA_VIEW_DEFAULT.get_font("default", "DataView")
	var _fontsize_default: int = DATA_VIEW_DEFAULT.get_font_size("default", "DataView")

	func reload_theme():
		if has_theme_stylebox("tmp", "DataView"): _stylebox_tmp = get_theme_stylebox("tmp", "DataView")
		
		if has_theme_stylebox("header", "DataView"): _stylebox_header = get_theme_stylebox("header", "DataView")
		if has_theme_stylebox("data_cell", "DataView"): _stylebox_data_cell = get_theme_stylebox("data_cell", "DataView")
		if has_theme_stylebox("data_cell_selected", "DataView"): _stylebox_data_cell_selected = get_theme_stylebox("data_cell_selected", "DataView")
		
		if has_theme_color("header_font_color", "DataView"): _header_font_color = get_theme_color("header_font_color", "DataView")
		
		if has_theme_constant("cell_gap_h", "DataView"): _cell_gap_h = get_theme_constant("cell_gap_h", "DataView")
		if has_theme_constant("cell_gap_v", "DataView"): _cell_gap_v = get_theme_constant("cell_gap_v", "DataView")
		if has_theme_constant("cell_margin_h", "DataView"): _cell_margin_h = get_theme_constant("cell_margin_h", "DataView")
		
		if has_theme_font("default", "DataView"): _font_default = get_theme_font("default", "DataView")
		if has_theme_font_size("default", "DataView"): _fontsize_default = get_theme_font_size("default", "DataView")
		elif get_theme_default_font_size(): _fontsize_default = get_theme_default_font_size()
		
		_row_height = int(_fontsize_default * 1.618)
	
	func _init(dv: DataView):
		_v_scrollbar = dv._v_scrollbar
		_h_scrollbar = dv._h_scrollbar
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_PASS
		
	func _ready():
		reload_theme()
		# Signals
		_v_scrollbar.scrolling.connect(_scrolled_y)
		_h_scrollbar.scrolling.connect(_scrolled_x)
		
	func _draw():
		var headers: Array
		var dataFunc: Callable
		if Engine.is_editor_hint():
			headers = ["Header A", "Header B", "Header C", "Header D", "Header E", "Header F"]
			dataFunc = func(index): return [index, index*2, index*3, index*4, index*5, index*6]
			_row_count = 10
		else:
			if data_provider == null: 
				_width_content = 0
				return
			headers = data_provider.get_headers()
			dataFunc = data_provider.get_row
			_row_count = data_provider.get_row_count()
		while col_sizes.size() < headers.size():
			col_sizes.append(200)
		if col_sizes.size() > headers.size():
			col_sizes.resize(headers.size())
		
		var text_offset_y = _row_height/2 + _fontsize_default/2
		var x = 0
		var y = 0
		draw_style_box(_stylebox_header, Rect2(x, y, size.x, _row_height))
		draw_set_transform(_transform)
		
		if col_sizes.size() > 0 and col_sizes[0] <= 0:
			draw_circle(Vector2(x + 4, y + _row_height / 2 + 1), 1, _header_font_color)
		for i in headers.size():
			if col_sizes[i] <= 0: continue
			var width: int = max(col_sizes[i], 20)
			
			if i+1 < col_sizes.size() and col_sizes[i+1] <= 0:
				draw_circle(Vector2(width + x + 4, y + _row_height / 2 + 1), 1, _header_font_color)
			
			var content_width: int = width - 2 * _cell_margin_h - _cell_gap_h
			var content_x: int = x + _cell_margin_h
			var s: String = headers[i]
			if content_width > 0:
				draw_string(_font_default, Vector2(content_x, y + text_offset_y), str(s), HORIZONTAL_ALIGNMENT_CENTER, content_width, _fontsize_default, _header_font_color, TextServer.JUSTIFICATION_NONE)
			draw_style_box(_stylebox_tmp, Rect2(x + width, y, 1, _row_height))
			#draw_rect(Rect2(content_x, y, content_width, _row_height), Color.from_hsv(0, 1, 1, 0.3), true)
			x += width
		if _width_content != x + 1:
			_width_content = x + 1 # convert last pixel X coord to pixel count, not a magic number!
			_update_h_scrollbar()
		y += _row_height
		
		var drawn_row_count = min(round(_get_shown_rows_count()), _row_count - _row_start_index)
		for index in drawn_row_count:
			index += _row_start_index
			x = 0
			var row_array = dataFunc.call(index)
			var col = 0
			for i in row_array.size():
				if col_sizes[i] <= 0: continue
				var width: int = max(col_sizes[i], 20)
				var content_width: int = width - 2 * _cell_margin_h - _cell_gap_h
				var content_x: int = x + _cell_margin_h
				
				var s = row_array[i]
				if _selection.has_point(V2i.new(col, index)):
					draw_style_box(_stylebox_data_cell_selected, Rect2(x, y, width - _cell_gap_h, _row_height - _cell_gap_v))
				else:
					draw_style_box(_stylebox_data_cell, Rect2(x, y, width - _cell_gap_h, _row_height - _cell_gap_v))
				if content_width > 0:
					draw_string(_font_default, Vector2(content_x, y + text_offset_y), str(s), HORIZONTAL_ALIGNMENT_CENTER, content_width, _fontsize_default, _header_font_color,TextServer.JUSTIFICATION_CONSTRAIN_ELLIPSIS)
				x += width
				col += 1
			y += _row_height
	
	func get_cell_from_position(position: Vector2) -> V2i:
		position -= _transform
		position.y -= (_row_height+1)
		var cell: V2i = V2i.new(0, -1)
		for width in col_sizes:
			position.x -= width
			if position.x <= 0: break
			cell.x += 1
		if cell.x >= col_sizes.size(): cell.x = -1
		if position.y < 0: return cell
		cell.y = floor(position.y / _row_height)
		cell.y += _row_start_index
		return cell
	
	func change_cursor(cursor: Control.CursorShape):
		if cursor == mouse_default_cursor_shape: return
		if cursor != -1: mouse_default_cursor_shape = cursor
		var pos = get_global_mouse_position()
		var e = InputEventMouseMotion.new()
		e.global_position = pos
		e.position = pos
		Input.parse_input_event(e)
	
	var resizing_col: int = -1
	func _gui_input(event):
		if data_provider == null: return
		if event is InputEventMouseButton:
			match event.button_index:
				MOUSE_BUTTON_WHEEL_DOWN:
					accept_event()
					if not event.pressed: return
					_v_scrollbar.value += int(_v_scrollbar.page / 4.0)
					_scrolled_y()
				MOUSE_BUTTON_WHEEL_UP:
					accept_event()
					if not event.pressed: return
					_v_scrollbar.value -= int(_v_scrollbar.page / 4.0)
					_scrolled_y()
				MOUSE_BUTTON_LEFT:
					accept_event()
					if !event.pressed:
						if resizing_col > -1:
							resizing_col = -1
							change_cursor(-1)
						return
					var cell = get_cell_from_position(event.position)
					if cell.y == -1:
						var pos_x = event.position.x - _transform.x
						for i in col_sizes.size():
							var width = max(col_sizes[i], 20)
							if col_sizes[i] <= 0: width = 0
							pos_x -= width
							if abs(pos_x) <= 3:
								if event.double_click and (i+1) < col_sizes.size() and col_sizes[i+1] <= 0:
									col_sizes[i+1] = 100
									queue_redraw()
								resizing_col = i
								col_sizes[i] = width
								return
						return
					_selection.set_to(cell.x, cell.y, 1, 1)
					queue_redraw()
		elif event is InputEventMouseMotion:
			if resizing_col > -1:
				col_sizes[resizing_col] += int(event.relative.x)
				queue_redraw()
				return
			if event.position.y > _row_height:
				change_cursor(Control.CURSOR_ARROW)
				return
			var pos_x = event.position.x - _transform.x
			var cursor = Control.CURSOR_ARROW
			for i in col_sizes.size():
				var width = max(col_sizes[i], 20)
				if col_sizes[i] <= 0: width = 0
				pos_x -= width
				if abs(pos_x) <= 3:
					cursor = Control.CURSOR_HSIZE
					break
			change_cursor(cursor)
	
	func _notification(what):
		match what:
			NOTIFICATION_RESIZED:
				_update_h_scrollbar()
				_update_v_scrollbar()
				queue_redraw()
			NOTIFICATION_THEME_CHANGED:
				reload_theme()
				queue_redraw()
	
	func _scrolled_x():
		_transform = Vector2(-_h_scrollbar.value, 0)
		queue_redraw()
	
	func _scrolled_y():
		if _row_start_index == _v_scrollbar.value: return
		_row_start_index = _v_scrollbar.value
		queue_redraw()
	
	func _update_v_scrollbar():
		_v_scrollbar.max_value = _row_count
		_v_scrollbar.page = floor(_get_shown_rows_count()) - 1
		_row_start_index = _v_scrollbar.value
		if _v_scrollbar.page >= _v_scrollbar.max_value: _v_scrollbar.max_value = 0

	func _update_h_scrollbar():
		if _width_content > size.x: _h_scrollbar.max_value = _width_content
		else: _h_scrollbar.max_value = 0
		_h_scrollbar.page = size.x
		_transform = Vector2(-_h_scrollbar.value, 0)
		#_h_scrollbar.visible = _width_content > size.x
		
	func _get_shown_rows_count() -> float:
		var size_without_header = size.y - _row_height
		return ceil(size_without_header / _row_height)
		
	func set_data_provider(dp):
		var old_data_provider = data_provider
		data_provider = dp
		queue_redraw()
		if Engine.is_editor_hint(): return
		_row_count = data_provider.get_row_count()
		if _row_count > 0x1FFFFFFFFFFFFF:
			print("data_provider.get_row_count() returned a value that is too large to be precisely represented on a variable of type double.")
			push_warning("data_provider.get_row_count() returned a value that is too large to be precisely represented on a variable of type double.")
		if old_data_provider and old_data_provider.has_signal("data_changed"):
			old_data_provider.data_changed.disconnect(queue_redraw)
		if data_provider and data_provider.has_signal("data_changed"):
			print(data_provider.data_changed)
			data_provider.data_changed.connect(queue_redraw)

####################################

func _draw():
	draw_style_box(stylebox_panel, Rect2(Vector2(), size))

func _init():
	clipping_container = DataDisplay.new(self)
	clipping_container.position = Vector2(4, 4)

	_v_scrollbar.rounded = true
	_v_scrollbar.min_value = 0
	_v_scrollbar.max_value = 100
	_v_scrollbar.page = 10
	
	_h_scrollbar.min_value = 0
	_h_scrollbar.page = 90

func _ready():
	reload_theme()
	add_child(clipping_container)
	add_child(_v_scrollbar)
	add_child(_h_scrollbar)

func reload_theme():
	if has_theme_stylebox("panel", "DataView"): stylebox_panel = get_theme_stylebox("panel", "DataView")

func set_col_sizes(cs: Array):
	col_sizes = cs
	clipping_container.col_sizes = cs.duplicate()
	clipping_container.queue_redraw()

func set_data_provider(dp):
	if dp == data_provider: return
	data_provider = dp
	has_valid_data_provider = _get_configuration_warnings().is_empty()
	clipping_container.set_data_provider(dp)
	#update_configuration_warnings()
	_refresh_view()

func _notification(what):
	match what:
		NOTIFICATION_RESIZED: # Control changed size; check new size with get_size().
			_refresh_view()
		NOTIFICATION_THEME_CHANGED:
			reload_theme()
			queue_redraw()
		#NOTIFICATION_MOUSE_ENTER: pass # Mouse entered the area of this control.
		#NOTIFICATION_MOUSE_EXIT: pass # Mouse exited the area of this control.
		#NOTIFICATION_FOCUS_ENTER: pass # Control gained focus.
		#NOTIFICATION_FOCUS_EXIT: pass # Control lost focus.
		#NOTIFICATION_VISIBILITY_CHANGED: pass # Control became visible/invisible; check new status with is_visible().
		#NOTIFICATION_MODAL_CLOSE: pass # For modal pop-ups, notification that the pop-up was closed.

func _refresh_view():
	const margin = 4
	_v_scrollbar.position = Vector2(size.x - _v_scrollbar.size.x - margin, margin)
	_v_scrollbar.size.y = size.y - _h_scrollbar.size.y - margin - margin
	
	_h_scrollbar.position = Vector2(margin, size.y - _h_scrollbar.size.y - margin)
	_h_scrollbar.size.x = size.x - _v_scrollbar.size.x - margin - margin

	clipping_container.size = Vector2(_v_scrollbar.position.x - margin*2, _h_scrollbar.position.y - margin*2)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings = []
	var required_method = func(name): if not data_provider.has_method(name): warnings.append(name)
	if data_provider != null:
		required_method.call("get_row_count")
		required_method.call("get_headers")
		pass
	return warnings


class V2i:
	var x: int
	var y: int
	func _init(_x=0, _y=0):
		x = _x
		y = _y
class R2i:
	var x: int
	var y: int
	var w: int
	var h: int
	func _init(_x=0, _y=0, _w=0, _h=0): set_to(_x, _y, _w, _h)
	func has_point(v: V2i):
		return v.x >= x and v.x < x + w and v.y >= y and v.y < y + h
	func set_to(_x=0, _y=0, _w=0, _h=0):
		x = _x
		y = _y
		w = _w
		h = _h

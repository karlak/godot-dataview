extends Control

const MAX_SINT32_VALUE: int = 2 ** 31 - 1

var dataview: Dataview = null
var _v_scrollbar: VScrollBar = null
var _h_scrollbar: HScrollBar = null
var _theme_cache: Dictionary = {}

var data_provider: Node = null
var _rows_data := []
var _header_titles := []

var _row_first_shown: int = 0
var _row_count_total: int = 0
var _row_count_shown: int = 0
var _row_height: int = 0
var _column_sizes := []
var _column_count_total: int = 0
var _column_first_shown: int = 0
var _column_last_shown: int = 0
var _column_first_shown_x: int = 0
var _text_offset_y: int = 0

var _width_content = 0

var selection: Rect2i = Rect2i(0, 0, 1, 1)

func _init(_dv: Dataview):
	dataview = _dv
	_h_scrollbar = _dv._h_scrollbar
	_v_scrollbar = _dv._v_scrollbar
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	_h_scrollbar.value_changed.connect(scroll_x)
	_v_scrollbar.value_changed.connect(scroll_y)

func _notification(what):
	match what:
		NOTIFICATION_RESIZED:
			_update_h_scrollbar()
			_update_v_scrollbar()
			queue_redraw()
		# NOTIFICATION_THEME_CHANGED:
		# 	queue_redraw()

func _draw():
	if not data_provider:
		_set_width_content(0)
		return
	var t0 = Time.get_ticks_usec()
	_prepare_draw()
	
	draw_style_box(_theme_cache.stylebox_header_bar, Rect2(0, 0, size.x, _row_height))

	var x = _column_first_shown_x - _h_scrollbar.value
	var hidden_column_before = false
	for column_index in range(_column_first_shown, _column_last_shown + 1):
		var width = _get_column_drawn_width(column_index)
		if width <= 0:
			hidden_column_before = true
			continue
		_draw_column(column_index, x, 0)
		if hidden_column_before:
			draw_circle(Vector2(x + 4, _row_height / 2 + 1), 1, _theme_cache.color_header_font)
			hidden_column_before = false
		x += width
	if hidden_column_before:
		draw_circle(Vector2(x + 4, _row_height / 2 + 1), 1, _theme_cache.color_header_font)
		hidden_column_before = false

	var t1 = Time.get_ticks_usec()
	print("_draw(): %dms" % ((t1-t0)/1000.0))

func _prepare_draw():
	_row_count_shown = int(size.y / _row_height)
	if Engine.is_editor_hint():
		if _row_count_total != 10:
			_row_count_total = 10
			_update_v_scrollbar()
		_header_titles = ["Header A", "Header B", "Header C", "Header D", "Header E", "Header F"]
		_rows_data = range(_row_first_shown, _row_first_shown + min(_row_count_shown, _row_count_total - _row_first_shown)).map(func(index): return [index, index*2, index*3, index*4, index*5, index*6])
	else:
		var _row_count = data_provider.get_row_count()
		if _row_count_total != _row_count:
			if _row_count > MAX_SINT32_VALUE:
				push_warning("Dataview: the data_provider returns too much rows! Over %d rows, the selection system does not work anymore!" % MAX_SINT32_VALUE)
			_row_count_total = _row_count
			_update_v_scrollbar()
		_header_titles = data_provider.get_headers()
		_rows_data = data_provider.get_rows(_row_first_shown, _row_count_shown)

	_column_count_total = _header_titles.size()

	# grow/shrink _column_sizes[] so that it's the same size as the headers
	if _column_sizes.size() < _header_titles.size():
		_build_column_sizes()

	# filter invisible columns out to speedup the draw
	var left := _h_scrollbar.value
	var right := left + size.x
	var x = 0
	for i in _column_count_total:
		var width = _get_column_drawn_width(i)
		if x + width >= left:
			_column_first_shown = i
			_column_first_shown_x = x
			break
		x += width
	for i in range(_column_first_shown, _column_count_total):
		var width = _get_column_drawn_width(i)
		if x < right: 
			_column_last_shown = i
		x += width
	_set_width_content(x + 1)

func _draw_column(column_index: int, x: int, y: int):
	var width = _get_column_drawn_width(column_index)
	
	# Header
	var header_margin_left = _theme_cache.stylebox_header.get_margin(SIDE_LEFT)
	var header_margin_right = _theme_cache.stylebox_header.get_margin(SIDE_RIGHT)
	var header_content_width = width - header_margin_left - header_margin_right
	draw_style_box(_theme_cache.stylebox_header, Rect2(x, y + _theme_cache.stylebox_header.get_margin(SIDE_TOP), width, _row_height - _theme_cache.stylebox_header.get_margin(SIDE_TOP) - _theme_cache.stylebox_header.get_margin(SIDE_BOTTOM)))
	if header_content_width > 0:
		draw_string(_theme_cache.font_default, Vector2(x + header_margin_left, y + _text_offset_y), str(_header_titles[column_index]), HORIZONTAL_ALIGNMENT_CENTER, header_content_width, _theme_cache.font_size_default, _theme_cache.color_header_font, TextServer.JUSTIFICATION_CONSTRAIN_ELLIPSIS)
	
	# Data
	var data_margin_left = _theme_cache.stylebox_data.get_margin(SIDE_LEFT)
	var data_margin_right = _theme_cache.stylebox_data.get_margin(SIDE_RIGHT)
	var data_content_width = width - data_margin_left - data_margin_right
	y = _row_height
	for i in _rows_data.size():
		var s = _rows_data[i][column_index]
		if selection.has_point(Vector2i(column_index, i + _row_first_shown)):
			draw_style_box(_theme_cache.stylebox_data_selected, Rect2(x, y, width, _row_height))
		else:
			draw_style_box(_theme_cache.stylebox_data, Rect2(x, y, width, _row_height))
		if data_content_width > 0:
			draw_string(_theme_cache.font_default, Vector2(x + data_margin_left, y + _text_offset_y), str(s), HORIZONTAL_ALIGNMENT_LEFT, data_content_width, _theme_cache.font_size_default, _theme_cache.color_data_font, TextServer.JUSTIFICATION_CONSTRAIN_ELLIPSIS)
		y += _row_height
	
func _gui_input(event):
	if not data_provider: return
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_DOWN:
				accept_event()
				if not event.pressed: return
				_v_scrollbar.value += int(_v_scrollbar.page / 4.0)
				scroll_y(_v_scrollbar.value)
			MOUSE_BUTTON_WHEEL_UP:
				accept_event()
				if not event.pressed: return
				_v_scrollbar.value -= int(_v_scrollbar.page / 4.0)
				scroll_y(_v_scrollbar.value)
			MOUSE_BUTTON_LEFT:
				_on_left_click(event)
	elif event is InputEventMouseMotion:
		_on_mouse_move(event)
		pass

var current_resizing_column: int = -1
func _on_left_click(event: InputEventMouseButton):
	accept_event()
	if !event.pressed:
		if current_resizing_column > -1:
			current_resizing_column = -1
		return
	var cell = _get_cell_from_position(event.position)
	if cell.y == -1: # clicked on a header
		var column_handle = _get_column_resize_handle_at_position(event.position)
		if column_handle > -1:
			if event.double_click:
				if column_handle == 0 and _column_sizes[0] <= 0:
					_column_sizes[0] = 100
					queue_redraw()
				elif column_handle + 1 < _column_count_total and _column_sizes[column_handle + 1] <= 0:
					_column_sizes[column_handle + 1] = 100
					queue_redraw()
				return
			current_resizing_column = column_handle
			_column_sizes[column_handle] = _get_column_drawn_width(column_handle)
	selection = Rect2i(cell.x, cell.y, 1, 1)
	queue_redraw()
	
func _on_mouse_move(event: InputEventMouseMotion):
	if current_resizing_column > -1:
		_column_sizes[current_resizing_column] += int(event.relative.x)
		queue_redraw()
		return
	if event.position.y > _row_height:
		change_cursor(Control.CURSOR_ARROW)
		return
	
	var column_handle = _get_column_resize_handle_at_position(event.position)
	if column_handle > -1: change_cursor(Control.CURSOR_HSIZE)
	else: change_cursor(Control.CURSOR_ARROW)

func _get_column_resize_handle_at_position(mouse_position: Vector2) -> int:
	var pos_x = mouse_position.x + _h_scrollbar.value
	for i in _column_count_total:
		pos_x -= _get_column_drawn_width(i)
		if abs(pos_x) <= 3: return i
	return -1

func change_cursor(cursor) -> void:
	if cursor == mouse_default_cursor_shape: return
	if cursor >= 0: mouse_default_cursor_shape = cursor
	var pos = get_global_mouse_position()
	var e = InputEventMouseMotion.new()
	e.global_position = pos
	e.position = pos
	Input.parse_input_event(e)

func _get_cell_from_position(position: Vector2) -> Vector2i:
	position.x += _h_scrollbar.value
	position.y -= (_row_height + 1)
	var cell_x := 0
	for i in _column_count_total:
		position.x -= _get_column_drawn_width(i)
		if position.x <= 0: break
		cell_x += 1
	if cell_x >= _column_count_total: cell_x = -1
	if position.y < 0: return Vector2i(cell_x, -1) # header
	var cell_y = floor(position.y / _row_height) + _row_first_shown
	return Vector2i(cell_x, cell_y)

func _get_column_drawn_width(index) -> int:
	var width = _column_sizes[index]
	if width <= 0: return 0
	return max(65, width)

func _build_column_sizes() -> void:
	var old_size = _column_sizes.size()
	_column_sizes.resize(_column_count_total)
	for i in range(old_size, _column_count_total):
		_column_sizes[i] = 200

func set_column_sizes(sizes) -> void:
	if _column_sizes != sizes:
		_column_sizes = sizes
		queue_redraw()

func set_data_provider(dp) -> void:
	if Engine.is_editor_hint(): return
	if data_provider == dp: return
	var old_data_provider = data_provider
	data_provider = dp
	queue_redraw()
	if old_data_provider and old_data_provider.has_signal("data_changed"):
		old_data_provider.data_changed.disconnect(on_data_provider_data_changed)
	if data_provider and data_provider.has_signal("data_changed"):
		data_provider.data_changed.connect(on_data_provider_data_changed)

func on_data_provider_data_changed():
	queue_redraw()

func refresh_theme(_theme) -> void:
	_theme_cache = _theme

func _set_width_content(w: int) -> void:
	if _width_content == w: return
	_width_content = w
	_update_h_scrollbar()

func _update_h_scrollbar() -> void:
	if _width_content > size.x: _h_scrollbar.max_value = _width_content
	else: _h_scrollbar.max_value = 0
	_h_scrollbar.page = size.x

func _update_v_scrollbar() -> void:
	_v_scrollbar.max_value = _row_count_total
	_v_scrollbar.page = _row_count_shown - 1
	_row_first_shown = _v_scrollbar.value
	if _v_scrollbar.page >= _v_scrollbar.max_value: _v_scrollbar.max_value = 0

func scroll_x(new_value) -> void:
	queue_redraw()

var _old_scroll_y = -1
func scroll_y(new_value) -> void:
	if _old_scroll_y == new_value: return
	# print(_old_scroll_y, " ", new_value)
	_old_scroll_y = new_value
	_update_v_scrollbar()
	queue_redraw()

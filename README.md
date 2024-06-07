# ![icon](addons/godot-dataview/icon-64x64.png) DataView UI Control for Godot 4.x
This add a control called DataView, which is made to display efficiently a lot of data, like the results of an SQL request (gotten the godot-sqlite project) or whichever data that a custom function returns.
The control only renders the data shown to be efficient and can display a table with $`2^{53} - 1`$ rows maximum.

![Demo 01 animation](addons/godot-dataview/demo01.gif)

## Usage
First, you need to add the DataView control in the scene tree, then specify a data provider node in the property of the control.
The data provider must adhere to a contract like what's shown in the example bellow.
```gdscript
extends Node

signal data_changed

func get_row_count() -> int:
	return int(pow(2, 53) - 1)

func get_headers() -> Array:
	return ["#", "text", "int"]

func get_rows(row_start: int, size: int) -> Array:
	size = min(size, get_row_count() - row_start)
	return range(0, size).map(func(n): return _get_row(n + row_start))


const _arr = ["foo", "bar", "hello", "world"]
func _get_row(row_index: int) -> Array:
	return [row_index, _arr[hash(row_index)%_arr.size()], str(row_index)]
```
The signal `data_changed` must be called to notify the control to redraw its data if it were to change.
The control is themeable, and you can consult the theme file included that contains the fallback values to know what you can customize.
Functions `get_row_count`, `get_headers` and `get_rows` should return as quickly as possible as they are called in the draw function of the control.
If you are providing data from a slow source, data should be cached so it can be returned instantly. If that's impossible, dummy/empty data should be returned and when the data is retrived the signal `data_changed` should be called.

There is currently no way to edit data.

## Demo 2 - SQLite query results

![Demo 01 animation](addons/godot-dataview/demo02.gif)

I've been working on this control for this purpose. The data_provider object creates a worker thread, invoked using a semaphore to query the database when data is not already cached.
It caches a few thousand rows every time it "cache miss", in this test. As a draft, the code currently looks really bad, I'll post it here after working a bit on it.


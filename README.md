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

![Demo 02 animation](addons/godot-dataview/demo02.gif)

I've been working on this control for this purpose. The data_provider object creates a worker thread, invoked using a semaphore to query the database when data is not already cached.
It caches a few thousand rows every time it "cache miss", in this test.

```gdscript
extends Node

signal data_changed

## Instance of the SQLite class for database interactions.
var database: SQLite = SQLite.new()

## Database path and query constants.
const DATABASE_PATH = "user://data2.db"
const QUERY_SELECT = "SELECT * FROM Card JOIN CardData ON Card.cardDataId = CardData.id WHERE language IN ('English', 'French')"

## Variables to store headers, placeholder rows, and total row count.
var headers = []
var placeholder_row = []
var total_row_count = 0

## Threading-related variables for synchronization and thread management.
var mutex: Mutex = Mutex.new()
var semaphore: Semaphore = Semaphore.new()
var worker_thread: Thread = Thread.new()
var requested_row_range := [0, 0]
var pending_tasks_count := 0
var should_exit_thread := false

## Constants and variables for row caching.
const ROWS_BATCH_SIZE = 1000
var cached_row_range := [-1, -1]
var cached_rows := []

## Called when the node is added to the scene. Initializes the database and starts the worker thread.
func _ready():
	_initialize_database()
	_start_worker_thread()

## Called when the node is about to be removed from the scene. Terminates the worker thread.
func _exit_tree():
	_terminate_worker_thread()

## Initializes the database by opening it and querying for headers and total row count.
func _initialize_database():
	database.path = DATABASE_PATH
	database.open_db()
	if not database.query(QUERY_SELECT + " LIMIT 1") or database.query_result.size() == 0:
		return
	headers = database.query_result[0].keys()
	placeholder_row = headers.map(func(header): return "-")
	
	var query_count = "SELECT COUNT(*) as count FROM (%s)" % QUERY_SELECT
	if not database.query(query_count) or database.query_result.size() == 0:
		return
	total_row_count = database.query_result[0].count
	print(total_row_count)

## Starts the worker thread which handles background data fetching.
func _start_worker_thread():
	worker_thread.start(_thread_function)

## Worker thread function that waits for tasks, fetches data from the database, and updates the cache.
func _thread_function():
	while true:
		semaphore.wait()
		
		mutex.lock()
		var exit_thread = should_exit_thread
		var row_range = requested_row_range.duplicate()
		pending_tasks_count -= 1
		mutex.unlock()
		
		if exit_thread:
			return
		
		var limit_clause = "LIMIT %d, %d" % row_range
		if not database.query(QUERY_SELECT + " " + limit_clause) or database.query_result.size() == 0:
			print("Error querying database.")
		else:
			var data = database.query_result_by_reference.map(func(record): return record.values())
			call_deferred("_on_rows_fetched", row_range, data)

## Signals the worker thread to exit and waits for it to finish.
func _terminate_worker_thread():
	mutex.lock()
	should_exit_thread = true
	mutex.unlock()
	semaphore.post()
	worker_thread.wait_to_finish()

## Requests rows from the database by updating the requested range and signaling the semaphore if needed.
func _request_rows(from, size):
	from = max(from, 0)
	var should_post_semaphore = false
	
	mutex.lock()
	if requested_row_range != [from, size]:
		requested_row_range = [from, size]
		if pending_tasks_count == 0:
			pending_tasks_count += 1
			should_post_semaphore = true
	mutex.unlock()
	
	if should_post_semaphore:
		semaphore.post()

## Callback function when rows are fetched by the worker thread. Updates the cache and emits the data_changed signal.
func _on_rows_fetched(row_range, data):
	cached_row_range = row_range
	cached_rows = data
	data_changed.emit()

## Returns the total number of rows in the database.
func get_row_count() -> int:
	return total_row_count

## Returns the headers of the database table.
func get_headers() -> Array:
	return headers

## Checks if the requested row range is within the cached range.
func is_range_within_cached_range(requested_range: Array) -> bool:
	var cached_start = cached_row_range[0]
	var cached_end = cached_row_range[0] + cached_row_range[1]
	var requested_start = requested_range[0]
	var requested_end = requested_range[0] + requested_range[1]
	return cached_start <= requested_start and requested_end <= cached_end

## Returns the requested rows if they are cached, otherwise returns placeholder rows and initiates a data fetch.
func get_rows(row_start: int, size: int) -> Array:
	size = clamp(size, 0, total_row_count - row_start)
	
	if is_range_within_cached_range([row_start, size]):
		return cached_rows.slice(row_start - cached_row_range[0], row_start - cached_row_range[0] + size)
	
	_request_rows(row_start - ROWS_BATCH_SIZE / 2, ROWS_BATCH_SIZE)
	
	return range(size).map(func(n): return placeholder_row)
```


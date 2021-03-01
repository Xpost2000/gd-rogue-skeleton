# Should rename this later...
extends Node2D
const TILE_SIZE = 32;
export var CHUNK_MAX_SIZE = 16;

func in_bounds_of(position, chunk_x, chunk_y) -> bool:
	return (position.x >= chunk_x*CHUNK_MAX_SIZE && position.x < (chunk_x + CHUNK_MAX_SIZE)) && (position.y >= chunk_y*CHUNK_MAX_SIZE && position.y < (chunk_y + CHUNK_MAX_SIZE));

var world_chunks = [];
const neighbor_vectors = [Vector2(-1, 0),
						  Vector2(1, 0),
						  Vector2(0, 1),
						  Vector2(0, -1),
						  Vector2(1, 1),
						  Vector2(-1, 1),
						  Vector2(1, -1),
						  Vector2(-1, -1),
						  ];

func calculate_chunk_position(absolute_position):
	return Vector2(int(absolute_position.x / CHUNK_MAX_SIZE), int(absolute_position.y / CHUNK_MAX_SIZE));

# for now keep this in sync with tileset...
export var _solid_cells_list = [8, 9];
func is_solid_tile(position) -> bool:
	var cell_at_position = get_cell(position);
	for cell in _solid_cells_list:
		if cell == cell_at_position:
			return true;
	return false;

# provide world generation algorithms.
class WorldChunk:
	func _init(size):
		self.size = size;
		var visibility_result = [];
		var chunk_result = [];
		self.dirty_cells = [];
		for y in range(size):
			var row = [];
			var visibility_row = [];
			for x in range(size):
				row.push_back(0);
				visibility_row.push_back(false);
				# var probability = randf();
				# if probability > 0.7:
				# 	row.push_back(0);
				# elif probability > 0.1: 
				# 	row.push_back(8);
				# else:
				# 	# This push is for collision detection. Auxiliary holder
				# 	row.push_back(10);
				# 	# Animated cells draw on top of "real" cells.
				# 	# maybe this should be a dictionary.
				# 	animated_cells.push_back([Vector2(x, y), 10, 4]);
				self.dirty_cells.push_back(Vector2(x, y));
			chunk_result.push_back(row);
			visibility_result.push_back(visibility_row);
		self.cells = chunk_result;
		self.visible_cells = visibility_result;

	func mark_all_dirty():
		for y in range(size):
			for x in range(size):
				var any_animated = false;
				for animated_cell in animated_cells:
					if animated_cell[0].x == x && animated_cell[0].y == y:
						any_animated = true;
						break;
				if not any_animated:
					self.dirty_cells.push_back(Vector2(x, y));

	func clear_dirty():
		dirty_cells = [];

	func get_cell(x, y):
		return cells[y][x];

	func is_cell_visible(x, y):
		return visible_cells[y][x];

	# Technically we shouldn't be doing dirty cells for this one but whatever.
	func set_cell_visible(x, y, val):
		visible_cells[y][x] = val;
		self.dirty_cells.push_back(Vector2(x, y));

	func set_cell(x, y, val):
		for animated_cell in animated_cells:
			var position_of_cell = animated_cell[0];
			if position_of_cell.x == x && position_of_cell.y == y:
				animated_cells.erase(animated_cell);
				break;

		cells[y][x] = val;
		self.dirty_cells.push_back(Vector2(x, y));

	var size: int;
	var cells: Array;
	var visible_cells: Array;
	var animated_cells: Array;
	# for repainting
	var dirty_cells: Array;

func in_bounds(where):
	return (where.y >= 0 && where.y < len(world_chunks)) && where.x >= 0 && where.x < len(world_chunks[where.y]);

func get_chunk_at(where):
	var current_chunk_location = calculate_chunk_position(where); 
	if where.x >= 0 && where.y >= 0 && in_bounds(current_chunk_location):
		return world_chunks[current_chunk_location.y][current_chunk_location.x];
	return null;
func set_cell(where, value):
	var current_chunk_location = calculate_chunk_position(where); 
	var chunk = get_chunk_at(where);
	where -= current_chunk_location * CHUNK_MAX_SIZE;
	if chunk:
		chunk.set_cell(where.x, where.y, value);
func get_cell(where):
	var current_chunk_location = calculate_chunk_position(where); 
	var chunk = get_chunk_at(where);
	where -= current_chunk_location * CHUNK_MAX_SIZE;
	if chunk:
		return chunk.get_cell(where.x, where.y);
	return null;

func set_cell_visibility(where, value):
	var current_chunk_location = calculate_chunk_position(where); 
	var chunk = get_chunk_at(where);
	where -= current_chunk_location * CHUNK_MAX_SIZE;
	if chunk:
		chunk.set_cell_visible(where.x, where.y, value);
func is_cell_visible(where):
	var current_chunk_location = calculate_chunk_position(where); 
	var chunk = get_chunk_at(where);
	where -= current_chunk_location * CHUNK_MAX_SIZE;
	if chunk:
		return chunk.is_cell_visible(where.x, where.y);
	return null;

func _ready():
	randomize();
	world_chunks = [
		[WorldChunk.new(CHUNK_MAX_SIZE), WorldChunk.new(CHUNK_MAX_SIZE), WorldChunk.new(CHUNK_MAX_SIZE)],
		[WorldChunk.new(CHUNK_MAX_SIZE), WorldChunk.new(CHUNK_MAX_SIZE), WorldChunk.new(CHUNK_MAX_SIZE)],
		[WorldChunk.new(CHUNK_MAX_SIZE), WorldChunk.new(CHUNK_MAX_SIZE), WorldChunk.new(CHUNK_MAX_SIZE)],
			  ];
	pass;

var _global_tile_tick_frame = 0;
func paint_animated_tiles(tilemap, chunk, chunk_x, chunk_y):
	for animated_cell_datum in chunk.animated_cells:
		var cell = animated_cell_datum[0];
		var cell_frames = animated_cell_datum[2];
		var cell_id = animated_cell_datum[1] + _global_tile_tick_frame % cell_frames;
		var x = cell.x;
		var y = cell.y;

		tilemap.set_cell(x + (chunk_x * CHUNK_MAX_SIZE), y + (chunk_y * CHUNK_MAX_SIZE), cell_id);

func repaint_animated_tiles(current_chunk_position):
	var chunk_offsets = neighbor_vectors.duplicate();
	chunk_offsets.push_back(Vector2(0, 0));
	for neighbor_index in len(chunk_offsets):
		var neighbor_vector = chunk_offsets[neighbor_index];
		var offset_position = current_chunk_position + neighbor_vector;
		
		if in_bounds(offset_position):
			get_child(neighbor_index).show();
			call_deferred("paint_animated_tiles", get_child(neighbor_index), world_chunks[offset_position.y][offset_position.x], offset_position.x, offset_position.y);
		else:
			get_child(neighbor_index).hide();

# The current tileset shows the "invisible cell" as id 14.
# Obviously change this for the real stuff.
func paint_chunk_to_tilemap(tilemap, chunk, chunk_x, chunk_y):
	for dirty_cell in chunk.dirty_cells:
		var x = dirty_cell.x;
		var y = dirty_cell.y;
		if chunk.is_cell_visible(x, y):
			tilemap.set_cell(x + (chunk_x * CHUNK_MAX_SIZE), y + (chunk_y * CHUNK_MAX_SIZE), chunk.get_cell(x, y));
		else:
			tilemap.set_cell(x + (chunk_x * CHUNK_MAX_SIZE), y + (chunk_y * CHUNK_MAX_SIZE), 14);

	chunk.clear_dirty();

var _tick_time = 0;

func inclusively_redraw_chunks_around(chunk_position):
	if _tick_time > 0.15:
		repaint_animated_tiles(chunk_position);
	else:
		_global_tile_tick_frame += 1;

	var chunk_offsets = neighbor_vectors.duplicate();
	chunk_offsets.push_back(Vector2(0, 0));
	for neighbor_index in len(chunk_offsets):
		var neighbor_vector = chunk_offsets[neighbor_index];
		var offset_position = chunk_position + neighbor_vector;
		
		if in_bounds(offset_position):
			get_child(neighbor_index).show();
			paint_chunk_to_tilemap(get_child(neighbor_index), world_chunks[offset_position.y][offset_position.x], offset_position.x, offset_position.y);
		else:
			get_child(neighbor_index).hide();


func _process(delta):
	if _tick_time > 0.15:
		_tick_time = 0;
	else:
		_tick_time += delta;

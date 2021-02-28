extends Node2D

# Just quickly seeing what would get me a decent organization structure.
# Doing a roguelike might require me to do a lot of perversion of the idiomatic godot way
# in which case I'm just writing a python roguelike engine and using godot as my driver/client...
# Which works I guess?
onready var _world_map = $ChunkViews/Current;
onready var _message_log = $InterfaceLayer/Interface/Messages;

const TILE_SIZE = 32;

func create_tween(node_to_tween, property, start, end, tween_fn, tween_ease, time=1.0, delay=0.0):
	var new_tween = Tween.new();
	new_tween.interpolate_property(node_to_tween, property, start, end, time, tween_fn, tween_ease, delay)
	new_tween.connect("tween_all_completed", self, "remove_child", [new_tween]);
	new_tween.connect("tween_all_completed", new_tween, "queue_free");
	add_child(new_tween);
	return new_tween;

func movement_tween(node, start, end):
	create_tween(node, "position", start, end, Tween.TRANS_LINEAR, Tween.EASE_IN, 0.25).start();

func bump_tween(node, start, direction):
	var first = create_tween(node, "position", start, start + direction * (TILE_SIZE/2), Tween.TRANS_LINEAR, Tween.EASE_IN, 0.25);
	first.start();
	var second = create_tween(node, "position", start + direction * (TILE_SIZE/2), start, Tween.TRANS_LINEAR, Tween.EASE_IN, 0.25);

	first.connect("tween_all_completed", second, "start");

func player_movement_direction():
	if Input.is_action_just_pressed("ui_up"):
		return Vector2(0, -1);
	elif Input.is_action_just_pressed("ui_down"):
		return Vector2(0, 1);
	elif Input.is_action_just_pressed("ui_left"):
		return Vector2(-1, 0);
	elif Input.is_action_just_pressed("ui_right"):
		return Vector2(1, 0);

	return Vector2.ZERO;

# for now keep this in sync with tileset...
var _solid_cells_list = [8, 9];
func is_solid_tile(world_map, position) -> bool:
	var cell_at_position = world_map.get_cell(position.x, position.y);
	for cell in _solid_cells_list:
		if cell == cell_at_position:
			return true;
	return false;

func in_bounds_of(world_map, position) -> bool:
	var bounds_rect = world_map.get_used_rect();
	return (position.x >= bounds_rect.position.x && position.x < bounds_rect.size.x) && (position.y >= bounds_rect.position.y && position.y < bounds_rect.size.y);

var actual_player_position = Vector2.ZERO;
func update_player(player_node):
	var direction = player_movement_direction();

	player_node.position = (actual_player_position+Vector2(0.5, 0.5)) * TILE_SIZE;
	if direction != Vector2.ZERO:
		var new_player_position = actual_player_position + direction;

		var in_bounds = in_bounds_of(_world_map, new_player_position);
		var hitting_wall = is_solid_tile(_world_map, new_player_position);
		if in_bounds && not hitting_wall:
			actual_player_position = new_player_position;
		else:
			if hitting_wall:
				_message_log.push_message("You bumped into a wall");
			elif not in_bounds:
				_message_log.push_message("You've hit the entrance to the great beyond");

var test_chunk = [];
const CHUNK_SIZE = 96;
func empty_chunk():
	var chunk_result = [];
	for y in range(CHUNK_SIZE):
		var row = [];
		for x in range(CHUNK_SIZE):
			row.push_back(0);
		chunk_result.push_back(row);
	return chunk_result;

func _ready():
	test_chunk = empty_chunk();

# yes this is probably very slow. I'm trying to go as far as I can with the
# engine is just my client approach, since it's easier for me to do that.
func paint_chunk_to_tilemap(tilemap, chunk, chunk_x, chunk_y):
	tilemap.clear();
	for y in range(CHUNK_SIZE):
		for x in range(CHUNK_SIZE):
			tilemap.set_cell(x - (chunk_x * CHUNK_SIZE), y - (chunk_y * CHUNK_SIZE), chunk[y][x]);

func _process(_delta):
	paint_chunk_to_tilemap($ChunkViews/Top, test_chunk, 0, -1);
	paint_chunk_to_tilemap($ChunkViews/Bottom, test_chunk, 0, 1);
	paint_chunk_to_tilemap($ChunkViews/Right, test_chunk, 1, 0);
	paint_chunk_to_tilemap($ChunkViews/Left, test_chunk, -1, 0);
	paint_chunk_to_tilemap(_world_map, test_chunk, 0, 0);
	update_player($PlayerSprite);

func _physics_process(_delta):
	pass;

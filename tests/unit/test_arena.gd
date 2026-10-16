extends GutTest

const ARENA_SCENE := preload("res://scenes/arena.tscn")

var _arena: Arena


func before_each() -> void:
	_arena = ARENA_SCENE.instantiate() as Arena
	add_child_autofree(_arena)
	await wait_process_frames(2)


func test_camera_exists_and_can_be_current() -> void:
	assert_not_null(_arena.camera)
	assert_eq(_arena.camera, _arena.get_node("%Camera"))
	_arena.camera.make_current()
	assert_true(_arena.camera.current)
	assert_almost_eq(_arena.camera.fov, 38.0, 0.01)


func test_play_area_is_inside_camera_view() -> void:
	var vp_size: Vector2 = _arena.get_viewport().get_visible_rect().size
	var rect := Rect2(Vector2(0.03, 0.03), Vector2(0.94, 0.94))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var corner := Vector3(sx * Arena.ARENA_HALF.x, 0.0, sz * Arena.ARENA_HALF.y)
			assert_false(_arena.camera.is_position_behind(corner))
			var p: Vector2 = _arena.camera.unproject_position(corner) / vp_size
			assert_true(rect.has_point(p), "corner %s at %s should be on screen" % [corner, p])


func test_throw_origin_within_arena() -> void:
	for count in [1, 3, 5, 6]:
		for i in count:
			var o := _arena.throw_origin(i, count)
			assert_between(o.x, -Arena.ARENA_HALF.x, Arena.ARENA_HALF.x)
			assert_between(o.z, -Arena.ARENA_HALF.y, Arena.ARENA_HALF.y + 0.3)
			assert_between(o.y, 1.0, 3.0)
	assert_lt(_arena.throw_origin(0, 5).x, _arena.throw_origin(4, 5).x)


func test_throw_target_within_arena() -> void:
	for n in 50:
		var t := _arena.throw_target()
		assert_between(t.x, -Arena.ARENA_HALF.x, Arena.ARENA_HALF.x)
		assert_between(t.z, -Arena.ARENA_HALF.y, Arena.ARENA_HALF.y)
		assert_almost_eq(t.y, 0.0, 0.001)


func test_park_positions_tidy_row() -> void:
	for count in [1, 4, 6]:
		var last_x: float = -INF
		for i in count:
			var p := _arena.park_position(i, count)
			assert_almost_eq(p.y, 0.5, 0.001)
			assert_between(p.x, -Arena.ARENA_HALF.x, Arena.ARENA_HALF.x)
			assert_between(p.z, -Arena.ARENA_HALF.y, Arena.ARENA_HALF.y)
			assert_gt(p.x, last_x)
			last_x = p.x


func test_set_hoard_fill_clamps_and_reveals_coins() -> void:
	var start: int = _arena.visible_coin_count()
	_arena.set_hoard_fill(-3.0)
	assert_eq(_arena.hoard_fill, 0.0)
	_arena.set_hoard_fill(7.0)
	assert_eq(_arena.hoard_fill, 1.0)
	await wait_seconds(1.2)
	assert_gt(_arena.visible_coin_count(), start)
	_arena.set_hoard_fill(0.5)
	assert_eq(_arena.hoard_fill, 0.5)
	await wait_seconds(1.2)
	assert_between(_arena.visible_coin_count(), start + 1, Arena.COIN_COUNT - 1)


func test_flashes_do_not_error() -> void:
	_arena.flash_scorch()
	_arena.flash_bank()
	_arena.flash_scorch()
	await wait_seconds(0.9)
	assert_true(is_instance_valid(_arena))


func test_world_collision_layer() -> void:
	var world := _arena.get_node("World") as StaticBody3D
	assert_not_null(world)
	assert_eq(world.collision_layer, 1)
	assert_gte(world.get_child_count(), 5)


func test_dropped_box_rests_on_floor() -> void:
	var body := RigidBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 3
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)
	body.global_position = Vector3(0.0, 3.0, 0.0)
	await wait_seconds(1.6)
	assert_gt(body.global_position.y, 0.0, "box must not fall through the floor")
	assert_lt(body.global_position.y, 1.0, "box should have landed")
	assert_almost_eq(body.global_position.y, 0.5, 0.1)

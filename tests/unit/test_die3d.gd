extends GutTest

var _floor: StaticBody3D
var _root: Node3D
var _seen: Dictionary = {}


func before_each() -> void:
	Engine.time_scale = 1.0
	_root = Node3D.new()
	add_child_autofree(_root)
	_floor = StaticBody3D.new()
	_floor.collision_layer = 1
	_floor.collision_mask = 0
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(40, 2, 40)
	cs.shape = box
	cs.position = Vector3(0, -1, 0)
	_floor.add_child(cs)
	_root.add_child(_floor)
	for w: Array in [[Vector3(0, 2, -9), Vector3(40, 6, 1)], [Vector3(0, 2, 9), Vector3(40, 6, 1)],
			[Vector3(-9, 2, 0), Vector3(1, 6, 40)], [Vector3(9, 2, 0), Vector3(1, 6, 40)]]:
		var wall: StaticBody3D = StaticBody3D.new()
		wall.collision_layer = 1
		var wc: CollisionShape3D = CollisionShape3D.new()
		var wb: BoxShape3D = BoxShape3D.new()
		wb.size = w[1]
		wc.shape = wb
		wall.position = w[0]
		wall.add_child(wc)
		_root.add_child(wall)


func after_each() -> void:
	Engine.time_scale = 1.0


func _throw(die: Die3D, x: float) -> void:
	die.throw_from(Vector3(x, 2.5, 5.0), Vector3(x * 0.3, 0.0, -2.0), randf_range(0.8, 1.2))


func test_mesh_builds() -> void:
	var m: ArrayMesh = DieMesh.build()
	var arr: Array = m.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	assert_eq(verts.size(), 6 * (DieMesh.GRID + 1) * (DieMesh.GRID + 1))
	assert_eq(idx.size() / 3, 6 * DieMesh.GRID * DieMesh.GRID * 2)
	for v: Vector3 in verts:
		assert_lte(absf(v.x), 0.5001)
		assert_lte(absf(v.y), 0.5001)
		assert_lte(absf(v.z), 0.5001)
	assert_same(DieMesh.build(), m, "mesh is cached")


func test_face_normals_are_axes() -> void:
	assert_eq(DieMesh.FACE_NORMALS.size(), 6)
	var sum: Vector3 = Vector3.ZERO
	for n: Vector3 in DieMesh.FACE_NORMALS:
		assert_almost_eq(n.length(), 1.0, 0.0001)
		assert_almost_eq(maxf(absf(n.x), maxf(absf(n.y), absf(n.z))), 1.0, 0.0001)
		sum += n
	assert_eq(sum, Vector3.ZERO)


func test_setup_changes_faces() -> void:
	var d: Die3D = Die3D.new()
	d.setup("cinder")  # before entering the tree
	_root.add_child(d)
	assert_eq(d.faces, [1, 1, 4, 6, 6, 6] as Array[int])
	d.setup("obsidian")
	assert_eq(d.type_id, "obsidian")
	assert_eq(d.faces, [2, 3, 4, 4, 5, 6] as Array[int])


func test_throw_settles_flat() -> void:
	Engine.time_scale = 4.0
	var d: Die3D = Die3D.new()
	_root.add_child(d)
	watch_signals(d)
	_throw(d, 0.0)
	await wait_for_signal(d.settled, 12.0)
	assert_signal_emit_count(d, "settled", 1)
	assert_between(d.top_value(), 1, 6)
	assert_eq(d.top_value(), d.faces[d.top_face_index()])
	var up: float = (d.global_basis * DieMesh.FACE_NORMALS[d.top_face_index()]).dot(Vector3.UP)
	assert_gt(up, 0.985)


func test_all_faces_appear() -> void:
	Engine.time_scale = 4.0
	var count: int = 0
	var rounds: int = 8
	for r: int in rounds:
		var dice: Array[Die3D] = []
		for i: int in 5:
			var d: Die3D = Die3D.new()
			_root.add_child(d)
			d.setup("bone")
			dice.append(d)
		for i: int in dice.size():
			_throw(dice[i], -4.0 + i * 2.0)
		var pending: Array[Die3D] = dice.duplicate()
		var t0: int = Time.get_ticks_msec()
		while not pending.is_empty() and Time.get_ticks_msec() - t0 < 15000:
			await get_tree().physics_frame
			for d: Die3D in pending.duplicate():
				if not d.is_physics_processing():
					pending.erase(d)
					_seen[d.top_face_index()] = true
					count += 1
		assert_eq(pending.size(), 0, "all dice settled")
		for d: Die3D in dice:
			d.queue_free()
	assert_eq(count, rounds * 5)
	for f: int in 6:
		assert_true(_seen.has(f), "face %d appeared" % f)

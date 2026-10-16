class_name Die3D
extends RigidBody3D
## A physically thrown bone die. Emits `settled` once per throw when it rests flat.

signal settled(die: Die3D)

const SHADER: Shader = preload("res://shaders/die3d.gdshader")
const FLAT_DOT: float = 0.985
const SLOW_LIN: float = 0.12
const SLOW_ANG: float = 0.3
const REST_TIME: float = 0.35
const KICK_TIME: float = 0.5
const HARD_TIMEOUT: float = 6.0

var frozen: bool = false
var type_id: String = "bone"
var faces: Array[int] = [1, 2, 3, 4, 5, 6]

var _mesh_instance: MeshInstance3D
var _material: ShaderMaterial
var _watching: bool = false
var _elapsed: float = 0.0
var _slow_time: float = 0.0
var _kicks: int = 0
var _glow_tween: Tween
var _flash_tween: Tween
var _glow: float = 0.0


func _init() -> void:
	mass = 1.0
	var pm: PhysicsMaterial = PhysicsMaterial.new()
	pm.bounce = 0.3
	pm.friction = 0.8
	physics_material_override = pm
	linear_damp = 0.15
	angular_damp = 0.35
	continuous_cd = true
	can_sleep = true
	collision_layer = 2
	collision_mask = 1 | 2


func _ready() -> void:
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = DieMesh.build()
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_mesh_instance.material_override = _material
	add_child(_mesh_instance)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3.ONE * 0.98
	cs.shape = box
	add_child(cs)
	_apply_type()
	set_physics_process(false)


func setup(new_type_id: String) -> void:
	type_id = new_type_id
	faces = DiceTypes.faces_of(new_type_id)
	_apply_type()


func _apply_type() -> void:
	if _material == null:
		return
	var info: Dictionary = DiceTypes.TYPES[type_id]
	faces = DiceTypes.faces_of(type_id)
	var body: Color = info["body"]
	_material.set_shader_parameter("faces_a", Vector4(faces[0], faces[1], faces[2], faces[3]))
	_material.set_shader_parameter("faces_b", Vector2(faces[4], faces[5]))
	_material.set_shader_parameter("body_color", body)
	_material.set_shader_parameter("edge_color", body.darkened(0.55))
	_material.set_shader_parameter("pip_color", info["pip"])
	_material.set_shader_parameter("glow", _glow)
	_material.set_shader_parameter("flash_amount", 0.0)


func throw_from(origin: Vector3, target: Vector3, strength: float = 1.0) -> void:
	freeze = true
	var rot: Basis = Basis(Quaternion(_random_unit(), randf_range(0.0, TAU)))
	global_transform = Transform3D(rot, origin)
	freeze = false
	sleeping = false
	var dir: Vector3 = target - origin
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = Vector3.FORWARD
	dir = dir.normalized()
	var speed: float = randf_range(6.0, 9.0) * strength
	linear_velocity = dir * speed + Vector3.UP * randf_range(1.5, 3.0) * strength
	angular_velocity = _random_unit() * randf_range(12.0, 25.0)
	_start_watch()


func _start_watch() -> void:
	_watching = true
	_elapsed = 0.0
	_slow_time = 0.0
	_kicks = 0
	set_physics_process(true)


func _random_unit() -> Vector3:
	var v: Vector3 = Vector3(randfn(0.0, 1.0), randfn(0.0, 1.0), randfn(0.0, 1.0))
	if v.length() < 0.001:
		return Vector3.UP
	return v.normalized()


func _physics_process(delta: float) -> void:
	if not _watching:
		set_physics_process(false)
		return
	_elapsed += delta
	var slow: bool = linear_velocity.length() < SLOW_LIN and angular_velocity.length() < SLOW_ANG
	if slow or sleeping:
		_slow_time += delta
	else:
		_slow_time = 0.0
	if _elapsed >= HARD_TIMEOUT:
		_snap_flat()
		_finish()
		return
	if _slow_time >= REST_TIME:
		if _is_flat():
			_finish()
		elif _slow_time >= KICK_TIME:
			_kick()


func _is_flat() -> bool:
	return (global_basis * DieMesh.FACE_NORMALS[top_face_index()]).dot(Vector3.UP) > FLAT_DOT


func _kick() -> void:
	_kicks += 1
	_slow_time = 0.0
	sleeping = false
	var side: Vector3 = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
	apply_central_impulse(Vector3.UP * 1.6 + side * 0.6)
	apply_torque_impulse(_random_unit() * 0.8)


func _snap_flat() -> void:
	var n: Vector3 = global_basis * DieMesh.FACE_NORMALS[top_face_index()]
	var align: Basis = Basis(Quaternion(n, Vector3.UP))
	var b: Basis = (align * global_basis).orthonormalized()
	# snap yaw to a quarter turn
	var fwd: Vector3 = b * Vector3.RIGHT
	var yaw: float = atan2(-fwd.z, fwd.x)
	var snapped_yaw: float = roundf(yaw / (PI * 0.5)) * (PI * 0.5)
	b = Basis(Vector3.UP, snapped_yaw - yaw) * b
	var pos: Vector3 = global_position
	pos.y = 0.5
	global_transform = Transform3D(b, pos)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


func _finish() -> void:
	_watching = false
	set_physics_process(false)
	settled.emit(self)


func top_face_index() -> int:
	var best: int = 0
	var best_y: float = -2.0
	for i: int in 6:
		var y: float = (global_basis * DieMesh.FACE_NORMALS[i]).y
		if y > best_y:
			best_y = y
			best = i
	return best


func top_value() -> int:
	return faces[top_face_index()]


func set_frozen_visual(on: bool) -> void:
	if _material == null:
		return
	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()
	var cur: float = _glow
	_glow_tween = create_tween()
	_glow_tween.tween_method(_set_glow, cur, 1.0 if on else 0.0, 0.25)


func _set_glow(v: float) -> void:
	_glow = v
	_material.set_shader_parameter("glow", v)


func flash(color: Color, duration: float = 0.45) -> void:
	if _material == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_material.set_shader_parameter("flash_color", color)
	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_flash, 0.0, 1.0, duration * 0.25)
	_flash_tween.tween_method(_set_flash, 1.0, 0.0, duration * 0.75)


func _set_flash(v: float) -> void:
	_material.set_shader_parameter("flash_amount", v)


func set_heat(h: float) -> void:
	if _material != null:
		_material.set_shader_parameter("pip_heat", clampf(h, 0.0, 1.0))


func park_at(pos: Vector3) -> void:
	_watching = false
	set_physics_process(false)
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	# random face up, random yaw
	var n: Vector3 = DieMesh.FACE_NORMALS[randi() % 6]
	var b: Basis = Basis(Quaternion(n, Vector3.UP))
	b = Basis(Vector3.UP, randf() * TAU) * b
	global_transform = Transform3D(b, Vector3(pos.x, 0.5, pos.z))

class_name Arena
extends Node3D
## The ritual altar: physical play area, torchlit atmosphere, looming dragon and the hoard.
## Public API: ARENA_HALF, camera, throw_origin(), throw_target(), park_position(),
## flash_scorch(), flash_bank(), set_hoard_fill().

const ARENA_HALF := Vector2(4.4, 2.7)
const CAMERA_POS := Vector3(0.0, 9.0, 9.6)
const CAMERA_TARGET := Vector3(0.0, 0.0, -0.3)
const ALTAR_RADIUS := 7.6
const ALTAR_SQUASH := 0.6
const CURB_WIDTH := 0.42
const CURB_HEIGHT := 0.3
const DRAGON_SIZE := Vector2(28.0, 15.75)
const DRAGON_POS := Vector3(-1.0, -3.13, -10.5)
const DRAGON_EYE_PX := Vector2(1062.0, 478.0)
const HOARD_POS := Vector3(-6.1, 0.0, -0.4)
const HOARD_RADIUS := 1.25
const HOARD_HEIGHT := 1.0
const COIN_COUNT := 700
const COIN_MIN_VISIBLE := 14
const TORCH_FLAME_Y := 1.75

const STONE_SHADER := preload("res://shaders/altar_stone.gdshader")
const RUNE_SHADER := preload("res://shaders/rune_ring.gdshader")
const GOLD_SHADER := preload("res://shaders/gold.gdshader")
const DRAGON_SHADER := preload("res://shaders/arena_dragon.gdshader")
const FOG_SHADER := preload("res://shaders/arena_fog.gdshader")
const DRAGON_ART := preload("res://assets/art/dragon.svg")
const BACKGROUND_ART := preload("res://assets/art/background.svg")

var camera: Camera3D
var hoard_fill: float = 0.0

var _rng := RandomNumberGenerator.new()
var _glow_tex: GradientTexture2D
var _stone_mat: ShaderMaterial
var _rune_mat: ShaderMaterial
var _dragon_mat: ShaderMaterial
var _dragon: MeshInstance3D
var _eye_glow: Sprite3D
var _torch_lights: Array[OmniLight3D] = []
var _scorch_light: OmniLight3D
var _bank_light: OmniLight3D
var _hoard_light: OmniLight3D
var _coins: MultiMeshInstance3D
var _mound: MeshInstance3D
var _pile: Node3D
var _hoard_shown: float = 0.0
var _hoard_tween: Tween
var _flash_tween: Tween
var _env: Environment


func _ready() -> void:
	_rng.seed = 20260
	camera = %Camera as Camera3D
	camera.look_at_from_position(CAMERA_POS, CAMERA_TARGET)
	_glow_tex = _make_glow_texture()
	_build_environment()
	_build_altar()
	_build_curb()
	_build_runes()
	_build_lights()
	_build_torches()
	_build_backdrop()
	_build_mist()
	_build_embers()
	_build_hoard()
	_apply_hoard(0.0)
	_start_ambient_tweens()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Where die `index` of `count` is released: along the front edge, above the floor.
func throw_origin(index: int, count: int) -> Vector3:
	var span: float = ARENA_HALF.x - 1.0
	var t: float = 0.5 if count <= 1 else float(index) / float(count - 1)
	return Vector3(lerpf(-span, span, t), 2.0, ARENA_HALF.y - 0.6)


## Random landing point near the middle of the play area.
func throw_target() -> Vector3:
	return Vector3(_rng.randf_range(-1.8, 1.8), 0.0, _rng.randf_range(-1.0, 0.9))


## Tidy resting slot for an unthrown die.
func park_position(index: int, count: int) -> Vector3:
	var spacing: float = minf(1.45, (ARENA_HALF.x - 1.0) * 2.0 / float(maxi(count - 1, 1)))
	var x: float = (float(index) - float(count - 1) * 0.5) * spacing
	return Vector3(x, 0.5, ARENA_HALF.y - 0.8)


## Red-orange burst: the dragon breathes on the player.
func flash_scorch() -> void:
	_run_flash(_scorch_light, 9.0, Color(1.0, 0.18, 0.03), 1.0, 0.6)


## Warm golden pulse for banking points.
func flash_bank() -> void:
	_run_flash(_bank_light, 7.0, Color(1.0, 0.75, 0.25), 0.0, 0.7)


## Grows the visible pile of treasure. ratio is clamped to 0..1.
func set_hoard_fill(ratio: float) -> void:
	hoard_fill = clampf(ratio, 0.0, 1.0)
	if _hoard_tween != null:
		_hoard_tween.kill()
	if not is_inside_tree():
		_apply_hoard(hoard_fill)
		return
	_hoard_tween = create_tween()
	_hoard_tween.tween_method(_apply_hoard, _hoard_shown, hoard_fill, 0.9) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Number of coins currently revealed (for tests / debugging).
func visible_coin_count() -> int:
	if _coins == null:
		return 0
	return _coins.multimesh.visible_instance_count


# ---------------------------------------------------------------------------
# Building blocks
# ---------------------------------------------------------------------------

func _make_glow_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	return t


func _additive_particle_material(tint: Color = Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _glow_tex
	m.albedo_color = tint
	m.disable_receive_shadows = true
	return m


func _build_environment() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.03, 0.012, 0.025)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.3, 0.22, 0.22)
	_env.ambient_light_energy = 0.38
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_exposure = 1.05
	_env.glow_enabled = true
	_env.glow_intensity = 1.1
	_env.glow_strength = 1.0
	_env.glow_bloom = 0.05
	_env.glow_hdr_threshold = 0.7
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	_env.fog_enabled = true
	_env.fog_light_color = Color(0.14, 0.05, 0.07)
	_env.fog_density = 0.012
	_env.adjustment_enabled = true
	_env.adjustment_contrast = 1.1
	_env.adjustment_saturation = 1.08
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = _env
	add_child(we)


func _build_altar() -> void:
	_stone_mat = ShaderMaterial.new()
	_stone_mat.shader = STONE_SHADER
	_stone_mat.set_shader_parameter("altar_squash", ALTAR_SQUASH)
	_stone_mat.set_shader_parameter("altar_radius", ALTAR_RADIUS)
	var cyl := CylinderMesh.new()
	cyl.top_radius = ALTAR_RADIUS
	cyl.bottom_radius = ALTAR_RADIUS * 0.82
	cyl.height = 2.4
	cyl.radial_segments = 64
	cyl.rings = 1
	cyl.material = _stone_mat
	var altar := MeshInstance3D.new()
	altar.name = "Altar"
	altar.mesh = cyl
	altar.position = Vector3(0.0, -1.2, 0.0)
	altar.scale = Vector3(1.0, 1.0, ALTAR_SQUASH)
	add_child(altar)

	# Dark plinth below so the altar floats above the abyss.
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = ALTAR_RADIUS * 0.8
	base_mesh.bottom_radius = ALTAR_RADIUS * 0.4
	base_mesh.height = 5.0
	base_mesh.material = _stone_mat
	base.mesh = base_mesh
	base.position = Vector3(0.0, -4.9, 0.0)
	base.scale = Vector3(1.0, 1.0, ALTAR_SQUASH)
	add_child(base)


func _build_curb() -> void:
	var root := Node3D.new()
	root.name = "Curb"
	add_child(root)
	var hx: float = ARENA_HALF.x
	var hz: float = ARENA_HALF.y
	# Left/right pieces span the full depth; back/front pieces span between them.
	var pieces: Array[Array] = [
		[Vector3(CURB_WIDTH, CURB_HEIGHT, hz * 2.0 + CURB_WIDTH * 2.0), Vector3(-(hx + CURB_WIDTH * 0.5), CURB_HEIGHT * 0.5, 0.0)],
		[Vector3(CURB_WIDTH, CURB_HEIGHT, hz * 2.0 + CURB_WIDTH * 2.0), Vector3(hx + CURB_WIDTH * 0.5, CURB_HEIGHT * 0.5, 0.0)],
		[Vector3(hx * 2.0, CURB_HEIGHT, CURB_WIDTH), Vector3(0.0, CURB_HEIGHT * 0.5, -(hz + CURB_WIDTH * 0.5))],
		[Vector3(hx * 2.0, CURB_HEIGHT, CURB_WIDTH), Vector3(0.0, CURB_HEIGHT * 0.5, hz + CURB_WIDTH * 0.5)],
	]
	for p in pieces:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = p[0] as Vector3
		bm.material = _stone_mat
		mi.mesh = bm
		mi.position = p[1] as Vector3
		root.add_child(mi)


func _build_runes() -> void:
	_rune_mat = ShaderMaterial.new()
	_rune_mat.shader = RUNE_SHADER
	_rune_mat.set_shader_parameter("arena_half", ARENA_HALF)
	_rune_mat.set_shader_parameter("squash", ALTAR_SQUASH)
	var plane := PlaneMesh.new()
	plane.size = Vector2(18.0, 18.0)
	plane.material = _rune_mat
	var mi := MeshInstance3D.new()
	mi.name = "RuneRing"
	mi.mesh = plane
	mi.position = Vector3(0.0, 0.012, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_lights() -> void:
	var moon := DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.light_color = Color(0.55, 0.45, 0.72)
	moon.light_energy = 0.42
	moon.shadow_enabled = true
	moon.shadow_blur = 1.6
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	moon.directional_shadow_max_distance = 22.0
	moon.rotation_degrees = Vector3(-52.0, 200.0, 0.0)
	add_child(moon)

	# Soft overhead ritual glow so dice stay readable in the middle of the table.
	var ritual := OmniLight3D.new()
	ritual.name = "RitualGlow"
	ritual.light_color = Color(1.0, 0.74, 0.5)
	ritual.light_energy = 0.55
	ritual.omni_range = 11.0
	ritual.omni_attenuation = 1.0
	ritual.position = Vector3(0.0, 5.0, 0.3)
	add_child(ritual)

	_scorch_light = OmniLight3D.new()
	_scorch_light.name = "ScorchLight"
	_scorch_light.light_color = Color(1.0, 0.2, 0.04)
	_scorch_light.light_energy = 0.0
	_scorch_light.omni_range = 16.0
	_scorch_light.position = Vector3(0.0, 3.0, -1.0)
	add_child(_scorch_light)

	_bank_light = OmniLight3D.new()
	_bank_light.name = "BankLight"
	_bank_light.light_color = Color(1.0, 0.78, 0.3)
	_bank_light.light_energy = 0.0
	_bank_light.omni_range = 14.0
	_bank_light.position = Vector3(-2.0, 3.0, 1.0)
	add_child(_bank_light)


func _build_torches() -> void:
	var spots: Array[Vector3] = [
		Vector3(-5.6, 0.0, -2.9), Vector3(5.6, 0.0, -2.9),
		Vector3(-5.5, 0.0, 3.4), Vector3(5.5, 0.0, 3.4),
	]
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.07, 0.06, 0.07)
	iron.metallic = 0.6
	iron.roughness = 0.45
	var coal := StandardMaterial3D.new()
	coal.albedo_color = Color(0.2, 0.05, 0.02)
	coal.emission_enabled = true
	coal.emission = Color(1.0, 0.4, 0.08)
	coal.emission_energy_multiplier = 1.3
	var idx: int = 0
	for s in spots:
		var torch := Node3D.new()
		torch.name = "Torch%d" % idx
		torch.position = s
		add_child(torch)

		var foot := MeshInstance3D.new()
		var foot_mesh := CylinderMesh.new()
		foot_mesh.top_radius = 0.28
		foot_mesh.bottom_radius = 0.4
		foot_mesh.height = 0.35
		foot_mesh.material = _stone_mat
		foot.mesh = foot_mesh
		foot.position.y = 0.17
		torch.add_child(foot)

		var pole := MeshInstance3D.new()
		var pole_mesh := CylinderMesh.new()
		pole_mesh.top_radius = 0.06
		pole_mesh.bottom_radius = 0.09
		pole_mesh.height = 1.3
		pole_mesh.material = iron
		pole.mesh = pole_mesh
		pole.position.y = 0.95
		torch.add_child(pole)

		var bowl := MeshInstance3D.new()
		var bowl_mesh := CylinderMesh.new()
		bowl_mesh.top_radius = 0.34
		bowl_mesh.bottom_radius = 0.14
		bowl_mesh.height = 0.3
		bowl_mesh.material = iron
		bowl.mesh = bowl_mesh
		bowl.position.y = 1.62
		torch.add_child(bowl)

		var embers := MeshInstance3D.new()
		var ember_mesh := SphereMesh.new()
		ember_mesh.radius = 0.26
		ember_mesh.height = 0.24
		ember_mesh.material = coal
		embers.mesh = ember_mesh
		embers.position.y = 1.74
		torch.add_child(embers)

		torch.add_child(_make_flame())
		torch.add_child(_make_sparks())

		var light := OmniLight3D.new()
		light.name = "Light"
		light.light_color = Color(1.0, 0.52, 0.18)
		light.light_energy = 3.6
		light.omni_range = 9.0
		light.omni_attenuation = 1.2
		light.position = Vector3(0.0, TORCH_FLAME_Y + 0.4, 0.0)
		torch.add_child(light)
		_torch_lights.append(light)
		idx += 1


func _make_flame() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Flame"
	p.amount = 40
	p.lifetime = 0.75
	p.position = Vector3(0.0, TORCH_FLAME_Y, 0.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.12
	p.direction = Vector3.UP
	p.spread = 14.0
	p.gravity = Vector3(0.0, 2.4, 0.0)
	p.initial_velocity_min = 0.7
	p.initial_velocity_max = 1.5
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.6))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	ramp.colors = PackedColorArray([Color(1.0, 0.8, 0.4, 0.55), Color(1.0, 0.38, 0.06, 0.4), Color(0.5, 0.06, 0.02, 0.0)])
	p.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.55)
	quad.material = _additive_particle_material()
	p.mesh = quad
	return p


func _make_sparks() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Sparks"
	p.amount = 10
	p.lifetime = 2.2
	p.position = Vector3(0.0, TORCH_FLAME_Y + 0.1, 0.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.2
	p.direction = Vector3.UP
	p.spread = 35.0
	p.gravity = Vector3(0.2, 0.6, 0.0)
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 2.2
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	p.explosiveness = 0.0
	p.randomness = 1.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	ramp.colors = PackedColorArray([Color(1.0, 0.8, 0.3, 1.0), Color(1.0, 0.35, 0.05, 0.8), Color(0.5, 0.05, 0.0, 0.0)])
	p.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	quad.material = _additive_particle_material()
	p.mesh = quad
	return p


func _build_backdrop() -> void:
	# Far sky with the blood moon.
	var sky_mat := StandardMaterial3D.new()
	sky_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sky_mat.albedo_texture = BACKGROUND_ART
	sky_mat.albedo_color = Color(0.3, 0.2, 0.25)
	sky_mat.disable_fog = true
	sky_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sky_mesh := QuadMesh.new()
	sky_mesh.size = Vector2(70.0, 39.4)
	sky_mesh.material = sky_mat
	var sky := MeshInstance3D.new()
	sky.name = "Sky"
	sky.mesh = sky_mesh
	sky.position = Vector3(-5.0, -17.8, -30.0)
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sky)

	_dragon_mat = ShaderMaterial.new()
	_dragon_mat.shader = DRAGON_SHADER
	_dragon_mat.set_shader_parameter("art", DRAGON_ART)
	var dm := QuadMesh.new()
	dm.size = DRAGON_SIZE
	dm.material = _dragon_mat
	_dragon = MeshInstance3D.new()
	_dragon.name = "Dragon"
	_dragon.mesh = dm
	_dragon.position = DRAGON_POS
	_dragon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_dragon)

	# Glowing eye: additive halo pinned to the eye in the art.
	var eye_off := Vector3(
			(DRAGON_EYE_PX.x - 960.0) / 1920.0 * DRAGON_SIZE.x,
			(540.0 - DRAGON_EYE_PX.y) / 1080.0 * DRAGON_SIZE.y, 0.1)
	_eye_glow = Sprite3D.new()
	_eye_glow.name = "EyeGlow"
	_eye_glow.texture = _glow_tex
	_eye_glow.pixel_size = 0.035
	_eye_glow.shaded = false
	_eye_glow.double_sided = true
	_eye_glow.transparent = true
	_eye_glow.modulate = Color(1.0, 0.6, 0.12, 0.9)
	_eye_glow.position = eye_off
	var eye_mat := StandardMaterial3D.new()
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	eye_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	eye_mat.albedo_texture = _glow_tex
	eye_mat.vertex_color_use_as_albedo = true
	eye_mat.disable_fog = true
	eye_mat.no_depth_test = false
	_eye_glow.material_override = eye_mat
	_dragon.add_child(_eye_glow)


func _build_mist() -> void:
	var layers: Array[Dictionary] = [
		{"pos": Vector3(0.0, -0.5, -7.0), "size": 36.0, "dens": 0.8, "hole": Vector2(0.0, 0.0), "col": Color(0.6, 0.22, 0.16)},
		{"pos": Vector3(0.0, -2.4, -9.2), "size": 40.0, "dens": 0.4, "hole": Vector2(0.0, 0.0), "col": Color(0.22, 0.08, 0.14)},
		{"pos": Vector3(0.0, -0.9, 0.0), "size": 34.0, "dens": 0.9, "hole": Vector2(7.0, 4.2), "col": Color(0.3, 0.1, 0.12)},
	]
	var i: int = 0
	for l in layers:
		var m := ShaderMaterial.new()
		m.shader = FOG_SHADER
		m.set_shader_parameter("fog_color", l["col"])
		m.set_shader_parameter("density", l["dens"])
		m.set_shader_parameter("plane_size", l["size"])
		m.set_shader_parameter("hole_half", l["hole"])
		m.set_shader_parameter("drift", Vector2(0.02 + 0.01 * i, 0.006))
		m.render_priority = -1 - i
		var pm := PlaneMesh.new()
		pm.size = Vector2(l["size"] as float, l["size"] as float)
		pm.material = m
		var mi := MeshInstance3D.new()
		mi.name = "Mist%d" % i
		mi.mesh = pm
		mi.position = l["pos"] as Vector3
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		i += 1


func _build_embers() -> void:
	var p := CPUParticles3D.new()
	p.name = "Embers"
	p.amount = 140
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.position = Vector3(0.0, 0.0, -1.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(9.0, 0.2, 7.0)
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3(0.15, 0.35, 0.0)
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.9
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	p.randomness = 1.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.8, 1.0])
	ramp.colors = PackedColorArray([Color(1.0, 0.5, 0.1, 0.0), Color(1.0, 0.55, 0.12, 0.9), Color(0.9, 0.25, 0.05, 0.5), Color(0.5, 0.05, 0.0, 0.0)])
	p.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(0.11, 0.11)
	quad.material = _additive_particle_material()
	p.mesh = quad
	add_child(p)


func _build_hoard() -> void:
	var root := Node3D.new()
	root.name = "Hoard"
	root.position = HOARD_POS
	add_child(root)

	var gold_mat := ShaderMaterial.new()
	gold_mat.shader = GOLD_SHADER
	var dull_mat := ShaderMaterial.new()
	dull_mat.shader = GOLD_SHADER
	dull_mat.set_shader_parameter("brightness", 0.5)
	dull_mat.set_shader_parameter("sparkle_strength", 0.0)

	var mound_mesh := CylinderMesh.new()
	mound_mesh.top_radius = 0.0
	mound_mesh.bottom_radius = HOARD_RADIUS * 0.97
	mound_mesh.height = HOARD_HEIGHT * 0.95
	mound_mesh.radial_segments = 20
	mound_mesh.rings = 1
	mound_mesh.material = dull_mat
	_mound = MeshInstance3D.new()
	_mound.name = "Mound"
	_mound.mesh = mound_mesh
	_pile = Node3D.new()
	_pile.name = "Pile"
	root.add_child(_pile)
	_mound.position.y = HOARD_HEIGHT * 0.95 * 0.5 - 0.03
	_pile.add_child(_mound)

	var coin_mesh := CylinderMesh.new()
	coin_mesh.top_radius = 0.21
	coin_mesh.bottom_radius = 0.21
	coin_mesh.height = 0.05
	coin_mesh.radial_segments = 10
	coin_mesh.rings = 1
	coin_mesh.material = gold_mat

	var entries: Array[Dictionary] = []
	for i in COIN_COUNT:
		var r: float = HOARD_RADIUS * sqrt(_rng.randf())
		var a: float = _rng.randf() * TAU
		var h: float = HOARD_HEIGHT * pow(maxf(0.0, 1.0 - r / HOARD_RADIUS), 1.1) + _rng.randf() * 0.06
		var basis := Basis.from_euler(Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf() * TAU, _rng.randf_range(-0.6, 0.6)))
		entries.append({"h": h, "t": Transform3D(basis, Vector3(cos(a) * r, h, sin(a) * r * 0.9))})

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = coin_mesh
	mm.instance_count = COIN_COUNT
	for i in COIN_COUNT:
		mm.set_instance_transform(i, entries[i]["t"] as Transform3D)
	_coins = MultiMeshInstance3D.new()
	_coins.name = "Coins"
	_coins.multimesh = mm
	_pile.add_child(_coins)

	_hoard_light = OmniLight3D.new()
	_hoard_light.name = "HoardLight"
	_hoard_light.light_color = Color(1.0, 0.72, 0.28)
	_hoard_light.light_energy = 1.4
	_hoard_light.omni_range = 5.0
	_hoard_light.position = Vector3(0.6, 1.8, 0.4)
	root.add_child(_hoard_light)


# ---------------------------------------------------------------------------
# Animation
# ---------------------------------------------------------------------------

func _start_ambient_tweens() -> void:
	for light in _torch_lights:
		_flicker(light, light.light_energy)

	var breathe := _dragon.create_tween().set_loops()
	breathe.tween_property(_dragon, "scale", Vector3(1.012, 1.018, 1.0), 3.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breathe.tween_property(_dragon, "scale", Vector3.ONE, 3.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var eye := _eye_glow.create_tween().set_loops()
	eye.tween_property(_eye_glow, "modulate:a", 0.5, 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	eye.tween_property(_eye_glow, "modulate:a", 1.0, 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Endless random flicker: each step picks a new energy and duration.
func _flicker(light: OmniLight3D, base: float) -> void:
	if not is_instance_valid(light) or not light.is_inside_tree():
		return
	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", base * _rng.randf_range(0.68, 1.22), _rng.randf_range(0.05, 0.17))
	tw.finished.connect(_flicker.bind(light, base))


func _run_flash(light: OmniLight3D, peak: float, rune_color: Color, eye_flare: float, duration: float) -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	_rune_mat.set_shader_parameter("flash_color", rune_color)
	if not is_inside_tree():
		return
	_flash_tween = create_tween()
	_flash_tween.set_parallel(true)
	_flash_tween.tween_property(light, "light_energy", peak, duration * 0.2).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_method(_set_flash_amount.bind(eye_flare), 0.0, 1.0, duration * 0.2)
	_flash_tween.chain().set_parallel(true)
	_flash_tween.tween_property(light, "light_energy", 0.0, duration * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_method(_set_flash_amount.bind(eye_flare), 1.0, 0.0, duration * 0.8)


func _set_flash_amount(amount: float, eye_flare: float) -> void:
	_rune_mat.set_shader_parameter("flash", amount)
	_dragon_mat.set_shader_parameter("flare", amount * eye_flare)
	_eye_glow.scale = Vector3.ONE * (1.0 + amount * eye_flare * 1.2)


func _apply_hoard(shown: float) -> void:
	_hoard_shown = shown
	var count: int = int(round(lerpf(float(COIN_MIN_VISIBLE), float(COIN_COUNT), shown)))
	_coins.multimesh.visible_instance_count = count
	var s: float = lerpf(0.22, 1.0, shown)
	var xz: float = lerpf(0.5, 1.0, shown)
	_pile.scale = Vector3(xz, s, xz)
	_hoard_light.light_energy = lerpf(0.5, 1.6, shown)

class_name DieMesh
extends RefCounted
## Procedural rounded cube (edge 1.0) used for every die.
## COLOR.r = face_index / 8.0, UV 0..1 per face (pips upright when viewed from outside),
## TANGENT = face "right" axis so the shader can bump-map in face space.

const FACE_NORMALS: Array[Vector3] = [
	Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD,
]
const GRID: int = 10
const HALF: float = 0.5
const RADIUS: float = 0.11

static var _cache: ArrayMesh = null


static func face_axes(face: int) -> Array[Vector3]:
	## Returns [u (right), v (up)] with u x v == normal, seen from outside.
	var n: Vector3 = FACE_NORMALS[face]
	var v: Vector3 = Vector3.UP
	if absf(n.y) > 0.5:
		v = Vector3.FORWARD
	var u: Vector3 = v.cross(n)
	return [u, v]


static func build() -> ArrayMesh:
	if _cache != null:
		return _cache
	var verts: PackedVector3Array = PackedVector3Array()
	var norms: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var cols: PackedColorArray = PackedColorArray()
	var tans: PackedFloat32Array = PackedFloat32Array()
	var idx: PackedInt32Array = PackedInt32Array()
	var inner: float = HALF - RADIUS

	for face: int in 6:
		var n: Vector3 = FACE_NORMALS[face]
		var axes: Array[Vector3] = face_axes(face)
		var u: Vector3 = axes[0]
		var v: Vector3 = axes[1]
		var base: int = verts.size()
		for j: int in GRID + 1:
			for i: int in GRID + 1:
				var s: float = float(i) / GRID * 2.0 - 1.0
				var t: float = float(j) / GRID * 2.0 - 1.0
				var p: Vector3 = n * HALF + u * (s * HALF) + v * (t * HALF)
				var c: Vector3 = Vector3(
					clampf(p.x, -inner, inner), clampf(p.y, -inner, inner), clampf(p.z, -inner, inner))
				var d: Vector3 = p - c
				var nn: Vector3 = d.normalized() if d.length() > 0.00001 else n
				verts.append(c + nn * RADIUS)
				norms.append(nn)
				uvs.append(Vector2(float(i) / GRID, 1.0 - float(j) / GRID))
				cols.append(Color(float(face) / 8.0, 0.0, 0.0, 1.0))
				tans.append_array([u.x, u.y, u.z, 1.0])
		for j: int in GRID:
			for i: int in GRID:
				var a: int = base + j * (GRID + 1) + i
				var b: int = a + 1
				var c2: int = a + GRID + 1
				var e: int = c2 + 1
				# clockwise seen from outside (Godot front face)
				idx.append_array([a, c2, e, a, e, b])

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TANGENT] = tans
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_cache = mesh
	return mesh

@tool
extends Node3D
class_name EnvironmentRegion

@export var sync_2d: bool = true

const PIXELS_PER_METER: float = 75
const FLOOR_GLOBAL_HEIGHT: float = 0.0
const DEBUG_WALL_HEIGHT: float = 2.0
const DEBUG_COLOR: Color = Color(0.0, 1.0, 0.4, 0.8)

var camera_3d: Camera3D
var sprite_3d: Sprite3D
var camera_2d: Camera2D
var subviewport: SubViewport

@export var BASE_FOV: float = 75.0
@export var BASE_CAMERA_Y: float = 9.0  # fixed, never changes

@export_tool_button("Update Debug View", "CollisionShape2D")
var update_debug_view = _rebuild_debug_view

func _process(_delta):
	if Engine.is_editor_hint(): return
	
	camera_2d = get_tree().get_first_node_in_group("camera_2d")
	camera_3d = get_viewport().get_camera_3d()
	subviewport = get_tree().get_first_node_in_group("sub_viewport")
	sprite_3d = get_tree().get_first_node_in_group("screen")

	if not camera_3d or not camera_2d or not sprite_3d or not subviewport or not sync_2d:
		return

	camera_3d.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	sprite_3d.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	sprite_3d.global_position.y = FLOOR_GLOBAL_HEIGHT
	sprite_3d.scale.y = 1.0

	sync_from_2d()
	
	%Label.text = "2D ZOOM: %s\n3D SPRITE POS: %s\n 2D CAM POS: %s" % [camera_2d.zoom, sprite_3d.position, camera_2d.global_position]


func sync_from_2d():
	var pan: Vector2 = camera_2d.global_position
	var zoom: float = camera_2d.zoom.x

	# No zoom division here - global_position is already in world space
	var world_x: float = pan.x / PIXELS_PER_METER
	var world_z: float = pan.y / PIXELS_PER_METER

	camera_3d.position.x = world_x
	camera_3d.position.z = world_z
	sprite_3d.position.x = world_x
	sprite_3d.position.z = world_z

	camera_3d.fov = 2.0 * rad_to_deg(atan(tan(deg_to_rad(BASE_FOV / 2.0)) / zoom))

	var world_height_meters: float = 2.0 * BASE_CAMERA_Y * tan(deg_to_rad(camera_3d.fov / 2.0))
	var world_width_meters: float = world_height_meters * (float(subviewport.size.x) / float(subviewport.size.y))
	sprite_3d.pixel_size = world_width_meters / float(subviewport.size.x)

# -----------------------------------------------------------------------
# Debug view
# -----------------------------------------------------------------------

func _rebuild_debug_view():
	subviewport = get_tree().get_first_node_in_group("sub_viewport")
	if not subviewport:
		push_error("EnvironmentRegion: no sub_viewport group node found")
		return

	# Clear previous debug container
	var existing = get_node_or_null("DebugCollisions")
	if existing:
		existing.queue_free()
		await get_tree().process_frame

	var container = Node3D.new()
	container.name = "DebugCollisions"
	add_child(container)
	container.set_owner(get_tree().edited_scene_root if Engine.is_editor_hint() else owner)

	var material = _make_debug_material()

	# Recursively find all collision shapes and polygons
	var shapes = []
	_collect_collision_nodes(subviewport, shapes)

	for node in shapes:
		if node is CollisionShape2D:
			_handle_collision_shape(node, container, material)
		elif node is CollisionPolygon2D:
			_handle_collision_polygon(node, container, material)

	print("EnvironmentRegion: debug view built with %d collision nodes" % shapes.size())

func _collect_collision_nodes(node: Node, result: Array):
	for child in node.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			result.append(child)
		_collect_collision_nodes(child, result)

func _handle_collision_shape(node: CollisionShape2D, container: Node3D, material: Material):
	var shape = node.shape
	if not shape:
		return

	var global_pos_2d: Vector2 = node.global_position
	var verts: PackedVector2Array

	if shape is RectangleShape2D:
		var half: Vector2 = shape.size / 2.0
		verts = PackedVector2Array([
			Vector2(-half.x, -half.y),
			Vector2( half.x, -half.y),
			Vector2( half.x,  half.y),
			Vector2(-half.x,  half.y),
		])
		# Rotate verts by node's rotation
		verts = _rotate_verts(verts, node.rotation)
		_spawn_box_mesh(global_pos_2d, verts, container, material)

	elif shape is CircleShape2D:
		var segments: int = 24
		var r: float = shape.radius
		for i in segments:
			var a0: float = (float(i) / segments) * TAU
			var a1: float = (float(i + 1) / segments) * TAU
			var p0 = Vector2(cos(a0), sin(a0)) * r + global_pos_2d
			var p1 = Vector2(cos(a1), sin(a1)) * r + global_pos_2d
			_spawn_wall_segment(p0, p1, container, material)

	elif shape is CapsuleShape2D:
		var r: float = shape.radius
		var h: float = shape.height / 2.0 - r
		var segments: int = 12
		# Two semicircles + two straight edges
		for i in segments:
			var a0: float = (float(i) / segments) * PI
			var a1: float = (float(i + 1) / segments) * PI
			# Top semicircle
			var p0 = Vector2(cos(a0), -sin(a0)) * r + global_pos_2d + Vector2(0, -h)
			var p1 = Vector2(cos(a1), -sin(a1)) * r + global_pos_2d + Vector2(0, -h)
			_spawn_wall_segment(p0, p1, container, material)
			# Bottom semicircle
			p0 = Vector2(cos(a0 + PI), -sin(a0 + PI)) * r + global_pos_2d + Vector2(0, h)
			p1 = Vector2(cos(a1 + PI), -sin(a1 + PI)) * r + global_pos_2d + Vector2(0, h)
			_spawn_wall_segment(p0, p1, container, material)
		# Two straight side edges
		_spawn_wall_segment(global_pos_2d + Vector2(-r, -h), global_pos_2d + Vector2(-r, h), container, material)
		_spawn_wall_segment(global_pos_2d + Vector2( r, -h), global_pos_2d + Vector2( r, h), container, material)

	elif shape is ConvexPolygonShape2D:
		var points: PackedVector2Array = _rotate_verts(shape.points, node.rotation)
		_spawn_polygon_outline(global_pos_2d, points, container, material)

	elif shape is ConcavePolygonShape2D:
		var segments_arr: PackedVector2Array = shape.segments
		for i in range(0, segments_arr.size() - 1, 2):
			var p0: Vector2 = segments_arr[i] + global_pos_2d
			var p1: Vector2 = segments_arr[i + 1] + global_pos_2d
			_spawn_wall_segment(p0, p1, container, material)

func _handle_collision_polygon(node: CollisionPolygon2D, container: Node3D, material: Material):
	if node.polygon.size() < 2:
		return
	var rotated: PackedVector2Array = _rotate_verts(node.polygon, node.rotation)
	_spawn_polygon_outline(node.global_position, rotated, container, material)

func _spawn_polygon_outline(origin: Vector2, local_verts: PackedVector2Array, container: Node3D, material: Material):
	var count: int = local_verts.size()
	for i in count:
		var p0: Vector2 = local_verts[i] + origin
		var p1: Vector2 = local_verts[(i + 1) % count] + origin
		_spawn_wall_segment(p0, p1, container, material)

func _spawn_box_mesh(origin: Vector2, local_verts: PackedVector2Array, container: Node3D, material: Material):
	_spawn_polygon_outline(origin, local_verts, container, material)

func _spawn_wall_segment(p0_2d: Vector2, p1_2d: Vector2, container: Node3D, material: Material):
	var a: Vector3 = _to_3d(p0_2d)
	var b: Vector3 = _to_3d(p1_2d)
	var top_offset := Vector3(0, DEBUG_WALL_HEIGHT, 0)

	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	# Bottom edge
	mesh.surface_add_vertex(a)
	mesh.surface_add_vertex(b)
	# Top edge
	mesh.surface_add_vertex(a + top_offset)
	mesh.surface_add_vertex(b + top_offset)
	# Verticals
	mesh.surface_add_vertex(a)
	mesh.surface_add_vertex(a + top_offset)
	mesh.surface_add_vertex(b)
	mesh.surface_add_vertex(b + top_offset)

	mesh.surface_end()

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	container.add_child(mi)
	mi.set_owner(get_tree().edited_scene_root if Engine.is_editor_hint() else owner)

func _to_3d(pos_2d: Vector2) -> Vector3:
	return Vector3(
		pos_2d.x / PIXELS_PER_METER,
		FLOOR_GLOBAL_HEIGHT,
		pos_2d.y / PIXELS_PER_METER
	)

func _rotate_verts(verts: PackedVector2Array, angle_rad: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for v in verts:
		result.append(v.rotated(angle_rad))
	return result

func _make_debug_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = DEBUG_COLOR
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.flag_no_depth_test = true
	return mat

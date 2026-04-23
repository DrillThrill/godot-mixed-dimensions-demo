@tool
extends Node3D
class_name EnvironmentRegion

const PIXELS_PER_METER: float = 75
const FLOOR_GLOBAL_HEIGHT: float = 0.0

var camera_3d: Camera3D
var sprite_3d: Sprite3D
var camera_2d: Camera2D
var subviewport: SubViewport

var base_camera_distance: float = 10.0

func _process(_delta):
	camera_2d = get_tree().get_first_node_in_group("camera_2d")
	camera_3d = get_viewport().get_camera_3d()
	subviewport = get_tree().get_first_node_in_group("sub_viewport")
	sprite_3d = get_tree().get_first_node_in_group("screen")
	
	if not camera_3d or not camera_2d or not sprite_3d or not subviewport:
		return
	
	camera_3d.rotation = Vector3(-90.0, 0.0, 0.0)
	sprite_3d.rotation = Vector3(-90.0, 0.0, 0.0)
	sprite_3d.global_position.y = FLOOR_GLOBAL_HEIGHT
	sprite_3d.scale.y = 1.0
		
	sync_from_2d()

func sync_from_2d():
	var pan: Vector2 = camera_2d.position
	var zoom: float = camera_2d.zoom.x

	var world_x: float = (pan.x / zoom) / PIXELS_PER_METER
	var world_z: float = (pan.y / zoom) / PIXELS_PER_METER

	camera_3d.position.x = world_x
	camera_3d.position.z = world_z
	sprite_3d.position.x = world_x
	sprite_3d.position.z = world_z

	var distance: float = base_camera_distance / zoom
	camera_3d.position.y = distance

	var visible_height: float = 2.0 * distance * tan(deg_to_rad(camera_3d.fov / 2.0))
	var viewport_aspect: float = float(subviewport.size.x) / float(subviewport.size.y)
	var visible_width: float = visible_height * viewport_aspect
	sprite_3d.pixel_size = visible_width / subviewport.size.x

func sync_from_3d() -> void:
	var pos: Vector3 = camera_3d.position
	var distance: float = pos.y

	if distance <= 0.0:
		return

	var zoom: float = base_camera_distance / distance

	# Sync sprite to follow camera on XZ
	sprite_3d.position.x = pos.x
	sprite_3d.position.z = pos.z

	# Convert 3D world position to 2D camera space
	camera_2d.zoom = Vector2(zoom, zoom)
	camera_2d.position.x = pos.x * PIXELS_PER_METER * zoom
	camera_2d.position.y = pos.z * PIXELS_PER_METER * zoom

	var visible_height: float = 2.0 * distance * tan(deg_to_rad(camera_3d.fov / 2.0))
	var viewport_aspect: float = float(subviewport.size.x) / float(subviewport.size.y)
	var visible_width: float = visible_height * viewport_aspect
	sprite_3d.pixel_size = visible_width / subviewport.size.x

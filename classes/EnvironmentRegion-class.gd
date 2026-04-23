extends Node3D
class_name EnvironmentRegion

const PIXELS_PER_METER: float = 75

var camera_3d: Camera3D
var sprite_3d: Sprite3D
var camera_2d: Camera2D
var subviewport: SubViewport

# Base sprite size in world units at zoom level 1.0
var base_sprite_height: float = 10.0
# Distance from camera to sprite at zoom level 1.0
var base_camera_distance: float = 10.0

func _process(_delta):
	camera_2d = get_tree().get_first_node_in_group("camera_2d")
	camera_3d = get_viewport().get_camera_3d()
	subviewport = get_tree().get_first_node_in_group("sub_viewport")
	sprite_3d = get_tree().get_first_node_in_group("screen")
	
	if camera_2d != null and camera_3d != null and subviewport != null and sprite_3d != null:
		sync_from_2d()

func sync_from_2d():
	var pan: Vector2 = camera_2d.position
	var zoom: float = camera_2d.zoom.x  # Assuming uniform zoom
	
	var world_x: float = (pan.x / zoom) / PIXELS_PER_METER
	var world_z: float = (pan.y / zoom) / PIXELS_PER_METER
	
	camera_3d.position.x = world_x
	camera_3d.position.z = world_z
	sprite_3d.position.x = world_x
	sprite_3d.position.z = world_z

	# Zoom: move camera back and scale sprite to compensate
	var distance: float = base_camera_distance / zoom
	camera_3d.position.y = distance

	# Scale sprite so it fills screen at this distance
	var visible_height: float = 2.0 * distance * tan(deg_to_rad(camera_3d.fov / 2.0))
	var viewport_aspect: float = float(subviewport.size.x) / float(subviewport.size.y)
	var visible_width: float = visible_height * viewport_aspect

	sprite_3d.pixel_size = visible_width / subviewport.size.x

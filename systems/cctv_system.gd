class_name CCTVSystem
extends Node3D

## Управляет 2 SubViewport низкого разрешения (бюджет Mobile):
## 1) CCTV (192x144) с 2 каналами (КАССА / ДВЕРЬ) и ручным обновлением UPDATE_ONCE раз в 0.1 с
## 2) Выпуклое зеркало (128x128) с ручным обновлением UPDATE_ONCE раз в 0.12 с

signal channel_changed(channel_idx: int, channel_name: String)

var cctv_viewport: SubViewport = null
var cctv_camera: Camera3D = null
var mirror_viewport: SubViewport = null
var mirror_camera: Camera3D = null

var current_channel: int = 0
var _cctv_timer: float = 0.0
var _mirror_timer: float = 0.0

const CHANNEL_NAMES: Array[String] = ["КАМ-01: КАССА", "КАМ-02: ВХОД"]
const CCTV_INTERVAL: float = 0.10
const MIRROR_INTERVAL: float = 0.12


func setup(shop: ShopBuilder) -> void:
	## 1. CCTV SubViewport 192x144
	cctv_viewport = SubViewport.new()
	cctv_viewport.name = "CCTVViewport"
	cctv_viewport.size = Vector2i(192, 144)
	cctv_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	cctv_viewport.msaa_3d = Viewport.MSAA_DISABLED
	add_child(cctv_viewport)

	cctv_camera = Camera3D.new()
	cctv_camera.cull_mask = Layers.MASK_CAM_CCTV
	cctv_camera.near = 0.1
	cctv_camera.far = 35.0
	cctv_viewport.add_child(cctv_camera)

	## 2. Mirror SubViewport 128x128
	mirror_viewport = SubViewport.new()
	mirror_viewport.name = "MirrorViewport"
	mirror_viewport.size = Vector2i(128, 128)
	mirror_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	mirror_viewport.msaa_3d = Viewport.MSAA_DISABLED
	add_child(mirror_viewport)

	mirror_camera = Camera3D.new()
	mirror_camera.cull_mask = Layers.MASK_CAM_MIRROR
	mirror_camera.fov = 95.0
	mirror_camera.near = 0.1
	mirror_camera.far = 25.0
	mirror_viewport.add_child(mirror_camera)
	mirror_camera.global_position = Vector3(-3.95, 2.35, -3.45)
	mirror_camera.look_at(Vector3(-0.3, 1.15, -0.9), Vector3.UP)

	## Назначаем текстуры на монитор и выпуклое зеркало
	if shop.cctv_screen_mesh != null:
		var scr_mat: StandardMaterial3D = StandardMaterial3D.new()
		scr_mat.albedo_texture = cctv_viewport.get_texture()
		scr_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		scr_mat.albedo_color = Color(0.84, 0.96, 0.84)
		shop.cctv_screen_mesh.material_override = scr_mat

	if shop.mirror_mesh != null:
		var mir_mat: StandardMaterial3D = StandardMaterial3D.new()
		mir_mat.albedo_texture = mirror_viewport.get_texture()
		mir_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mir_mat.albedo_color = Color(0.88, 0.90, 0.88)
		shop.mirror_mesh.material_override = mir_mat

	set_channel(0)


func refresh_upgrades() -> void:
	if cctv_camera == null:
		return
	cctv_camera.fov = 68.0 + float(SaveSystem.upg_cctv_fov) * 8.0


func toggle_channel() -> void:
	set_channel((current_channel + 1) % 2)
	SoundBank.play_sfx("ui_click", 1.1, -3.0)


func set_channel(ch: int) -> void:
	current_channel = clampi(ch, 0, 1)
	if cctv_camera == null:
		return
	refresh_upgrades()
	if current_channel == 0:
		cctv_camera.global_position = Vector3(-2.6, 2.55, -2.4)
		cctv_camera.look_at(Vector3(-0.3, 1.15, -1.0), Vector3.UP)
	else:
		cctv_camera.global_position = Vector3(2.4, 2.55, -2.5)
		cctv_camera.look_at(Vector3(0.0, 1.15, -5.2), Vector3.UP)
	channel_changed.emit(current_channel, CHANNEL_NAMES[current_channel])


func get_cctv_texture() -> ViewportTexture:
	if cctv_viewport == null:
		return null
	return cctv_viewport.get_texture()


func _process(delta: float) -> void:
	if cctv_viewport != null:
		_cctv_timer += delta
		if _cctv_timer >= CCTV_INTERVAL:
			_cctv_timer = 0.0
			cctv_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

	if mirror_viewport != null:
		_mirror_timer += delta
		if _mirror_timer >= MIRROR_INTERVAL:
			_mirror_timer = 0.0
			mirror_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

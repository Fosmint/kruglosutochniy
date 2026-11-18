class_name PlayerController
extends CharacterBody3D

## Игрок от первого лица с жёсткой защитой от провала под пол,
## плавным зумом осмотра, УФ-фонариком и эффектом покачивания камеры (head bob).

signal inspect_zone_hit(zone_id: String, zone_label: String, world_pos: Vector3)
signal autofocus_triggered()
signal flashlight_toggled(is_on: bool)

const MOVE_SPEED: float = 2.85
const GRAVITY: float = 16.0
const EYE_HEIGHT: float = 1.62
const FOV_NORMAL: float = 70.0
const FOV_ZOOM: float = 35.0

var camera: Camera3D = null
var uv_light: SpotLight3D = null
var flashlight_on: bool = false

var _yaw: float = 0.0
var _pitch: float = 0.0
var _move_input: Vector2 = Vector2.ZERO
var _bob_time: float = 0.0
var _step_accum: float = 0.0
var _footstep_audio: AudioStreamPlayer3D = null

## Защита от провала под пол
var _spawn_freeze_timer: float = 0.5
var _last_safe_pos: Vector3 = Vector3(-0.3, 0.3, 1.0)

## Осмотр и зум
var _is_zoomed: bool = false
var _zoom_target_world: Vector3 = Vector3.ZERO
var _target_fov: float = FOV_NORMAL
var _last_focus_id: String = ""


func _ready() -> void:
	collision_layer = Layers.PHYS_PLAYER
	collision_mask = Layers.PHYS_WORLD
	safe_margin = 0.01
	floor_snap_length = 0.4

	var cs: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.72
	cs.shape = cap
	cs.position = Vector3(0.0, 0.86, 0.0)
	add_child(cs)

	camera = Camera3D.new()
	camera.position = Vector3(0.0, EYE_HEIGHT, 0.0)
	camera.fov = FOV_NORMAL
	camera.near = 0.06
	camera.far = 55.0
	camera.cull_mask = Layers.MASK_CAM_MAIN
	add_child(camera)

	uv_light = SpotLight3D.new()
	uv_light.position = Vector3(0.14, -0.10, -0.18)
	uv_light.light_color = Color(0.56, 0.48, 1.0)
	uv_light.spot_angle = 30.0
	uv_light.shadow_enabled = false
	uv_light.visible = false
	camera.add_child(uv_light)
	refresh_upgrades()

	_footstep_audio = AudioStreamPlayer3D.new()
	_footstep_audio.bus = "SFX"
	_footstep_audio.volume_db = -10.0
	_footstep_audio.stream = SoundBank.get_stream("footstep")
	add_child(_footstep_audio)

	reset_to_spawn(ShopBuilder.SPAWN_PLAYER_POS)


func reset_to_spawn(pos: Vector3) -> void:
	global_position = pos
	_last_safe_pos = pos
	velocity = Vector3.ZERO
	_yaw = 0.0
	_pitch = 0.0
	rotation.y = 0.0
	if camera != null:
		camera.rotation.x = 0.0
	_spawn_freeze_timer = 0.5
	clear_zoom()


func refresh_upgrades() -> void:
	if uv_light == null:
		return
	var lvl: int = SaveSystem.upg_flashlight
	uv_light.light_energy = 3.2 + float(lvl) * 1.1
	uv_light.spot_range = 7.5 + float(lvl) * 2.2
	uv_light.spot_angle = 28.0 + float(lvl) * 5.0


func set_move_input(vec: Vector2) -> void:
	_move_input = vec


func add_look_delta(delta_px: Vector2) -> void:
	if GameState.phase != GameState.PHASE_PLAYING:
		return
	if _is_zoomed:
		clear_zoom()
	var sens: float = SaveSystem.look_sensitivity
	_yaw -= delta_px.x * sens
	_pitch = clampf(_pitch - delta_px.y * sens, -1.18, 1.15)
	rotation.y = _yaw
	if camera != null:
		camera.rotation.x = _pitch


func toggle_flashlight() -> void:
	flashlight_on = not flashlight_on
	if uv_light != null:
		uv_light.visible = flashlight_on
	SoundBank.play_sfx("ui_click", 1.25 if flashlight_on else 0.85, -3.0)
	flashlight_toggled.emit(flashlight_on)


func set_zoom_target(world_pos: Vector3, focus_id: String) -> void:
	_is_zoomed = true
	_zoom_target_world = world_pos
	_target_fov = FOV_ZOOM
	if focus_id != _last_focus_id:
		_last_focus_id = focus_id
		autofocus_triggered.emit()


func clear_zoom() -> void:
	if _is_zoomed:
		_is_zoomed = false
		_target_fov = FOV_NORMAL
		_last_focus_id = ""
		autofocus_triggered.emit()


func inspect_at_screen_pos(screen_pos: Vector2) -> Dictionary:
	if camera == null:
		return {}
	var from_pt: Vector3 = camera.project_ray_origin(screen_pos)
	var dir: Vector3 = camera.project_ray_normal(screen_pos)
	var to_pt: Vector3 = from_pt + dir * 7.5
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from_pt, to_pt, Layers.PHYS_INTERACT)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		clear_zoom()
		return {}
	var col_obj: Object = hit.get("collider", null)
	if col_obj == null or not (col_obj is Node):
		clear_zoom()
		return {}
	var node: Node = col_obj as Node
	var zid: String = str(node.get_meta("interact_id", ""))
	var zlabel: String = str(node.get_meta("interact_label", ""))
	var hpos: Vector3 = hit.get("position", Vector3.ZERO)
	if zid == "face" or zid == "hands" or zid == "legs":
		set_zoom_target(hpos, zid)
	inspect_zone_hit.emit(zid, zlabel, hpos)
	return {"id": zid, "label": zlabel, "pos": hpos}


func _physics_process(raw_delta: float) -> void:
	var delta: float = minf(raw_delta, 1.0 / 20.0)

	## Заморозка движения первые 0.5 с после спавна
	if _spawn_freeze_timer > 0.0:
		_spawn_freeze_timer -= delta
		velocity = Vector3.ZERO
		return

	if GameState.phase != GameState.PHASE_PLAYING:
		velocity = Vector3.ZERO
		return

	## Гравитация
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
		if global_position.y > -0.5:
			_last_safe_pos = global_position

	## Горизонтальное перемещение
	var input_len: float = _move_input.length()
	if input_len > 0.08:
		if _is_zoomed:
			clear_zoom()
		var forward: Vector3 = -global_transform.basis.z
		var right: Vector3 = global_transform.basis.x
		var move_dir: Vector3 = (right * _move_input.x - forward * _move_input.y).normalized()
		velocity.x = move_dir.x * MOVE_SPEED * clampf(input_len, 0.0, 1.0)
		velocity.z = move_dir.z * MOVE_SPEED * clampf(input_len, 0.0, 1.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)

	move_and_slide()

	## Failsafe: если игрок всё же провалился ниже y = -2.0 -> телепорт
	if global_position.y < -2.0:
		global_position = _last_safe_pos + Vector3(0.0, 0.3, 0.0)
		velocity = Vector3.ZERO

	_update_camera_and_bob(delta)


func _update_camera_and_bob(delta: float) -> void:
	if camera == null:
		return
	camera.fov = lerpf(camera.fov, _target_fov, clampf(delta * 8.0, 0.0, 1.0))

	var horiz_speed: float = Vector2(velocity.x, velocity.z).length()
	if horiz_speed > 0.25 and is_on_floor():
		_bob_time += delta * 8.2
		_step_accum += delta * horiz_speed
		if _step_accum >= 1.35:
			_step_accum = 0.0
			if _footstep_audio != null and _footstep_audio.stream != null:
				_footstep_audio.pitch_scale = randf_range(0.88, 1.12)
				_footstep_audio.play()
		camera.position.y = EYE_HEIGHT + sin(_bob_time) * 0.032
		camera.position.x = cos(_bob_time * 0.5) * 0.018
	else:
		_bob_time += delta * 1.4
		camera.position.y = lerpf(camera.position.y, EYE_HEIGHT + sin(_bob_time) * 0.008, delta * 5.0)
		camera.position.x = lerpf(camera.position.x, 0.0, delta * 5.0)

	if _is_zoomed:
		var look_dir: Vector3 = (_zoom_target_world - camera.global_position).normalized()
		if look_dir.length_squared() > 0.001:
			var target_yaw: float = atan2(-look_dir.x, -look_dir.z)
			var target_pitch: float = asin(clampf(look_dir.y, -0.95, 0.95))
			_yaw = lerp_angle(_yaw, target_yaw, clampf(delta * 7.0, 0.0, 1.0))
			_pitch = lerpf(_pitch, target_pitch, clampf(delta * 7.0, 0.0, 1.0))
			rotation.y = _yaw
			camera.rotation.x = _pitch

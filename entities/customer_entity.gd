class_name CustomerEntity
extends Node3D

## 3D-покупатель из примитивов + процедурное лицо + 5/6 пальцев + зоны осмотра + речь и анимация.

const STATE_ENTERING: int = 0
const STATE_AT_COUNTER: int = 1
const STATE_LEAVING: int = 2
const STATE_AGGRESSIVE: int = 3
const STATE_DISSOLVING: int = 4

signal arrived_at_counter(customer: CustomerEntity)
signal exited_shop(customer: CustomerEntity)
signal speech_updated(speaker: String, text: String)

var appearance: CustomerAppearance = null
var basket: Array[Dictionary] = []
var greeting_text: String = ""
var state: int = STATE_ENTERING
var needs_id_check: bool = false
var uses_large_bill: bool = false

var _visual_root: Node3D = null
var _torso_node: Node3D = null
var _head_node: Node3D = null
var _arm_l: Node3D = null
var _arm_r: Node3D = null
var _leg_l: Node3D = null
var _leg_r: Node3D = null
var _face_mat: StandardMaterial3D = null
var _tex_face_normal: ImageTexture = null
var _tex_face_uv: ImageTexture = null
var _shadow_mesh: MeshInstance3D = null
var _doppelganger_node: Node3D = null
var _footstep_audio: AudioStreamPlayer3D = null

var _anim_t: float = 0.0
var _step_t: float = 0.0
var _target_pos: Vector3 = Vector3.ZERO
var _dissolve_timer: float = 0.0
var _player_ref: Node3D = null
var _uv_lit: bool = false

## Речь и бормотание
var _speech_active: bool = false
var _speech_chars: int = 0
var _speech_timer: float = 0.0
var _desync_blip_timer: float = 0.0


func setup(p_appearance: CustomerAppearance, p_basket: Array[Dictionary], p_greeting: String, player_node: Node3D) -> void:
	appearance = p_appearance
	basket = p_basket
	greeting_text = p_greeting
	_player_ref = player_node

	for item: Dictionary in basket:
		if bool(item.get("needs_id", false)):
			needs_id_check = true
	uses_large_bill = appearance.strange_payment or (appearance.seed_val % 3 == 0 and GameState.current_night >= 3)

	_build_body()
	_build_inspect_zones()
	_build_audio()

	global_position = ShopBuilder.DOOR_ENTRY_POS
	_target_pos = ShopBuilder.COUNTER_STAND_POS
	state = STATE_ENTERING


func set_uv_illuminated(is_on: bool) -> void:
	if _uv_lit == is_on:
		return
	_uv_lit = is_on
	if _face_mat != null:
		_face_mat.albedo_texture = _tex_face_uv if (_uv_lit and _tex_face_uv != null) else _tex_face_normal
		if _uv_lit and appearance != null and appearance.is_anomaly and appearance.anomaly_id == "uv_pupils":
			_face_mat.emission_enabled = true
			_face_mat.emission_texture = _tex_face_uv
			_face_mat.emission_energy_multiplier = 1.6
		else:
			_face_mat.emission_enabled = false


func command_leave(dissolve_in_static: bool = false) -> void:
	if dissolve_in_static:
		state = STATE_DISSOLVING
		_dissolve_timer = 0.85
		SoundBank.play_sfx("static_burst", 1.0, -2.0)
	else:
		state = STATE_LEAVING
		_target_pos = ShopBuilder.DOOR_ENTRY_POS


func start_aggressive_mode() -> void:
	state = STATE_AGGRESSIVE
	var line: String = DialogueDB.AGGRESSIVE_LINES[appearance.seed_val % DialogueDB.AGGRESSIVE_LINES.size()]
	start_speaking(line)
	SoundBank.play_sfx("whisper", 0.75, 1.0)


func start_speaking(line: String) -> void:
	greeting_text = line
	_speech_active = true
	_speech_chars = 0
	_speech_timer = 0.0
	_desync_blip_timer = 0.25
	speech_updated.emit("ПОКУПАТЕЛЬ", "")


func _build_body() -> void:
	_visual_root = Node3D.new()
	add_child(_visual_root)

	var vis_layer: int = Layers.VIS_ALL
	if not appearance.visible_in_mirror_cctv or appearance.has_doppelganger:
		vis_layer = Layers.VIS_MAIN_ONLY

	var cloth_mat: StandardMaterial3D = MaterialLibrary.get_clothing_mat(appearance.seed_val, appearance.cloth_color, appearance.cloth_pattern, appearance.is_wet)
	var pants_mat: StandardMaterial3D = MaterialLibrary.get_flat_mat("pants_" + str(appearance.seed_val % 5), appearance.pants_color, 0.35 if appearance.is_wet else 0.88)
	var skin_mat: StandardMaterial3D = MaterialLibrary.get_flat_mat("skin_" + appearance.skin_color.to_html(false), appearance.skin_color, 0.78)

	## Ноги
	_leg_l = _make_limb(Vector3(-0.13, 0.45, 0.0), 0.095, 0.86, pants_mat, vis_layer)
	_leg_r = _make_limb(Vector3(0.13, 0.45, 0.0), 0.095, 0.86, pants_mat, vis_layer)
	_visual_root.add_child(_leg_l)
	_visual_root.add_child(_leg_r)

	## Туловище
	_torso_node = Node3D.new()
	_torso_node.position = Vector3(0.0, 1.18, 0.0)
	var torso_mesh: MeshInstance3D = MeshInstance3D.new()
	var tm: CapsuleMesh = CapsuleMesh.new()
	tm.radius = 0.24 if appearance.weirdo_id != "dino_suit" else 0.34
	tm.height = 0.72
	torso_mesh.mesh = tm
	torso_mesh.material_override = cloth_mat
	torso_mesh.layers = vis_layer
	_torso_node.add_child(torso_mesh)
	_visual_root.add_child(_torso_node)

	## Шарф
	if appearance.has_scarf:
		var scarf: MeshInstance3D = MeshInstance3D.new()
		var sm: CylinderMesh = CylinderMesh.new()
		sm.top_radius = 0.16
		sm.bottom_radius = 0.18
		sm.height = 0.12
		scarf.mesh = sm
		scarf.position = Vector3(0.0, 0.32, 0.0)
		scarf.material_override = MaterialLibrary.get_flat_mat("scarf_red", Color(0.62, 0.16, 0.16), 0.9)
		scarf.layers = vis_layer
		_torso_node.add_child(scarf)

	## Руки + кисти с 5 или 6 отдельными пальцами
	_arm_l = _make_arm_with_hand(Vector3(-0.31, 1.38, 0.06), cloth_mat, skin_mat, vis_layer)
	_arm_r = _make_arm_with_hand(Vector3(0.31, 1.38, 0.06), cloth_mat, skin_mat, vis_layer)
	_visual_root.add_child(_arm_l)
	_visual_root.add_child(_arm_r)

	## Голова
	_head_node = Node3D.new()
	_head_node.position = Vector3(0.0, 1.66, 0.0)
	var head_mesh: MeshInstance3D = MeshInstance3D.new()
	var hm: SphereMesh = SphereMesh.new()
	hm.radius = 0.17
	hm.height = 0.36
	head_mesh.mesh = hm
	head_mesh.material_override = skin_mat
	head_mesh.layers = vis_layer
	_head_node.add_child(head_mesh)

	## Face plate (перед головой, предсказуемый UV)
	_tex_face_normal = FaceGenerator.generate_face_texture(appearance.get_face_params(false, false))
	_tex_face_uv = FaceGenerator.generate_face_texture(appearance.get_face_params(true, false))
	_face_mat = StandardMaterial3D.new()
	_face_mat.albedo_texture = _tex_face_normal
	_face_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_face_mat.roughness = 0.72
	var face_plate: MeshInstance3D = MeshInstance3D.new()
	var fq: QuadMesh = QuadMesh.new()
	fq.size = Vector2(0.28, 0.31)
	face_plate.mesh = fq
	face_plate.position = Vector3(0.0, 0.0, 0.168)
	face_plate.material_override = _face_mat
	face_plate.layers = vis_layer
	_head_node.add_child(face_plate)

	## Волосы / аксессуары / образ чудака
	_build_head_extras(vis_layer)
	_visual_root.add_child(_head_node)

	## Масштаб роста (если слишком высокий — пригибается под потолком)
	_visual_root.scale = Vector3(1.0, appearance.height_scale, 1.0)
	if appearance.crouch_under_ceiling:
		_head_node.rotation_degrees.x = 24.0
		_torso_node.rotation_degrees.x = 14.0

	## Blob-тень под ногами (у аномалии no_shadow отсутствует)
	if appearance.has_shadow:
		_shadow_mesh = MeshInstance3D.new()
		var sqm: QuadMesh = QuadMesh.new()
		sqm.size = Vector2(0.85, 0.85)
		_shadow_mesh.mesh = sqm
		_shadow_mesh.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		_shadow_mesh.position = Vector3(0.0, 0.015, 0.0)
		_shadow_mesh.material_override = MaterialLibrary.get_shadow_blob_mat()
		_shadow_mesh.layers = vis_layer
		add_child(_shadow_mesh)

	## Двойник на камере CCTV (виден только на Layers.VIS_CCTV_ONLY)
	if appearance.has_doppelganger:
		_doppelganger_node = Node3D.new()
		var d_body: MeshInstance3D = MeshInstance3D.new()
		var dcm: CapsuleMesh = CapsuleMesh.new()
		dcm.radius = 0.32
		dcm.height = 2.25
		d_body.mesh = dcm
		d_body.position = Vector3(0.0, 1.15, 0.0)
		d_body.material_override = MaterialLibrary.get_shadow_doppelganger_mat()
		d_body.layers = Layers.VIS_CCTV_ONLY
		_doppelganger_node.add_child(d_body)
		add_child(_doppelganger_node)


func _make_limb(pos: Vector3, radius: float, height: float, mat: Material, vis_layer: int) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.position = pos
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius * 0.88
	cm.height = height
	mi.mesh = cm
	mi.material_override = mat
	mi.layers = vis_layer
	pivot.add_child(mi)
	return pivot


func _make_arm_with_hand(pos: Vector3, cloth_mat: Material, skin_mat: Material, vis_layer: int) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.position = pos
	var sleeve: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.075
	cm.bottom_radius = 0.065
	cm.height = 0.52
	sleeve.mesh = cm
	sleeve.position = Vector3(0.0, -0.22, 0.14)
	sleeve.rotation_degrees = Vector3(-40.0, 0.0, 0.0)
	sleeve.material_override = cloth_mat
	sleeve.layers = vis_layer
	pivot.add_child(sleeve)

	## Кисть вытянута вперёд над прилавком, чтобы игрок мог посчитать пальцы
	var hand: Node3D = Node3D.new()
	hand.position = Vector3(0.0, -0.38, 0.34)
	var palm: MeshInstance3D = MeshInstance3D.new()
	var pm: BoxMesh = BoxMesh.new()
	pm.size = Vector3(0.09, 0.035, 0.09)
	palm.mesh = pm
	palm.material_override = skin_mat
	palm.layers = vis_layer
	hand.add_child(palm)

	var f_count: int = appearance.finger_count
	var f_len: float = 0.14 if appearance.long_fingers else 0.072
	for i in range(f_count):
		var finger: MeshInstance3D = MeshInstance3D.new()
		var fm: BoxMesh = BoxMesh.new()
		fm.size = Vector3(0.013, 0.016, f_len)
		finger.mesh = fm
		var spread: float = (float(i) - float(f_count - 1) * 0.5) * 0.020
		finger.position = Vector3(spread, 0.0, 0.045 + f_len * 0.5)
		finger.material_override = skin_mat
		finger.layers = vis_layer
		hand.add_child(finger)

	pivot.add_child(hand)
	return pivot


func _build_head_extras(vis_layer: int) -> void:
	## Волосы
	var hair: MeshInstance3D = MeshInstance3D.new()
	var hbm: SphereMesh = SphereMesh.new()
	hbm.radius = 0.178
	hbm.height = 0.24
	hair.mesh = hbm
	hair.position = Vector3(0.0, 0.07, -0.02)
	hair.material_override = MaterialLibrary.get_hair_mat(appearance.hair_color)
	hair.layers = vis_layer
	_head_node.add_child(hair)

	if appearance.has_cap:
		var cap: MeshInstance3D = MeshInstance3D.new()
		var cpm: BoxMesh = BoxMesh.new()
		cpm.size = Vector3(0.28, 0.06, 0.34)
		cap.mesh = cpm
		cap.position = Vector3(0.0, 0.15, 0.06)
		cap.material_override = MaterialLibrary.get_flat_mat("cap_dark", Color(0.16, 0.20, 0.26), 0.85)
		cap.layers = vis_layer
		_head_node.add_child(cap)

	if appearance.has_glasses:
		var gl: MeshInstance3D = MeshInstance3D.new()
		var gm: BoxMesh = BoxMesh.new()
		gm.size = Vector3(0.24, 0.055, 0.03)
		gl.mesh = gm
		gl.position = Vector3(0.0, 0.02, 0.185)
		gl.material_override = MaterialLibrary.get_flat_mat("glasses", Color(0.10, 0.10, 0.12), 0.2)
		gl.layers = vis_layer
		_head_node.add_child(gl)

	if appearance.weirdo_id == "dino_suit":
		var snout: MeshInstance3D = MeshInstance3D.new()
		var snm: BoxMesh = BoxMesh.new()
		snm.size = Vector3(0.24, 0.22, 0.26)
		snout.mesh = snm
		snout.position = Vector3(0.0, 0.19, 0.12)
		snout.material_override = MaterialLibrary.get_flat_mat("dino_green", Color(0.20, 0.64, 0.24), 0.7)
		snout.layers = vis_layer
		_head_node.add_child(snout)
	elif appearance.weirdo_id == "babushka_curlers":
		for cx: float in [-0.15, 0.0, 0.15]:
			var curler: MeshInstance3D = MeshInstance3D.new()
			var clm: CylinderMesh = CylinderMesh.new()
			clm.top_radius = 0.035
			clm.bottom_radius = 0.035
			clm.height = 0.09
			curler.mesh = clm
			curler.rotation_degrees = Vector3(0.0, 0.0, 90.0)
			curler.position = Vector3(cx, 0.17, 0.08)
			curler.material_override = MaterialLibrary.get_flat_mat("curler_pink", Color(0.88, 0.44, 0.65), 0.6)
			curler.layers = vis_layer
			_head_node.add_child(curler)


func _build_inspect_zones() -> void:
	var h: float = appearance.height_scale
	_add_zone("face", "ЗОНА: ЛИЦО / ГЛАЗА", Vector3(0.0, 1.66 * h, 0.08), Vector3(0.42, 0.42, 0.42))
	_add_zone("hands", "ЗОНА: РУКИ / ПАЛЬЦЫ", Vector3(0.0, 1.02 * h, 0.38), Vector3(0.85, 0.36, 0.42))
	_add_zone("legs", "ЗОНА: НОГИ / ТЕНЬ", Vector3(0.0, 0.35, 0.0), Vector3(0.75, 0.72, 0.75))


func _add_zone(zid: String, zlabel: String, pos: Vector3, sz: Vector3) -> void:
	var area: Area3D = Area3D.new()
	area.position = pos
	area.collision_layer = Layers.PHYS_INTERACT
	area.collision_mask = 0
	area.set_meta("interact_id", zid)
	area.set_meta("interact_label", zlabel)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = sz
	cs.shape = bs
	area.add_child(cs)
	add_child(area)


func _build_audio() -> void:
	_footstep_audio = AudioStreamPlayer3D.new()
	_footstep_audio.bus = "SFX"
	_footstep_audio.volume_db = -8.0
	_footstep_audio.stream = SoundBank.get_stream("footstep")
	add_child(_footstep_audio)


func _process(delta: float) -> void:
	_anim_t += delta
	_update_speech(delta)

	if state == STATE_ENTERING or state == STATE_LEAVING:
		var dir: Vector3 = _target_pos - global_position
		dir.y = 0.0
		var dist: float = dir.length()
		if dist > 0.08:
			var speed: float = 1.65
			global_position += dir.normalized() * minf(dist, speed * delta)
			rotation.y = atan2(dir.x, dir.z)
			## Качание конечностей при ходьбе
			var swing: float = sin(_anim_t * 7.5) * 0.42
			if _leg_l != null:
				_leg_l.rotation.x = swing
			if _leg_r != null:
				_leg_r.rotation.x = -swing
			_step_t += delta
			if _step_t >= 0.44:
				_step_t = 0.0
				if _footstep_audio != null and _footstep_audio.stream != null:
					_footstep_audio.pitch_scale = randf_range(0.85, 1.1)
					_footstep_audio.play()
		else:
			if _leg_l != null:
				_leg_l.rotation.x = 0.0
			if _leg_r != null:
				_leg_r.rotation.x = 0.0
			if state == STATE_ENTERING:
				state = STATE_AT_COUNTER
				rotation_degrees.y = 0.0
				start_speaking(greeting_text)
				arrived_at_counter.emit(self)
			else:
				exited_shop.emit(self)
				queue_free()
	elif state == STATE_AT_COUNTER or state == STATE_AGGRESSIVE:
		_animate_idle(delta)
	elif state == STATE_DISSOLVING:
		_dissolve_timer -= delta
		visible = (int(Time.get_ticks_msec() / 55) % 2 == 0)
		if _dissolve_timer <= 0.0:
			exited_shop.emit(self)
			queue_free()


func _animate_idle(_delta: float) -> void:
	## Дыхание грудной клетки (у аномалии no_breathing грудь полностью неподвижна)
	if _torso_node != null:
		if appearance.breathes:
			var breath: float = sin(_anim_t * 2.4) * 0.032
			_torso_node.scale = Vector3(1.0 + breath, 1.0 + breath * 0.6, 1.0 + breath)
		else:
			_torso_node.scale = Vector3.ONE

	## Пьяный слегка покачивается
	if appearance.weirdo_id == "drunk" and _visual_root != null:
		_visual_root.rotation.z = sin(_anim_t * 1.9) * 0.06

	## Поворот головы: аномалии смотрят строго в камеру игрока, нормальные слегка оглядываются
	if _head_node != null:
		if appearance.is_anomaly and _player_ref != null:
			var to_p: Vector3 = _player_ref.global_position - _head_node.global_position
			var target_y: float = atan2(to_p.x, to_p.z) - rotation.y
			_head_node.rotation.y = clampf(target_y, -0.75, 0.75)
			## Микро-подёргивание аномалий
			if int(_anim_t * 10.0) % 29 == 0:
				_head_node.rotation.z = 0.14
			else:
				_head_node.rotation.z = 0.0
		else:
			_head_node.rotation.y = sin(_anim_t * 0.85) * 0.18
			_head_node.rotation.z = 0.0

	if state == STATE_AGGRESSIVE:
		## Приближается вплотную к прилавку и трясётся
		position.z = lerpf(position.z, -0.92, 0.04)
		position.x = ShopBuilder.COUNTER_STAND_POS.x + sin(_anim_t * 35.0) * 0.025


func _update_speech(delta: float) -> void:
	if not _speech_active:
		return
	_speech_timer += delta
	if _speech_timer >= 0.045:
		_speech_timer = 0.0
		_speech_chars += 1
		if _speech_chars <= greeting_text.length():
			speech_updated.emit("ПОКУПАТЕЛЬ", greeting_text.substr(0, _speech_chars))
			## Нормальная синхронная речь: блип на каждые 3 символа
			if not appearance.desync_speech and _speech_chars % 3 == 1:
				SoundBank.play_voice_blip(appearance.voice_pitch + randf_range(-0.08, 0.08), -5.0)
		else:
			if not appearance.desync_speech:
				_speech_active = false
	## Рассинхрон речи: блипы звучат с задержкой и даже после конца субтитров
	if appearance.desync_speech:
		_desync_blip_timer -= delta
		if _desync_blip_timer <= 0.0:
			SoundBank.play_voice_blip(appearance.voice_pitch * randf_range(0.6, 1.4), -4.0)
			_desync_blip_timer = randf_range(0.18, 0.55)
			if _speech_chars > greeting_text.length() + 18:
				_speech_active = false

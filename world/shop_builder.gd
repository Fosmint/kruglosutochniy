class_name ShopBuilder
extends Node3D

## Строит 3D-магазин процедурно с защитой от провала под пол и оптимизацией под Mobile

var cctv_screen_mesh: MeshInstance3D = null
var mirror_mesh: MeshInstance3D = null
var rain_glass_mat: ShaderMaterial = null
var main_light: OmniLight3D = null
var backroom_light: OmniLight3D = null
var tube_mats: Array[StandardMaterial3D] = []
var car_headlights: Node3D = null
var hallucination_mesh: MeshInstance3D = null

var doorbell_audio: AudioStreamPlayer3D = null
var _ambient_hum: AudioStreamPlayer3D = null
var _fridge_hum: AudioStreamPlayer3D = null
var _road_audio: AudioStreamPlayer3D = null
var _vhs_hiss: AudioStreamPlayer = null
var _tension_drone: AudioStreamPlayer = null
var _heartbeat_player: AudioStreamPlayer = null

var _flicker_timer: float = 0.0
var _car_timer: float = 6.0
var _car_x: float = -18.0
var _car_active: bool = false
var _lights_forced_off: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

const SPAWN_PLAYER_POS: Vector3 = Vector3(-0.3, 0.3, 1.0)
const DOOR_ENTRY_POS: Vector3 = Vector3(0.0, 0.0, -5.0)
const COUNTER_STAND_POS: Vector3 = Vector3(-0.3, 0.0, -1.25)


func _ready() -> void:
	_rng.randomize()
	_build_environment()
	_build_safety_floor()
	_build_room_shell()
	_build_counter_area()
	_build_shelves_and_props()
	_build_backroom()
	_build_street_outside()
	_build_lighting()
	_build_hallucination_prop()
	_build_audio()

	GameState.power_state_changed.connect(_on_power_changed)
	GameState.weather_changed.connect(_on_weather_changed)
	_on_weather_changed(GameState.weather)


func _process(delta: float) -> void:
	_update_lights_flicker(delta)
	_update_passing_car(delta)
	_update_sanity_audio_and_hallucinations()


func set_temporary_lights_off(off: bool) -> void:
	_lights_forced_off = off
	_apply_light_state()


func ring_doorbell() -> void:
	if doorbell_audio != null and doorbell_audio.stream != null:
		doorbell_audio.play()


func _build_environment() -> void:
	var we: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.025, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.14, 0.16, 0.15)
	env.ambient_light_energy = 0.65
	env.fog_enabled = true
	env.fog_light_color = Color(0.04, 0.05, 0.06)
	env.fog_density = 0.045
	## Без SSAO, SSR и volumetric fog (Mobile renderer)
	we.environment = env
	add_child(we)


func _build_safety_floor() -> void:
	## Страховочный пол под всей картой на y = -3.0
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "SafetyFloor"
	body.collision_layer = Layers.PHYS_WORLD
	body.collision_mask = 0
	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: WorldBoundaryShape3D = WorldBoundaryShape3D.new()
	shape.plane = Plane(Vector3.UP, 0.0)
	col.shape = shape
	body.position = Vector3(0.0, -3.0, 0.0)
	body.add_child(col)
	add_child(body)


func _build_room_shell() -> void:
	## Пол: визуально тонкий (0.1м), коллайдер толстый 2.0м (верх на y=0.0)
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.name = "ShopFloor"
	floor_body.collision_layer = Layers.PHYS_WORLD
	floor_body.collision_mask = 0
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var fm: BoxMesh = BoxMesh.new()
	fm.size = Vector3(9.4, 0.1, 10.6)
	floor_mesh.mesh = fm
	floor_mesh.position = Vector3(0.0, -0.05, -0.5)
	floor_mesh.material_override = MaterialLibrary.get_triplanar_mat("floor_tile", Color(0.32, 0.34, 0.31), 0.78)
	floor_mesh.layers = Layers.VIS_ALL
	floor_body.add_child(floor_mesh)

	var floor_col: CollisionShape3D = CollisionShape3D.new()
	var fc_shape: BoxShape3D = BoxShape3D.new()
	fc_shape.size = Vector3(12.0, 2.0, 14.0)
	floor_col.shape = fc_shape
	floor_col.position = Vector3(0.0, -1.0, -0.5)
	floor_body.add_child(floor_col)
	add_child(floor_body)

	## Потолок (y = 3.0)
	var ceil_mesh: MeshInstance3D = MeshInstance3D.new()
	var cm: BoxMesh = BoxMesh.new()
	cm.size = Vector3(9.4, 0.15, 10.6)
	ceil_mesh.mesh = cm
	ceil_mesh.position = Vector3(0.0, 3.07, -0.5)
	ceil_mesh.material_override = MaterialLibrary.get_triplanar_mat("ceiling", Color(0.28, 0.30, 0.27), 0.92)
	add_child(ceil_mesh)

	## Толстые стены (коллайдер >= 1.2 м)
	var wall_mat: StandardMaterial3D = MaterialLibrary.get_triplanar_mat("wall_paint", Color(0.42, 0.45, 0.39), 0.90)
	_add_solid_wall("WallLeft", Vector3(-4.5, 1.5, -0.5), Vector3(0.2, 3.0, 10.6), Vector3(-5.1, 1.5, -0.5), Vector3(1.2, 3.4, 11.4), wall_mat)
	_add_solid_wall("WallRight", Vector3(4.5, 1.5, -0.5), Vector3(0.2, 3.0, 10.6), Vector3(5.1, 1.5, -0.5), Vector3(1.2, 3.4, 11.4), wall_mat)
	_add_solid_wall("WallBack", Vector3(0.0, 1.5, 4.7), Vector3(9.2, 3.0, 0.2), Vector3(0.0, 1.5, 5.3), Vector3(10.0, 3.4, 1.2), wall_mat)

	## Передняя стена со стеклянной дверью (z = -5.7)
	_add_solid_wall("WallFrontLeft", Vector3(-3.0, 1.5, -5.7), Vector3(3.2, 3.0, 0.2), Vector3(-3.0, 1.5, -6.3), Vector3(3.2, 3.4, 1.2), wall_mat)
	_add_solid_wall("WallFrontRight", Vector3(3.0, 1.5, -5.7), Vector3(3.2, 3.0, 0.2), Vector3(3.0, 1.5, -6.3), Vector3(3.2, 3.4, 1.2), wall_mat)

	## Невидимый коллайдер на стекле, чтобы игрок не выходил наружу
	var glass_col_body: StaticBody3D = StaticBody3D.new()
	glass_col_body.collision_layer = Layers.PHYS_WORLD
	glass_col_body.collision_mask = 0
	var gcol: CollisionShape3D = CollisionShape3D.new()
	var gshape: BoxShape3D = BoxShape3D.new()
	gshape.size = Vector3(3.0, 3.2, 1.0)
	gcol.shape = gshape
	gcol.position = Vector3(0.0, 1.5, -6.2)
	glass_col_body.add_child(gcol)
	add_child(glass_col_body)

	## Стеклянная дверь с шейдером дождя
	var glass_mesh: MeshInstance3D = MeshInstance3D.new()
	var gm: QuadMesh = QuadMesh.new()
	gm.size = Vector2(2.8, 2.7)
	glass_mesh.mesh = gm
	glass_mesh.position = Vector3(0.0, 1.35, -5.65)
	var sh: Shader = load("res://shaders/rain_glass.gdshader") as Shader
	rain_glass_mat = ShaderMaterial.new()
	rain_glass_mat.shader = sh
	rain_glass_mat.set_shader_parameter("rain_amount", 0.0)
	glass_mesh.material_override = rain_glass_mat
	add_child(glass_mesh)

	## Перегородка подсобки (z = 2.0, проход справа x = 1.6..3.6)
	_add_solid_wall("BackroomDivider", Vector3(-1.5, 1.5, 2.1), Vector3(6.0, 3.0, 0.18), Vector3(-1.5, 1.5, 2.1), Vector3(6.0, 3.0, 0.5), wall_mat)


func _add_solid_wall(wname: String, vis_pos: Vector3, vis_size: Vector3, col_pos: Vector3, col_size: Vector3, mat: Material) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = wname
	body.collision_layer = Layers.PHYS_WORLD
	body.collision_mask = 0
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = vis_size
	mi.mesh = bm
	mi.position = vis_pos
	mi.material_override = mat
	body.add_child(mi)

	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = col_size
	cs.shape = bs
	cs.position = col_pos
	body.add_child(cs)
	add_child(body)


func _build_counter_area() -> void:
	var counter_mat: StandardMaterial3D = MaterialLibrary.get_triplanar_mat("counter_wood", Color(0.30, 0.23, 0.18), 0.75)
	_add_solid_wall("CounterMain", Vector3(-0.4, 0.48, -0.2), Vector3(3.6, 0.96, 0.85), Vector3(-0.4, 0.48, -0.2), Vector3(3.6, 0.96, 0.95), counter_mat)

	## Лента транспортёра
	var belt: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(1.4, 0.04, 0.52)
	belt.mesh = bm
	belt.position = Vector3(-0.9, 0.98, -0.2)
	belt.material_override = MaterialLibrary.get_flat_mat("belt_rubber", Color(0.10, 0.10, 0.11), 0.9)
	add_child(belt)

	## Красная полоса сканера
	var scan_line: MeshInstance3D = MeshInstance3D.new()
	var slm: BoxMesh = BoxMesh.new()
	slm.size = Vector3(0.05, 0.02, 0.48)
	scan_line.mesh = slm
	scan_line.position = Vector3(-0.25, 1.0, -0.2)
	scan_line.material_override = MaterialLibrary.get_flat_mat("scanner_red", Color(0.95, 0.12, 0.10), 0.2, 2.2)
	add_child(scan_line)

	## Кассовый аппарат
	var reg: MeshInstance3D = MeshInstance3D.new()
	var rm: BoxMesh = BoxMesh.new()
	rm.size = Vector3(0.45, 0.32, 0.38)
	reg.mesh = rm
	reg.position = Vector3(0.35, 1.12, -0.15)
	reg.material_override = MaterialLibrary.get_flat_mat("register_grey", Color(0.22, 0.24, 0.23), 0.6)
	add_child(reg)

	## Монитор CCTV на кассе (экран подключается из CCTVSystem)
	var mon_case: MeshInstance3D = MeshInstance3D.new()
	var mcm: BoxMesh = BoxMesh.new()
	mcm.size = Vector3(0.56, 0.42, 0.32)
	mon_case.mesh = mcm
	mon_case.position = Vector3(0.95, 1.18, -0.08)
	mon_case.rotation_degrees = Vector3(0.0, -28.0, 0.0)
	mon_case.material_override = MaterialLibrary.get_flat_mat("crt_case", Color(0.18, 0.19, 0.18), 0.7)
	add_child(mon_case)

	cctv_screen_mesh = MeshInstance3D.new()
	var qm: QuadMesh = QuadMesh.new()
	qm.size = Vector2(0.48, 0.34)
	cctv_screen_mesh.mesh = qm
	cctv_screen_mesh.position = Vector3(0.0, 0.0, 0.165)
	mon_case.add_child(cctv_screen_mesh)

	## Выключатель света на боковине кассы (интерактивный)
	var sw_area: Area3D = _make_interact_box("light_switch", "Выключатель света (удерживайте 3 с)", Vector3(1.18, 0.88, 0.26), Vector3(0.22, 0.24, 0.16))
	var sw_vis: MeshInstance3D = MeshInstance3D.new()
	var swm: BoxMesh = BoxMesh.new()
	swm.size = Vector3(0.10, 0.14, 0.05)
	sw_vis.mesh = swm
	sw_vis.material_override = MaterialLibrary.get_flat_mat("switch_red", Color(0.75, 0.18, 0.14), 0.4, 0.4)
	sw_area.add_child(sw_vis)
	add_child(sw_area)

	## Выпуклое зеркало в левом дальнем углу
	var mir_frame: MeshInstance3D = MeshInstance3D.new()
	var mfm: CylinderMesh = CylinderMesh.new()
	mfm.top_radius = 0.46
	mfm.bottom_radius = 0.46
	mfm.height = 0.06
	mir_frame.mesh = mfm
	mir_frame.position = Vector3(-4.05, 2.38, -3.55)
	mir_frame.rotation_degrees = Vector3(105.0, -40.0, 0.0)
	mir_frame.material_override = MaterialLibrary.get_flat_mat("mirror_rim", Color(0.12, 0.12, 0.13), 0.5)
	add_child(mir_frame)

	mirror_mesh = MeshInstance3D.new()
	var mq: QuadMesh = QuadMesh.new()
	mq.size = Vector2(0.78, 0.78)
	mirror_mesh.mesh = mq
	mirror_mesh.position = Vector3(0.0, 0.036, 0.0)
	mirror_mesh.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	mir_frame.add_child(mirror_mesh)


func _build_shelves_and_props() -> void:
	var shelf_mat: StandardMaterial3D = MaterialLibrary.get_triplanar_mat("shelf_metal", Color(0.28, 0.30, 0.32), 0.65, 0.35)
	var positions: Array[Vector3] = [
		Vector3(-3.6, 0.95, -2.2),
		Vector3(-3.6, 0.95, -4.1),
		Vector3(3.6, 0.95, -2.2),
	]
	for idx in range(positions.size()):
		var p: Vector3 = positions[idx]
		_add_solid_wall("Shelf_%d" % idx, p, Vector3(0.7, 1.9, 1.6), p, Vector3(0.85, 1.9, 1.7), shelf_mat)
		_populate_shelf_items(p)

	## Холодильник у правой стены
	var fridge_mat: StandardMaterial3D = MaterialLibrary.get_triplanar_mat("fridge_white", Color(0.72, 0.76, 0.78), 0.4)
	_add_solid_wall("Fridge", Vector3(3.85, 1.15, -4.3), Vector3(0.95, 2.3, 1.4), Vector3(3.85, 1.15, -4.3), Vector3(1.05, 2.3, 1.5), fridge_mat)
	var fridge_glow: MeshInstance3D = MeshInstance3D.new()
	var fgm: QuadMesh = QuadMesh.new()
	fgm.size = Vector2(1.15, 1.75)
	fridge_glow.mesh = fgm
	fridge_glow.position = Vector3(3.36, 1.2, -4.3)
	fridge_glow.rotation_degrees = Vector3(0.0, -90.0, 0.0)
	fridge_glow.material_override = MaterialLibrary.get_flat_mat("fridge_door", Color(0.55, 0.76, 0.85), 0.15, 0.75)
	add_child(fridge_glow)


func _populate_shelf_items(shelf_pos: Vector3) -> void:
	var colors: Array[Color] = [
		Color(0.82, 0.22, 0.18), # чипсы
		Color(0.18, 0.62, 0.28), # напитки
		Color(0.82, 0.78, 0.68), # соль
		Color(0.24, 0.12, 0.20), # свечи
	]
	var x_off: float = 0.28 if shelf_pos.x < 0.0 else -0.28
	for row in range(3):
		var y_pos: float = 0.55 + float(row) * 0.52
		for col in range(4):
			var z_off: float = -0.55 + float(col) * 0.36
			var box: MeshInstance3D = MeshInstance3D.new()
			var bm: BoxMesh = BoxMesh.new()
			bm.size = Vector3(0.18, 0.24, 0.22)
			box.mesh = bm
			box.position = Vector3(shelf_pos.x + x_off, y_pos, shelf_pos.z + z_off)
			var c_idx: int = (row + col) % colors.size()
			box.material_override = MaterialLibrary.get_flat_mat("prod_%d" % c_idx, colors[c_idx], 0.7)
			add_child(box)


func _build_backroom() -> void:
	## Щиток питания в подсобке (интерактивный — для отключений света на 5-й ночи)
	var fuse_area: Area3D = _make_interact_box("fuse_box", "Электрощиток (вернуть свет)", Vector3(-1.8, 1.45, 4.48), Vector3(0.55, 0.75, 0.35))
	var fuse_mesh: MeshInstance3D = MeshInstance3D.new()
	var fm: BoxMesh = BoxMesh.new()
	fm.size = Vector3(0.45, 0.62, 0.16)
	fuse_mesh.mesh = fm
	fuse_mesh.material_override = MaterialLibrary.get_flat_mat("fuse_box", Color(0.32, 0.35, 0.32), 0.6)
	fuse_area.add_child(fuse_mesh)

	var fuse_led: MeshInstance3D = MeshInstance3D.new()
	var flm: BoxMesh = BoxMesh.new()
	flm.size = Vector3(0.08, 0.08, 0.04)
	fuse_led.mesh = flm
	fuse_led.position = Vector3(0.0, 0.16, -0.09)
	fuse_led.material_override = MaterialLibrary.get_flat_mat("fuse_led", Color(0.95, 0.25, 0.12), 0.2, 2.0)
	fuse_area.add_child(fuse_led)
	add_child(fuse_area)

	## Ведро со шваброй в углу подсобки
	var bucket: MeshInstance3D = MeshInstance3D.new()
	var bkm: CylinderMesh = CylinderMesh.new()
	bkm.top_radius = 0.20
	bkm.bottom_radius = 0.15
	bkm.height = 0.36
	bucket.mesh = bkm
	bucket.position = Vector3(-3.6, 0.18, 3.8)
	bucket.material_override = MaterialLibrary.get_flat_mat("bucket_blue", Color(0.18, 0.34, 0.56), 0.55)
	add_child(bucket)

	var mop: MeshInstance3D = MeshInstance3D.new()
	var mm: CylinderMesh = CylinderMesh.new()
	mm.top_radius = 0.02
	mm.bottom_radius = 0.02
	mm.height = 1.45
	mop.mesh = mm
	mop.position = Vector3(-3.55, 0.75, 3.8)
	mop.rotation_degrees = Vector3(0.0, 0.0, -14.0)
	mop.material_override = MaterialLibrary.get_flat_mat("mop_wood", Color(0.55, 0.42, 0.26), 0.85)
	add_child(mop)


func _build_street_outside() -> void:
	## Асфальт пустой ночной дороги за стеклом
	var road: MeshInstance3D = MeshInstance3D.new()
	var rm: BoxMesh = BoxMesh.new()
	rm.size = Vector3(45.0, 0.1, 20.0)
	road.mesh = rm
	road.position = Vector3(0.0, -0.08, -16.0)
	road.material_override = MaterialLibrary.get_triplanar_mat("asphalt", Color(0.08, 0.09, 0.10), 0.95)
	add_child(road)

	## Уличный фонарь
	var pole: MeshInstance3D = MeshInstance3D.new()
	var pm: CylinderMesh = CylinderMesh.new()
	pm.top_radius = 0.07
	pm.bottom_radius = 0.09
	pm.height = 5.5
	pole.mesh = pm
	pole.position = Vector3(-3.5, 2.75, -10.5)
	pole.material_override = MaterialLibrary.get_flat_mat("pole_metal", Color(0.16, 0.18, 0.19), 0.7)
	add_child(pole)

	var lamp_head: MeshInstance3D = MeshInstance3D.new()
	var lhm: BoxMesh = BoxMesh.new()
	lhm.size = Vector3(0.6, 0.16, 0.28)
	lamp_head.mesh = lhm
	lamp_head.position = Vector3(-3.1, 5.4, -10.5)
	lamp_head.material_override = MaterialLibrary.get_flat_mat("street_lamp_emit", Color(0.95, 0.78, 0.45), 0.2, 2.4)
	add_child(lamp_head)

	var street_light: OmniLight3D = OmniLight3D.new()
	street_light.position = Vector3(-2.8, 4.9, -10.2)
	street_light.light_color = Color(0.95, 0.76, 0.44)
	street_light.light_energy = 2.8
	street_light.omni_range = 14.0
	street_light.shadow_enabled = false
	add_child(street_light)

	## Фары проезжающих машин
	car_headlights = Node3D.new()
	car_headlights.position = Vector3(-18.0, 0.75, -13.0)
	for z_off: float in [-0.45, 0.45]:
		var hl: MeshInstance3D = MeshInstance3D.new()
		var hlm: SphereMesh = SphereMesh.new()
		hlm.radius = 0.16
		hl.mesh = hlm
		hl.position = Vector3(0.0, 0.0, z_off)
		hl.material_override = MaterialLibrary.get_flat_mat("car_hl", Color(1.0, 0.94, 0.75), 0.1, 4.0)
		car_headlights.add_child(hl)
	var car_light: OmniLight3D = OmniLight3D.new()
	car_light.light_color = Color(1.0, 0.92, 0.72)
	car_light.light_energy = 3.2
	car_light.omni_range = 10.0
	car_light.shadow_enabled = false
	car_headlights.add_child(car_light)
	car_headlights.visible = false
	add_child(car_headlights)


func _build_lighting() -> void:
	## Единственный свет с тенями (бюджет Mobile)
	main_light = OmniLight3D.new()
	main_light.position = Vector3(-0.3, 2.72, -1.3)
	main_light.light_color = Color(0.90, 0.96, 0.84)
	main_light.light_energy = 2.2
	main_light.omni_range = 11.5
	main_light.shadow_enabled = true
	add_child(main_light)

	backroom_light = OmniLight3D.new()
	backroom_light.position = Vector3(-0.5, 2.70, 3.2)
	backroom_light.light_color = Color(0.84, 0.90, 0.76)
	backroom_light.light_energy = 1.25
	backroom_light.omni_range = 7.0
	backroom_light.shadow_enabled = false
	add_child(backroom_light)

	## Люминесцентные трубки на потолке
	var tube_positions: Array[Vector3] = [
		Vector3(-0.3, 2.95, -1.2),
		Vector3(-0.3, 2.95, -3.8),
		Vector3(-0.5, 2.95, 3.2),
	]
	for i in range(tube_positions.size()):
		var tube: MeshInstance3D = MeshInstance3D.new()
		var tm: BoxMesh = BoxMesh.new()
		tm.size = Vector3(1.5, 0.06, 0.14)
		tube.mesh = tm
		tube.position = tube_positions[i]
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(0.88, 0.96, 0.85)
		mat.emission_enabled = true
		mat.emission = Color(0.85, 0.96, 0.82)
		mat.emission_energy_multiplier = 2.0
		tube.material_override = mat
		tube_mats.append(mat)
		add_child(tube)


func _build_hallucination_prop() -> void:
	## Ложный силуэт, видимый ТОЛЬКО на камере CCTV при низком рассудке
	hallucination_mesh = MeshInstance3D.new()
	var cm: CapsuleMesh = CapsuleMesh.new()
	cm.radius = 0.28
	cm.height = 1.95
	hallucination_mesh.mesh = cm
	hallucination_mesh.position = Vector3(-2.3, 0.98, -3.2)
	hallucination_mesh.material_override = MaterialLibrary.get_shadow_doppelganger_mat()
	hallucination_mesh.layers = Layers.VIS_CCTV_ONLY
	hallucination_mesh.visible = false
	add_child(hallucination_mesh)


func _build_audio() -> void:
	doorbell_audio = AudioStreamPlayer3D.new()
	doorbell_audio.position = Vector3(0.0, 2.4, -5.5)
	doorbell_audio.bus = "SFX"
	doorbell_audio.stream = SoundBank.get_stream("door_bell")
	add_child(doorbell_audio)

	_ambient_hum = AudioStreamPlayer3D.new()
	_ambient_hum.position = Vector3(-0.3, 2.9, -1.2)
	_ambient_hum.bus = "Ambience"
	_ambient_hum.unit_size = 6.0
	_ambient_hum.volume_db = -12.0
	_ambient_hum.stream = SoundBank.get_stream("fluorescent_hum")
	add_child(_ambient_hum)
	_ambient_hum.play()

	_fridge_hum = AudioStreamPlayer3D.new()
	_fridge_hum.position = Vector3(3.6, 1.2, -4.3)
	_fridge_hum.bus = "Ambience"
	_fridge_hum.unit_size = 4.0
	_fridge_hum.volume_db = -10.0
	_fridge_hum.stream = SoundBank.get_stream("fridge_hum")
	add_child(_fridge_hum)
	_fridge_hum.play()

	_road_audio = AudioStreamPlayer3D.new()
	_road_audio.position = Vector3(0.0, 1.5, -6.5)
	_road_audio.bus = "Ambience"
	_road_audio.unit_size = 8.0
	_road_audio.volume_db = -11.0
	_road_audio.stream = SoundBank.get_stream("road_ambience")
	add_child(_road_audio)
	_road_audio.play()

	_vhs_hiss = AudioStreamPlayer.new()
	_vhs_hiss.bus = "Ambience"
	_vhs_hiss.volume_db = -16.0
	_vhs_hiss.stream = SoundBank.get_stream("vhs_hiss")
	add_child(_vhs_hiss)
	_vhs_hiss.play()

	_tension_drone = AudioStreamPlayer.new()
	_tension_drone.bus = "Ambience"
	_tension_drone.volume_db = -32.0
	_tension_drone.stream = SoundBank.get_stream("tension_drone")
	add_child(_tension_drone)
	_tension_drone.play()

	_heartbeat_player = AudioStreamPlayer.new()
	_heartbeat_player.bus = "SFX"
	_heartbeat_player.volume_db = -40.0
	_heartbeat_player.stream = SoundBank.get_stream("heartbeat")
	add_child(_heartbeat_player)
	_heartbeat_player.play()


func _make_interact_box(zone_id: String, label_ru: String, pos: Vector3, sz: Vector3) -> Area3D:
	var area: Area3D = Area3D.new()
	area.name = "Interact_" + zone_id
	area.position = pos
	area.collision_layer = Layers.PHYS_INTERACT
	area.collision_mask = 0
	area.set_meta("interact_id", zone_id)
	area.set_meta("interact_label", label_ru)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = sz
	cs.shape = bs
	area.add_child(cs)
	return area


func _on_power_changed(power_on: bool) -> void:
	if not power_on:
		SoundBank.play_sfx("power_down", 1.0, 0.0)
	else:
		SoundBank.play_sfx("ui_click", 0.7, 1.0)
	_apply_light_state()


func _apply_light_state() -> void:
	var is_on: bool = GameState.power_on and not _lights_forced_off
	if main_light != null:
		main_light.visible = is_on
	if backroom_light != null:
		backroom_light.visible = GameState.power_on
	for mat: StandardMaterial3D in tube_mats:
		mat.emission_energy_multiplier = 2.0 if is_on else 0.05
	if _ambient_hum != null:
		_ambient_hum.stream_paused = not is_on


func _on_weather_changed(weather_type: int) -> void:
	if rain_glass_mat != null:
		rain_glass_mat.set_shader_parameter("rain_amount", 1.0 if weather_type == GameState.WEATHER_RAIN else 0.0)


func _update_lights_flicker(delta: float) -> void:
	if not GameState.power_on or _lights_forced_off or main_light == null:
		return
	_flicker_timer -= delta
	if _flicker_timer <= 0.0:
		var sanity_factor: float = 1.0 - (GameState.sanity / 100.0)
		if _rng.randf() < (0.06 + sanity_factor * 0.22):
			main_light.light_energy = _rng.randf_range(0.55, 1.45)
			_flicker_timer = _rng.randf_range(0.05, 0.14)
		else:
			main_light.light_energy = 2.2
			_flicker_timer = _rng.randf_range(0.35, 1.6)


func _update_passing_car(delta: float) -> void:
	if car_headlights == null:
		return
	if not _car_active:
		_car_timer -= delta
		if _car_timer <= 0.0:
			_car_active = true
			_car_x = -20.0
			car_headlights.visible = true
	else:
		_car_x += delta * 18.0
		car_headlights.position.x = _car_x
		if _car_x > 20.0:
			_car_active = false
			car_headlights.visible = false
			_car_timer = _rng.randf_range(12.0, 28.0)


func _update_sanity_audio_and_hallucinations() -> void:
	var stress: float = clampf(1.0 - (GameState.sanity / 100.0), 0.0, 1.0)
	var night_bonus: float = float(GameState.current_night - 1) * 0.1
	if _tension_drone != null:
		_tension_drone.volume_db = lerpf(-30.0, -8.0, clampf(stress + night_bonus, 0.0, 1.0))
	if _heartbeat_player != null:
		_heartbeat_player.volume_db = lerpf(-45.0, -6.0, clampf((stress - 0.35) * 1.6, 0.0, 1.0))
	if hallucination_mesh != null:
		var show_ghost: bool = stress > 0.45 and (int(Time.get_ticks_msec() / 1800) % 4 == 0)
		hallucination_mesh.visible = show_ghost

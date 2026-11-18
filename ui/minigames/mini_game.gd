class_name MiniGame
extends Control

## Базовый класс для всех мини-игр на кассе

signal finished(success: bool, quality: float)
signal rejected_by_player()

var _completed: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _finish_game(success: bool, quality: float) -> void:
	if _completed:
		return
	_completed = true
	finished.emit(success, clampf(quality, 0.0, 1.0))


func _reject_customer() -> void:
	if _completed:
		return
	_completed = true
	rejected_by_player.emit()


func _make_styled_panel(bg_col: Color) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = Color(0.45, 0.55, 0.42)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(14)
	p.add_theme_stylebox_override("panel", sb)
	return p

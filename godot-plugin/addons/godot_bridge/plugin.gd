@tool
extends EditorPlugin

const BridgeServer = preload("res://addons/godot_bridge/bridge_server.gd")

var _server: BridgeServer
var _status_label: Label


func _enter_tree() -> void:
	_server = BridgeServer.new()
	_server.status_changed.connect(_on_status_changed)
	add_child(_server)

	_status_label = Label.new()
	_status_label.text = "Bridge: Starting…"
	add_control_to_bottom_panel(_status_label, "Bridge")

	var port: int = _get_port()
	_server.start(port)


func _exit_tree() -> void:
	if _server:
		_server.stop()
		remove_child(_server)
		_server = null

	if _status_label:
		remove_control_from_bottom_panel(_status_label)
		_status_label.queue_free()
		_status_label = null


func _get_port() -> int:
	var setting := "godot_bridge/port"
	if not ProjectSettings.has_setting(setting):
		ProjectSettings.set_setting(setting, 6505)
		ProjectSettings.set_initial_value(setting, 6505)
		ProjectSettings.save()
	return int(ProjectSettings.get_setting(setting))


func _on_status_changed(status: String) -> void:
	if _status_label:
		_status_label.text = "Bridge: " + status

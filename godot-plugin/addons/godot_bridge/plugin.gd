@tool
extends EditorPlugin

const BridgeServer = preload("res://addons/godot_bridge/bridge_server.gd")
const BridgeDebuggerPlugin = preload("res://addons/godot_bridge/bridge_debugger_plugin.gd")

const RUNTIME_AUTOLOAD_NAME := "GodotBridgeRuntime"
const RUNTIME_AUTOLOAD_PATH := "res://addons/godot_bridge/runtime/bridge_runtime.gd"

var _server: BridgeServer
var _debugger_plugin: EditorDebuggerPlugin
var _status_label: Label


func _enter_tree() -> void:
	_ensure_runtime_autoload()

	_debugger_plugin = BridgeDebuggerPlugin.new()
	add_debugger_plugin(_debugger_plugin)

	_server = BridgeServer.new()
	_debugger_plugin.set_server(_server)
	_server.init_plugin(self, _debugger_plugin)
	_server.status_changed.connect(_on_status_changed)
	add_child(_server)

	_status_label = Label.new()
	_status_label.text = "Bridge: Starting…"
	add_control_to_bottom_panel(_status_label, "Bridge")

	var port: int = _get_port()
	_server.start(port)


func _exit_tree() -> void:
	if _debugger_plugin:
		remove_debugger_plugin(_debugger_plugin)
		_debugger_plugin = null

	if _server:
		_server.stop()
		remove_child(_server)
		_server = null

	if _status_label:
		remove_control_from_bottom_panel(_status_label)
		_status_label.queue_free()
		_status_label = null

	_remove_runtime_autoload()


func _get_port() -> int:
	var setting := "godot_bridge/port"
	if not ProjectSettings.has_setting(setting):
		ProjectSettings.set_setting(setting, 6505)
		ProjectSettings.set_initial_value(setting, 6505)
		ProjectSettings.save()
	return int(ProjectSettings.get_setting(setting))


func _ensure_runtime_autoload() -> void:
	var setting := "autoload/%s" % RUNTIME_AUTOLOAD_NAME
	if ProjectSettings.has_setting(setting):
		return
	add_autoload_singleton(RUNTIME_AUTOLOAD_NAME, RUNTIME_AUTOLOAD_PATH)


func _remove_runtime_autoload() -> void:
	var setting := "autoload/%s" % RUNTIME_AUTOLOAD_NAME
	if not ProjectSettings.has_setting(setting):
		return
	remove_autoload_singleton(RUNTIME_AUTOLOAD_NAME)


func _on_status_changed(status: String) -> void:
	if _status_label:
		_status_label.text = "Bridge: " + status

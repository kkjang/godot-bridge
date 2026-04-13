@tool
class_name BridgeProjectSettings
extends RefCounted


static func read_settings(property_list: Array, getter: Callable, keys: Array, prefix: String) -> Dictionary:
	var settings := {}
	var seen := {}

	for key in keys:
		var setting_key := str(key)
		if setting_key.is_empty() or seen.has(setting_key):
			continue
		settings[setting_key] = getter.call(setting_key)
		seen[setting_key] = true

	if not prefix.is_empty():
		for property_info in property_list:
			var property_name := str(property_info.get("name", ""))
			if property_name.is_empty() or not property_name.begins_with(prefix) or seen.has(property_name):
				continue
			settings[property_name] = getter.call(property_name)
			seen[property_name] = true

	return settings

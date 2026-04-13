@tool
class_name BridgeDebugState
extends RefCounted

const ALLOWED_EVENTS := ["output", "error"]

var _all_events := false
var _events := {}


func subscribe(events: Array) -> Array[String]:
	var normalized := normalize_events(events)
	if normalized.is_empty():
		_all_events = true
		_events.clear()
		return subscribed_events()

	if _all_events:
		return subscribed_events()

	for event_name in normalized:
		_events[event_name] = true
	return subscribed_events()


func unsubscribe(events: Array) -> Array[String]:
	var normalized := normalize_events(events)
	if normalized.is_empty():
		_all_events = false
		_events.clear()
		var empty: Array[String] = []
		return empty

	if _all_events:
		_all_events = false
		_events.clear()
		for event_name in ALLOWED_EVENTS:
			if not normalized.has(event_name):
				_events[event_name] = true
		return subscribed_events()

	for event_name in normalized:
		_events.erase(event_name)
	return subscribed_events()


func should_forward(event_name: String) -> bool:
	return _all_events or _events.has(event_name)


func subscribed_events() -> Array[String]:
	if _all_events:
		var all_events: Array[String] = []
		for event_name in ALLOWED_EVENTS:
			all_events.append(str(event_name))
		return all_events

	var values: Array[String] = []
	for event_name in _events.keys():
		values.append(str(event_name))
	values.sort()
	return values


static func normalize_events(events: Array) -> Array[String]:
	var values: Array[String] = []
	var seen := {}
	for event_name in events:
		var normalized := str(event_name).strip_edges().to_lower()
		if normalized.is_empty():
			continue
		if not ALLOWED_EVENTS.has(normalized):
			continue
		if seen.has(normalized):
			continue
		seen[normalized] = true
		values.append(normalized)
	return values

class_name FixedSizeQueue
extends RefCounted
## Keeps only the last `limit` items. Port of MoBBoLibrary_WIFI.FixedSizeQueue<T>.

var _items: Array = []
var limit: int

var last:
	get: return _items.back() if not _items.is_empty() else null

var size: int:
	get: return _items.size()

var is_full: bool:
	get: return _items.size() >= limit

func _init(p_limit: int) -> void:
	limit = p_limit

func enqueue(item) -> void:
	_items.append(item)
	while _items.size() > limit:
		_items.pop_front()

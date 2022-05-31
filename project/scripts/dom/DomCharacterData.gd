extends DomNode
class_name DomCharacterData
## https://dom.spec.whatwg.org/#characterdata

var data: String
var length: int setget ,_get_length

func _get_length() -> int:
  return data.length()

extends DomNode
class_name DomCharacterData
## https://dom.spec.whatwg.org/#characterdata

var data: String


func _replace_data(offset: int, count: int, data_: String) -> void:
  # whatwg: https://dom.spec.whatwg.org/#concept-cd-replace
  var length := self._get_length()
  if offset > length:
    # whatwg: throw an "IndexSizeError" DOMException. 
    # todo: Mechanism for propagating DOMExceptions
    return
  if offset + count > length:
    count = length - offset

  # todo: Small optimization by bypasssing `self.data` resolution, work on local copy instead
  var new_data = self.data.insert(offset, data_)
  new_data.erase(offset + data_.length(), count)
  self.data = new_data

  var parent := self.get_parent()
  if parent != null:
    parent._children_changed()

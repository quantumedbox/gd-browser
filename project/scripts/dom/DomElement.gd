extends DomNode
class_name DomElement
## https://dom.spec.whatwg.org/#element

# todo: Attrs are technically part of tree, so, it might be better to use godot scene for placing them, at least for consistency and method correctness
#       This however does create quite a bit of overhead. We might consider to make attributes live outside of scene tree and prefer local dictionary instead. It actually might simplify some aspect of implementation, but not all. For example, not sure how attribute node would know their parent inside of dictionary.

var tag_name: String
var id: String setget _set_id, _get_id


func _init() -> void:
  node_type = DomNode.ELEMENT_NODE


func get_attribute_node(qualified_name: String): # -> ?DomAttr
  for child in self.get_children():
    if child.node_type == DomNode.ATTRIBUTE_NODE:
      if child.attr_name == qualified_name:
        return child
  return null


func get_attrbiute(attr: String): # ?String
  var attr_node = get_attribute_node(attr)
  if attr_node == null:
    return null
  return attr_node.attr_value


func _set_id(new_id: String) -> void:
  var attr_node = get_attribute_node("id")
  if attr_node != null:
    attr_node.value = new_id


func _get_id() -> String:
  var attr_node = get_attribute_node("id")
  if attr_node != null:
    return attr_node.attr_value
  else:
    return ""


func _private_setter(_any) -> void:
  assert(false, "Private setter is used")

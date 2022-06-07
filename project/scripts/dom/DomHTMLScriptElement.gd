extends DomHTMLElement
class_name DomHTMLScriptElement
## https://html.spec.whatwg.org/multipage/scripting.html#htmlscriptelement

var type: String setget _private_setter, _get_type # Technically type isn't readonly by spec, but meh
var text: String setget _set_text, _get_text


func _get_type() -> String:
  var attr_node = get_attribute_node("type")
  if attr_node != null:
    return attr_node.attr_value
  else:
    return ""


func _set_text(_text_: String) -> void:
  ## https://html.spec.whatwg.org/multipage/scripting.html#dom-script-text
  Shared.unimplemented()


func _get_text() -> String:
  ## https://html.spec.whatwg.org/multipage/scripting.html#dom-script-text
  var result: String = ""
  for child in self.get_children():
    if child.node_type == TEXT_NODE:
      result += child.data
  return result


func _private_setter(_any) -> void:
  assert(false, "Private setter is used")

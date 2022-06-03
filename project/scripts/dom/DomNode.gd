extends Node # todo: Should implement event listener, but do we need it?
class_name DomNode
## https://dom.spec.whatwg.org/#node

enum {
  ELEMENT_NODE = 1,
  ATTRIBUTE_NODE,
  TEXT_NODE,
  CDATA_SECTION_NODE,
  COMMENT_NODE = 8,
  DOCUMENT_NODE,
  DOCUMENT_TYPE_NODE,
}

var node_type: int setget _private_setter
var text_content: String setget _set_text_content, _get_text_content
var length: int setget _private_setter, _get_length


func _set_text_content(text: String) -> void:
  # https://dom.spec.whatwg.org/#dom-node-textcontent
  match self.node_type:
    ELEMENT_NODE:
      var node = null
      if not text.empty():
        node = load("res://scripts/dom/DomText.gd").new() # todo: Kinda not great
        node.data = text
      self._replace_all(node)

    ATTRIBUTE_NODE:
      Shared.unimplemented()


    TEXT_NODE, COMMENT_NODE:
      # whatwf: Replace data with node this, offset 0, count this’s length, and data the given value.
      self.call("_replace_data", 0, self.length, text)


func _get_text_content(): # -> ?String:
  # https://dom.spec.whatwg.org/#dom-node-textcontent
  var result = null

  match self.node_type:
    ELEMENT_NODE:
      result = ""
      # whatwg: The descendant text content of this.
      var text_descendants := _collect_descendants_by_type(TEXT_NODE)
      for descendant in text_descendants:
        # todo: Should there be any separation? whatwg says that it's empty string as far as i can see
        result += descendant.data

    ATTRIBUTE_NODE:
      result = self.attr_value

    TEXT_NODE, COMMENT_NODE:
      result = self.data

  assert(result is String or result == null)
  return result


func _get_length() -> int:
  # https://dom.spec.whatwg.org/#concept-node-length
  match self.node_type:
    DOCUMENT_TYPE_NODE, ATTRIBUTE_NODE:
      return 0

    TEXT_NODE, COMMENT_NODE:
      return self.data.length()

    _: return self.get_child_count()


func _replace_all(node) -> void:
  ## https://dom.spec.whatwg.org/#concept-node-replace-all
  # Assumes `parent` as self
  for child in self.get_children():
    remove_child(child)
    child.queue_free()
  if node != null:
    _insert(node, null)


func _insert(node, child) -> void:
  ## https://dom.spec.whatwg.org/#concept-node-insert
  # Assumes `parent` as self
  # var nodes := node.get_children()
  # var count := nodes.size()
  # if count == 0:
  #   return
  if child != null:
    Shared.unimplemented()
    return
  self.add_child(node) # todo: Should be a lot more, lol
  self._children_changed()


func _children_changed() -> void:
  # todo: Should signalize that render update is possibly needed to page
  Shared.unimplemented()


# todo: Rename? There could also be already something similar in DOM spec
func _collect_descendants_by_type(node_type_: int) -> Array: # Array<DomNode>
  var result := Array()
  var stack := Array()
  var idx := 0
  var cur := self
  while true:
    while idx < cur.get_child_count():
      var node = cur.get_child(idx)
      if node.node_type == node_type_:
        result.push_back(node)
      if node.get_child_count() != 0:
        stack.push_back(cur)
        stack.push_back(idx + 1)
        cur = node
        idx = -1
      idx += 1
    if stack.empty():
      break
    idx = stack.pop_back()
    cur = stack.pop_back()
  return result


func _private_setter(_any) -> void:
  assert(false, "Private setter is used")

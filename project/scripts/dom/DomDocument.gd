extends DomNode
class_name DomDocument
## https://dom.spec.whatwg.org/#document

var url: String
var character_set: String
var content_type: String
var doctype: DomDocumentType setget ,_get_doctype


func _init() -> void:
  node_type = DomNode.DOCUMENT_NODE


func _get_doctype() -> DomDocumentType:
  Shared.unimplemented()
  return null


func get_elements_by_tag_name(tag_name: String) -> Array: # Array<DomElement>
  var result := Array()
  var stack := Array()
  var cur: DomNode = self
  var idx := 0
  while true:
    while idx < cur.get_child_count():
      var node := cur.get_child(idx)
      if node.node_type == DomNode.ELEMENT_NODE:
        if node.tag_name == tag_name:
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


func get_element_by_id(id: String): # -> ?DomElement
  var stack := Array()
  var cur: DomNode = self
  var idx := 0
  while true:
    while idx < cur.get_child_count():
      var node := cur.get_child(idx)
      if node.node_type == DomNode.ELEMENT_NODE:
        if node.id == id:
          return node
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
  return null

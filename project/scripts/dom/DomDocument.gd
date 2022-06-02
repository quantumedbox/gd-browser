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
  # todo: Search for DocumentType node
  return null


func get_element_by_id(id: String): # -> ?DomElement
  var idx_stack := PoolIntArray()
  var cur_stack := Array()
  var idx := 0
  var cur := self
  while true:
    while idx < cur.get_child_count():
      var node := cur.get_child(idx)
      if node.node_type == DomNode.ELEMENT_NODE:
        if node.id == id:
          return node
      if node.get_child_count() != 0:
        idx_stack.push_back(idx + 1)
        cur_stack.push_back(cur)
        cur = node
        idx = -1
      idx += 1
    if idx_stack.empty():
      break
    idx = idx_stack[idx_stack.size() - 1]
    idx_stack.remove(idx_stack.size() - 1)
    cur = cur_stack.pop_back()
  return null

extends DomNode
class_name DomDocument
## https://dom.spec.whatwg.org/#document

var url: String
var character_set: String
var content_type: String
var doctype: DomDocumentType setget ,_get_doctype


func _get_doctype() -> DomDocumentType:
  # todo: Search for DocumentType node
  return null

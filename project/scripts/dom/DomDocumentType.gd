extends DomNode
class_name DomDocumentType
## https://dom.spec.whatwg.org/#documenttype

var doctype_name: String
var publicId: String
var systemId: String


func _init() -> void:
  node_type = DomNode.DOCUMENT_TYPE_NODE

extends DomNode
class_name DomAttr
## https://dom.spec.whatwg.org/#attr

# todo: What to do? We can't use `name` as Node already implements that
#       Changing the name will somewhat worsen the compat with DOM spec
var attr_name: String
var attr_value: String


func _init() -> void:
  node_type = DomNode.ATTRIBUTE_NODE

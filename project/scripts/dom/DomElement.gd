extends DomNode
class_name DomElement
## https://dom.spec.whatwg.org/#element

var tag_name: String

# Array<DomAttr>
# todo: Attrs are technically part of tree, so, it might be better to use godot scene for placing them, at least for consistency and method correctness
# var attributes: Array


# func has_attributes() -> bool:
#   return !attributes.empty()


# func get_attribute_names() -> PoolStringArray:
#   var result = PoolStringArray()
#   for node in attributes:
#     result.push_back(node.node_name)
#   return result

# todo: Fill attribute interface as we need it

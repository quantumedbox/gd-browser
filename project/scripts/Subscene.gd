extends ViewportContainer

onready var n_Viewport := find_node("Viewport")


func emplace(node: Node) -> void:
  Shared.drop_node_tree(n_Viewport)
  n_Viewport.add_child(node)

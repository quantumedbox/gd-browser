extends Node


func do_assert(status: bool, msg: String = "") -> void:
  if not status:
    if msg.empty():
      push_error("{source}:{function}:{line}".format(get_stack()[1]))
    else:
      push_error("{source}:{function}:{line} ".format(get_stack()[1]) + msg)
    # todo: Apparently it crashes on web build?
    #       We could change the scene to crash report instead of exiting
    get_tree().quit(1)


static func ok(status: int, msg: String = "") -> void:
  assert(status == OK, msg)


static func dump_node_tree(obj, indent: int = 0):
  if obj is Dictionary:
    for item in obj:
      if obj[item] is Dictionary or obj[item] is Array:
        print(" ".repeat(indent) + item + ": ")
        dump_node_tree(obj[item], indent + 1)
      else:
        print(" ".repeat(indent) + item + ": " + obj[item])
  elif obj is Array:
    for item in obj:
      if item is Dictionary or item is Array:
        dump_node_tree(item, indent + 1)
      else:
        print(" ".repeat(indent) + item)
  else: assert(false)

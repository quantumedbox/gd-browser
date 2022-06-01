extends Node

# todo: Make it an array instead?
const HTTPErrorToText := {
  HTTPRequest.RESULT_SUCCESS: "Success",
  HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH: "Chunked body mismatch",
  HTTPRequest.RESULT_CANT_CONNECT: "Can't connect",
  HTTPRequest.RESULT_CANT_RESOLVE: "Can't resolve",
  HTTPRequest.RESULT_CONNECTION_ERROR: "Connection error",
  HTTPRequest.RESULT_SSL_HANDSHAKE_ERROR: "SSL handshake error",
  HTTPRequest.RESULT_NO_RESPONSE: "No response",
  HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED: "Body size limit exceeded",
  HTTPRequest.RESULT_REQUEST_FAILED: "Request failed",
  HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN: "Can't open download file",
  HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR: "Can't write to download file",
  HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED: "Redirect limit reached",
  HTTPRequest.RESULT_TIMEOUT: "Timeout",
}


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


static func drop_node_tree(node: Node) -> void:
  for child in node:
    node.remove_child(child)
    child.queue_free()

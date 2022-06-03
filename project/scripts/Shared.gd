extends Node

# todo: Wrap Godot global scope error codes to text descriptions

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


static func unimplemented() -> void:
  push_error("Unimplemented: {source}:{function}:{line}".format(get_stack()[1]))


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
  for child in node.get_children():
    node.remove_child(child)
    child.queue_free()


static func free_dir(path: String) -> void:
  # todo: Remove itself too?
  var dir := Directory.new()
  var err := dir.open(path)
  if err != OK:
    push_error("Error opening temporary directory for freeing %s, error code: %s" % [path, err])
    return
  err = dir.list_dir_begin(true)
  if err != OK:
    push_error("Error starting iterating temporary directory for freeing %s, error code: %s" % [path, err])
    return
  var filename := dir.get_next()
  while filename != "":
    if dir.current_is_dir():
      free_dir("%s/%s" % [path, filename])
      err = dir.remove(filename)
      if err != OK:
        push_error("Error removing temporary directory at %s, error code: %s" % ["%s/%s" % [path, filename], err])
    else:
      err = dir.remove(filename)
      if err != OK:
        push_error("Error removing temporary file at %s, error code: %s" % ["%s/%s" % [path, filename], err])
    filename = dir.get_next()
  dir.list_dir_end()

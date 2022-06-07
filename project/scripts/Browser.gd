extends Control

# todo: Error message display to user, probably via console-like interface
#       We could also generate DOM pages to render, so that no new functionalities would need to be added


const STARTUP_URL := "https://serenityos.org"

onready var n_SearchBox := find_node("SearchBox")
onready var n_Canvas := find_node("Canvas")

var n_Page: Node = null # todo: Temp


func _ready() -> void:
  # Ensure clearance of temporaries of previous session
  Shared.free_dir("res://temp") # todo: Make path to temp root a project setting
  Shared.ok(self.n_SearchBox.connect("text_entered", self, "_on_search_made"))
  var args := OS.get_cmdline_args()
  if args.size() > 0:
    request_page(URL.parse(args[0]))
  else:
    request_page(URL.parse(STARTUP_URL))


func _on_search_made(url: String) -> void:
  request_page(URL.parse(url))


func request_page(url: URL.URLObject) -> void:
  assert(not url.failure)
  n_SearchBox.text = url.to_urlstring()
  # todo: Implement "file:///" URLs by invoking filesystem operations
  if self.n_Page != null:
    remove_child(self.n_Page)
    self.n_Page.queue_free()
    Shared.drop_node_tree(self.n_Canvas)
  self.n_Page = preload("res://scenes/Page.tscn").instance()
  Shared.ok(self.n_Page.connect("page_requested", self, "request_page")) # todo: Temp
  add_child(self.n_Page)
  var await = self.n_Page.request_document(url)
  while await is GDScriptFunctionState:
    await = yield(await, "completed")
  if await == true:
    self.n_Page.render_to(self.n_Canvas)

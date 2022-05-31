extends Control

# todo: Error message display to user
# todo: Would be really interesting to have GDScript based webpages, or probably even loading of scenes


onready var n_SearchBox := find_node("SearchBox")
onready var n_HTTPRequest := find_node("HTTPRequest")
onready var n_HTMLParser := find_node("HTMLParser")
onready var n_DOM := find_node("DOM")
onready var n_PageCanvas := find_node("PageCanvas")


func _ready() -> void:
  OS.low_processor_usage_mode = true
  Shared.ok(self.n_SearchBox.connect("text_entered", self, "_on_search_made"))
  Shared.ok(self.n_HTTPRequest.connect("request_completed", self, "_on_request_completed"))
  self.n_HTMLParser.stop_on_first_error = true
  self.n_HTTPRequest.use_threads = true

  if OS.has_feature("debug"):
    _on_search_made("http://histo.io/")


func _on_search_made(url: String) -> void:
  if self.n_HTTPRequest.request(url) != OK:
      push_error("An error occurred in the HTTP request.")


func _on_request_completed(result: int, response_code: int, headers: PoolStringArray, body: PoolByteArray) -> void:
  # todo: Method to parse header information
  #       In particular it might be useful for getting info about document type that is returned
  if result != OK:
    push_error("Error on request")
    return

  if response_code != 200:
    push_error("Response code: %s" % response_code)
    return

  # todo: It could be beneficial to implement iterator mechanism to bypass need to create so many intermediate dictionaries and arrays
  var body_parsed := self.n_HTMLParser.parse(body.get_string_from_utf8()) as Dictionary
  if body_parsed.empty():
    # Error in gd-gumbo represented by empty dict currently
    push_error("Invalid HTML document")
    return

  Shared.dump_node_tree(body_parsed)

  _nuke_tree(self.n_DOM)
  _nuke_tree(self.n_PageCanvas)
  # todo: Pass URL here. I think headers have address field?
  _populate_tree(self.n_DOM, body_parsed, "todo!")
  _render_dom(self.n_DOM.get_child(0), self.n_PageCanvas)


func _nuke_tree(root: Node) -> void:
  for child in root.get_children():
    child.queue_free()


func _populate_tree(root: Node, desc: Dictionary, url: String) -> void:
  # todo: Passing url string around recursively is kinda lame
  var this: Node = null

  assert("type" in desc)

  match desc["type"]:
    "document":
      var node := DomDocument.new() as DomDocument
      node.url = url
      var doctype_node := DomDocumentType.new() as DomDocumentType
      if "public_identifier" in desc:
        doctype_node.publicId = desc["public_identifier"]
      if "system_identifier" in desc:
        doctype_node.systemId = desc["system_identifier"]
      node.add_child(doctype_node)
      root.add_child(node)
      this = node

    "element":
      var node := DomElement.new() as DomElement
      if "tag" in desc:
        node.tag_name = desc["tag"]
      if "attributes" in desc:
        for attr in desc["attributes"]:
          var attr_node := DomAttr.new() as DomAttr
          attr_node.attr_name = attr
          attr_node.attr_value = desc["attributes"][attr]
      root.add_child(node)
      this = node

    "text":
      var node := DomText.new().init(desc["text"]) as DomText
      root.add_child(node)
      this = node

    _: push_error("Node %s unimplemented" % desc["type"])

  if "children" in desc:
    assert(desc["children"] is Array)
    for child in desc["children"]:
      _populate_tree(this, child, url)


static func _render_dom(node: DomNode, page_canvas: Container) -> void:
  ## Naive and incorrect
  if node is DomElement:
    _render_dom_element(node, page_canvas)
  else: pass

  for child in node.get_children():
    _render_dom(child, page_canvas)


static func _render_dom_element(elem: DomElement, page_canvas: Container) -> void:
  # todo: Translate HTML/XHTML markup to BBCode rudely
  match elem.tag_name:
    "p":
      var text := _collect_text(elem)
      if not text.empty():
        var p := preload("res://scenes/elements/Paragraph.tscn").instance()
        p.text = text
        page_canvas.add_child(p)


static func _collect_text(root: DomNode) -> String:
  var result: String
  for child in root.get_children():
    if child is DomText:
      result += child.data
  return result

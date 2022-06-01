extends Control

# todo: Error message display to user
# todo: Would be really interesting to have GDScript based webpages, or probably even loading of scenes


onready var n_SearchBox := find_node("SearchBox")
onready var n_HTTPRequest := find_node("HTTPRequest")
onready var n_HTMLParser := find_node("HTMLParser")
onready var n_DOM := find_node("DOM")
onready var n_PageCanvas := find_node("PageCanvas")


func _ready() -> void:
  Shared.ok(self.n_SearchBox.connect("text_entered", self, "_on_search_made"))
  Shared.ok(self.n_HTTPRequest.connect("request_completed", self, "_on_request_completed"))
  self.n_HTMLParser.stop_on_first_error = false
  self.n_HTTPRequest.use_threads = true

  if OS.has_feature("debug"):
    request_page("https://www.webfx.com/archive/blog/images/assets/cdn.sixrevisions.com/0435-01_html5_download_attribute_demo/samp/htmldoc.html")


func _on_search_made(url: String) -> void:
  request_page(url)


func request_page(url: String) -> void:
  # todo: Mutex on n_HTTPRequest so that only one request will go at the time
  if self.n_HTTPRequest.request(url) != OK:
      push_error("An error occurred in the HTTP request.")


func _on_request_completed(result: int, response_code: int, headers: PoolStringArray, body: PoolByteArray) -> void:
  # todo: Method to parse header information
  #       In particular it might be useful for getting info about document type that is returned
  if result != OK:
    push_error("Error on request: %s" % result)
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

  # if OS.has_feature("debug"):
  #   Shared.dump_node_tree(body_parsed)

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
          root.add_child(attr_node)
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


func _render_dom(node: DomDocument, page_canvas: Container) -> void:
  ## Naive and incorrect
  for child in node.get_children():
    if child is DomElement and child.tag_name == "html":
      _render_element(child, page_canvas)


func _render_node(node: DomNode, page_canvas: Container) -> void:
  ## Generic dispatcher
  if node is DomElement:
    _render_element(node, page_canvas)
  elif node is DomText:
    var text_node := preload("res://scenes/Text.tscn").instance()
    text_node.bbcode_text = node.data
    page_canvas.add_child(text_node)


func _render_element(node: DomElement, page_canvas: Container) -> void:
  # todo: Sectioning tags
  match node.tag_name:
    "title":
      pass
      # todo: Display page title

    "meta", "base", "head", "link", "style":
      pass
      # Ignored metadata tags

    "a":
      # Hyperlink
      var text_content = DomInterface.get_text_content(node)
      if text_content:
        var text_node := preload("res://scenes/Text.tscn").instance()
        text_node.bbcode_text = "[url=%s]%s[/url]" % [DomInterface.get_attrbiute(node, "href"), text_content]
        _apply_text_style_by_tag(text_node, node.tag_name)
        Shared.ok(text_node.connect("meta_clicked", self, "_on_meta_clicked"))
        page_canvas.add_child(text_node)

    "div", "h1", "p":
      # todo: <div> and alike should collect child nodes into itself, creating single container object rather than separate ones
      # Text content elements
      var text_content = DomInterface.get_text_content(node)
      if text_content:
        var text_node := preload("res://scenes/Text.tscn").instance()
        text_node.bbcode_text = text_content
        _apply_text_style_by_tag(text_node, node.tag_name)
        page_canvas.add_child(text_node)
      for child in node.get_children():
        if child is DomElement:
          _render_node(child, page_canvas)

    _:
      # For now unknown tags are used for propagation further down the tree
      for child in node.get_children():
        if child is DomElement:
          _render_node(child, page_canvas)


static func _apply_text_style_by_tag(node: RichTextLabel, tag: String) -> void:
  match tag:
    "h1":
      var font := FontManager.request_font(FontManager.DEFAULT_FAMILY, FontManager.DEFAULT_TYPEFACE, 28)
      node.set("custom_fonts/normal_font", font) # todo: Now we're using RichTextLabel so we need ability to get all possible typefaces to set the overrides


func _on_meta_clicked(meta) -> void:
  print(meta)

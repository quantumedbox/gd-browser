extends Node
# Encapsulated page unit, representing generic document structure

# todo: Reuse RequestNodes in n_HTTPRequestQueue
# todo: URL Resource caching singleton


onready var n_DOM := find_node("DOM")
onready var n_HTTPRequestQueue := find_node("HTTPRequestQueue")

var url: String setget _private_setter
var title: String = "Untitled Page"


func request_document(url_: String) -> void:
  # Await!
  assert(not url_.empty())
  url = url_
  print_debug("Getting document from: %s" % self.url)
  var request_node := preload("res://scenes/RequestNode.tscn").instance().init(self.url) as Node
  self.n_HTTPRequestQueue.add_child(request_node)
  yield(request_node, "finished")
  _process_page_request_response(request_node.result, request_node.response_code, request_node.headers, request_node.body)
  self.n_HTTPRequestQueue.remove_child(request_node)
  request_node.queue_free()


func request_image(url_: String): # -> ?Image
  # Await!
  print_debug("Getting image from: %s" % url_)
  var request_node := preload("res://scenes/RequestNode.tscn").instance().init(url_) as Node
  self.n_HTTPRequestQueue.add_child(request_node)
  yield(request_node, "finished")
  var image = _process_image_request_response(request_node.result, request_node.response_code, request_node.headers, request_node.body)
  self.n_HTTPRequestQueue.remove_child(request_node)
  request_node.queue_free()
  if not image:
    return null
  else:
    return image


func render_to(canvas: Container) -> void:
  _render_dom(self.n_DOM.get_child(0), canvas)


func _process_page_request_response(result: int, response_code: int, headers: PoolStringArray, body: PoolByteArray) -> void:
  # todo: Make it return Container node tree, will be neccessary for implementing tabs
  # todo: Method to parse header information
  #       In particular it might be useful for getting info about document type that is returned
  if result != OK:
    push_error("Error on request: %s: %s" % [result, Shared.HTTPErrorToText[result]])
    return
  if response_code != 200:
    push_error("Response code: %s" % response_code)
    return

  # todo: It could be beneficial to implement iterator mechanism to bypass need to create so many intermediate dictionaries and arrays
  # todo: Check whether gd-gumbo is present and if not - ignore HTML
  var html_parser := preload("res://bin/gd-gumbo.gdns").new()
  html_parser.stop_on_first_error = false
  var body_parsed := html_parser.parse(body.get_string_from_utf8()) as Dictionary
  html_parser.free()
  if body_parsed.empty():
    # Error in gd-gumbo represented by empty dict currently
    push_error("Invalid HTML document")
    return

  # if OS.has_feature("debug"):
  #   Shared.dump_node_tree(body_parsed)

  _populate_tree(self.n_DOM, body_parsed)
  # _render_dom(self.n_DOM.get_child(0), self.n_Canvas)


func _process_image_request_response(result: int, response_code: int, headers: PoolStringArray, body: PoolByteArray): # -> ?Image
  # todo: Should it return ImageTexture directly?
  if result != OK:
    push_error("Error on request: %s: %s" % [result, Shared.HTTPErrorToText[result]])
    return null
  if response_code != 200:
    push_error("Response code: %s" % response_code)
    return null

  var image := Image.new()
  var err := image.load_png_from_buffer(body) # todo: Don't guess the format, infer it
  if err != OK:
    push_error("Could not load image, error code: %s" % err) # todo: Godot errors to text
    return null
  return image


func _populate_tree(root: Node, desc: Dictionary) -> void:
  # todo: Passing url string around recursively is kinda lame
  var this: Node = null

  assert("type" in desc)

  match desc["type"]:
    "document":
      var node := DomDocument.new() as DomDocument
      node.url = self.url
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
          node.add_child(attr_node)
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
      _populate_tree(this, child)


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
      self.title = DomInterface.get_text_content(node)

    "meta", "base", "head", "link", "style":
      # Ignored metadata tags
      pass

    "a":
      # Hyperlink
      var text_content = DomInterface.get_text_content(node)
      if text_content:
        var text_node := preload("res://scenes/Text.tscn").instance()
        text_node.bbcode_text = "[url=%s]%s[/url]" % [DomInterface.get_attrbiute(node, "href"), text_content]
        _apply_text_style_by_tag(text_node, node.tag_name)
        Shared.ok(text_node.connect("meta_clicked", self, "_on_meta_clicked"))
        page_canvas.add_child(text_node)

    "div", "h1", "p", "b":
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

    "img":
      # Image node
      var src = DomInterface.get_attrbiute(node, "src")
      if src:
        var image = request_image(self.url + '/' + src) # todo: URL path validation, in general gotta read about URL spec
        if image is GDScriptFunctionState:
          image = yield(image, "completed")
        if image:
          var image_node := preload("res://scenes/Image.tscn").instance()
          var texture := ImageTexture.new()
          # image.lock()
          texture.create_from_image(image)
          # image.unlock()
          image_node.texture = texture
          page_canvas.add_child(image_node)
        else:
          # Fallback to alt text
          var text_content = DomInterface.get_attrbiute(node, "alt")
          if text_content:
            var text_node := preload("res://scenes/Text.tscn").instance()
            text_node.bbcode_text = text_content
            page_canvas.add_child(text_node)

    _:
      # For now unknown tags are used for propagation further down the tree
      for child in node.get_children():
        if child is DomElement:
          _render_node(child, page_canvas)


static func _apply_text_style_by_tag(node: RichTextLabel, tag: String) -> void:
  match tag:
    "h1":
      var font := FontManager.request_font(FontManager.DEFAULT_FAMILY, FontManager.DEFAULT_TYPEFACE, 26)
      node.set("custom_fonts/normal_font", font) # todo: Now we're using RichTextLabel so we need ability to get all possible typefaces to set the overrides
    "b":
      var font := FontManager.request_font(FontManager.DEFAULT_FAMILY, "Bold")
      node.set("custom_fonts/normal_font", font)


func _on_meta_clicked(meta) -> void:
  print(meta)


func _private_setter(_any) -> void:
  pass

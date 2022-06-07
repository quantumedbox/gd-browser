extends Node
## Encapsulated page unit, representing generic document structure

# todo: Reuse RequestNodes in n_HTTPRequestPool
# todo: URL Resource caching singleton
# todo: Make image nodes load in order, currently they're loaded based on where their image data is retrieved
# todo: Weakref to scene node to which page is rendered, as its needed for redrawing
#       Better yet to implement it via signal
# todo: Rework temporary resource strategy to allow shared resources between pages

# Used to say the Page owner that it wants to get to the new url
# (url: URL.URLObject)
signal page_requested(url)


onready var n_DOM := find_node("DOM")
onready var n_HTTPRequestPool := find_node("HTTPRequestPool")
onready var n_ScriptPool := find_node("ScriptPool")

var url setget _private_setter # todo: Should it be here? We could infer from URL  member of document node in DOM tree
var title: String = "Untitled Page" # todo: Infer directly from DOM, as this way any change to title node will not necessarily update this value

# Used for storing temporary files related to this particular page, should not clash with any other page's path, nor pollute already existing directories on filesystem
var _temp_dir: String setget _private_setter


func request_file(url_: URL.URLObject) -> Resource: # ?RequestNode.RequestResult
  var request_node := preload("res://scenes/RequestNode.tscn").instance()
  self.n_HTTPRequestPool.add_child(request_node)
  var err = request_node.request_get(url_)
  if err != OK:
    push_error("Error on HTTP request while getting, error code: %s, url: %s" % [err, url_.to_urlstring()])
    return null
  var request = yield(request_node, "finished")
  while request is GDScriptFunctionState:
    request = yield(request, "completed")
  self.n_HTTPRequestPool.remove_child(request_node)
  request_node.queue_free()
  if request.result != OK:
    push_error("Error on request: %s: %s" % [request.result, Shared.HTTPErrorToText[request.result]])
    return null
  if request.response_code != 200:
    # todo: There's more to that in response codes that that
    push_error("Response code %s at requesting %s" % [request.response_code, url_.to_urlstring()])
    return null
  return request


func request_document(url_: URL.URLObject) -> bool:
  print_debug("Getting document from: %s" % url_.to_urlstring())
  url = url_
  var request_result = request_file(url_)
  while request_result is GDScriptFunctionState:
    request_result = yield(request_result, "completed")
  if request_result == null:
    return false
  # todo: Method to parse header information
  #       In particular it might be useful for getting info about document type that is returned
  # todo: It could be beneficial to implement iterator mechanism to bypass need to create so many intermediate dictionaries and arrays
  # todo: Check whether gd-gumbo is present and if not - ignore HTML
  var html_parser := preload("res://bin/gd-gumbo.gdns").new()
  html_parser.stop_on_first_error = false
  var body_parsed := html_parser.parse(request_result.body.get_string_from_utf8()) as Dictionary
  html_parser.free()
  if body_parsed.empty():
    # Error in gd-gumbo represented by empty dict currently
    push_error("Invalid HTML document")
    return false
  _populate_tree(self.n_DOM, body_parsed)
  _resolve_scripts(self.n_DOM.get_child(0))
  return true


func request_image(url_: URL.URLObject) -> Image:
  print_debug("Getting image from: %s" % url_.to_urlstring())
  var request_result = request_file(url_)
  while request_result is GDScriptFunctionState:
    request_result = yield(request_result, "completed")
  if request_result == null:
    return null
  # todo: Should it return ImageTexture directly?
  var image := Image.new()
  # there's Image::load method, but it only works on saved images, is probably alright to do so
  var err := image.load_png_from_buffer(request_result.body) # todo: Don't guess the format, infer it
  if err != OK:
    push_error("Could not load image, error code: %s" % err) # todo: Godot errors to text
    return null
  return image


func request_scene(url_: URL.URLObject): # -> ?String
  # todo: Check whether it's valid TSCN syntax, at least by trying to parse heading
  print_debug("Getting scene from: %s" % url_.to_urlstring())
  var request_result = request_file(url_)
  while request_result is GDScriptFunctionState:
    request_result = yield(request_result, "completed")
  if request_result == null:
    return null
  var scene_path := Shared.make_temp_dir(self._temp_dir)
  return _resolve_scene_ext_resources(url_, request_result, scene_path)


func render_to(canvas: Container) -> void:
  _render_dom(self.n_DOM.get_child(0), canvas) # todo: Make DOM node be the Document itself?


func _populate_tree(root: Node, desc: Dictionary) -> void:
  # todo: Passing url string around recursively is kinda lame
  var this: Node = null

  match desc["type"]:
    "document":
      var node := DomDocument.new() as DomDocument
      node.url = self.url.to_urlstring()
      var doctype_node := DomDocumentType.new() as DomDocumentType
      if "public_identifier" in desc:
        doctype_node.publicId = desc["public_identifier"]
      if "system_identifier" in desc:
        doctype_node.systemId = desc["system_identifier"]
      node.add_child(doctype_node)
      root.add_child(node)
      this = node

    "element":
      var node: DomElement = null
      match desc["tag"]:
        "script":
          node = DomHTMLScriptElement.new()
        _:
          node = DomElement.new()
      node.tag_name = desc["tag"]
      if "attributes" in desc:
        var desc_attribs := desc["attributes"] as Dictionary
        for attr in desc_attribs:
          var attr_node := DomAttr.new() as DomAttr
          attr_node.attr_name = attr
          attr_node.attr_value = desc_attribs[attr]
          node.add_child(attr_node)
      root.add_child(node)
      this = node

    "text":
      var node := DomText.new() as DomText
      node.data = desc["text"]
      root.add_child(node)
      this = node

    "comment":
      # todo: Technically valid node in dom, but not sure whether we really need it
      pass
    _:
      push_error("Node %s unimplemented" % desc["type"])
      return

  if "children" in desc:
    assert(desc["children"] is Array)
    for child in desc["children"]:
      _populate_tree(this, child)


func _render_dom(node: DomDocument, page_canvas: Container) -> void:
  ## Naive and incorrect
  for child in node.get_children():
    if child.node_type == DomNode.ELEMENT_NODE and child.tag_name == "html":
      _render_element(child, page_canvas)


func _render_node(node: DomNode, page_canvas: Container) -> void:
  ## Generic dispatcher
  if node.node_type == DomNode.ELEMENT_NODE:
    _render_element(node, page_canvas)
  elif node.node_type == DomNode.TEXT_NODE:
    var text_node := preload("res://scenes/Text.tscn").instance()
    text_node.bbcode_text = node.data
    page_canvas.add_child(text_node)


func _render_element(node: DomElement, page_canvas: Container) -> void:
  # todo: Redo, too noisy
  # todo: Sectioning tags
  match node.tag_name:
    "title":
      self.title = node.text_content

    "meta", "base", "head", "link", "style":
      # Ignored metadata tags
      pass

    "a":
      # Hyperlink
      var text_content = node.text_content
      if text_content != null:
        var text_node := preload("res://scenes/Text.tscn").instance()
        text_node.bbcode_text = "[url=%s]%s[/url]" % [node.get_attrbiute("href"), text_content]
        _apply_text_style_by_tag(text_node, node.tag_name)
        Shared.ok(text_node.connect("meta_clicked", self, "_on_link_meta_clicked"))
        page_canvas.add_child(text_node)

    "blockquote":
      # Quote block
      # todo: Test
      var text_content = node.text_content
      if text_content != null:
        var text_node := preload("res://scenes/Text.tscn").instance()
        text_node.bbcode_text = "[quote]%s[/quote]" % text_content
        _apply_text_style_by_tag(text_node, node.tag_name)
        page_canvas.add_child(text_node)

    "ul":
      # Unordered list
      var ul_container := VBoxContainer.new()
      for child in node.get_children():
        if child.node_type == DomNode.ELEMENT_NODE:
          _render_element_ul(child, ul_container)
      page_canvas.add_child(ul_container)

    "div", "h1", "p", "b":
      # todo: <div> and alike should collect child nodes into itself, creating single container object rather than separate ones
      # Text content elements
      var text_content = node.text_content
      if text_content != null:
        var text_node := preload("res://scenes/Text.tscn").instance()
        text_node.bbcode_text = text_content
        _apply_text_style_by_tag(text_node, node.tag_name)
        page_canvas.add_child(text_node)
      for child in node.get_children():
        if child.node_type == DomNode.ELEMENT_NODE:
          _render_node(child, page_canvas)

    "img":
      # Image node
      var src = node.get_attrbiute("src")
      if src != null:
        var image_node := preload("res://scenes/Image.tscn").instance()
        page_canvas.add_child(image_node) # todo: The fact that we leave node in the tree to then delete on resuming when HTTP request is done might potentially create problems, for example, some parts referencing it, while it's not in valid state.
        # todo: DomHTMLImageElement interface and respecting of `complete` value
        var image = request_image(URL.parse(src, self.url))
        while image is GDScriptFunctionState:
          image = yield(image, "completed")
        if image != null:
          var texture := ImageTexture.new()
          texture.create_from_image(image)
          image_node.texture = texture
        else:
          # Fallback to alt text, if present
          # todo: Test
          var text_content = node.get_attrbiute("alt")
          if text_content != null:
            var text_node := preload("res://scenes/Text.tscn").instance()
            text_node.bbcode_text = text_content
            page_canvas.add_child_below_node(text_node, image_node)
            page_canvas.remove_child(image_node)
            image_node.queue_free()

    "embed":
      var type = node.get_attrbiute("type")
      if type != null:
        if type == "application/godot-scene":
          var src = node.get_attrbiute("src")
          if src != null:
            var scene_node := preload("res://scenes/Subscene.tscn").instance()
            page_canvas.add_child(scene_node) # todo: Placed in the tree while being in possibly invalid state, could be problematic
            var scene = request_scene(URL.parse(src, self.url))
            while scene is GDScriptFunctionState:
              scene = yield(scene, "completed")
            if scene != null:
              var scene_scene := ResourceLoader.load(scene)
              if scene_scene.can_instance():
                scene_node.emplace(scene_scene.instance())
              else:
                push_error("Cant instance scene %s" % URL.parse(src, self.url).to_urlstring())

    _:
      # For now unknown tags are used for propagation further down the tree
      for child in node.get_children():
        if child.node_type == DomNode.ELEMENT_NODE:
          _render_node(child, page_canvas)


func _render_element_ul(node: DomElement, page_canvas: Container) -> void:
  match node.tag_name:
    "li":
      var item = preload("res://scenes/ItemList.tscn").instance()
      for child in node.get_children():
        if child.node_type == DomNode.ELEMENT_NODE:
          _render_element(child, item.get_child(1))
      page_canvas.add_child(item)
    _: _render_element(node, page_canvas)


static func _apply_text_style_by_tag(node: RichTextLabel, tag: String) -> void:
  if tag.length() == 2 and tag[0] == "h" and tag[1].is_valid_integer():
    # Headings tags of different size
    var font := FontManager.request_font(FontManager.DEFAULT_FAMILY, FontManager.DEFAULT_TYPEFACE, FontManager.DEFAULT_SIZE + tag[1].to_int() * 2)
    node.set("custom_fonts/normal_font", font) # todo: Now we're using RichTextLabel so we need ability to get all possible typefaces to set the overrides
    return
  match tag:
    "b":
      var font := FontManager.request_font(FontManager.DEFAULT_FAMILY, "Bold")
      node.set("custom_fonts/normal_font", font)


func _resolve_scripts(document: DomDocument) -> void:
  for script in document.get_elements_by_tag_name("script"):
    if script.type == "text/gdscript":
      var src_attr = script.get_attrbiute("src")
      if src_attr != null:
        Shared.unimplemented()
        continue
      var source = script.text
      if not source.empty():
        # todo: Could we prevent need to create files?
        var path := Shared.write_temp_file(self._temp_dir, source)
        var script_instance := load(path).new() as GDScriptScript
        if script_instance == null:
          push_error("Script within document doesn't extend GDScriptScript")
          continue
        script_instance.document = document
        n_ScriptPool.add_child(script_instance)
        print_debug("Added one running gdscript script")


func _resolve_scene_ext_resources(scene_url: URL.URLObject, request: Resource, scene_path: String, subpath: String = "") -> String:
  # todo: Compile regex only once
  # todo: Resolve extern resource scenes recursively
  var input := request.body.get_string_from_utf8() as String
  var output := String()
  var ext_resource_regex := RegEx.new()
  Shared.ok(ext_resource_regex.compile("\\[ext_resource.+path=\\\"(?<path>.+?)\\\".+\\]"))
  for result in ext_resource_regex.search_all(input):
    var resource_url = Shared.deepcopy(scene_url)
    resource_url.path = resource_url.path.get_base_dir()
    var resource_path := result.get_string("path") as String
    var local_resource_path: String
    if resource_path.find("res://") != -1:
      # Absolute path
      var resless_path = resource_path.substr(6, resource_path.length())
      resource_url.path += '/' + resless_path
      local_resource_path = "%s/%s" % [scene_path, resless_path]
    else:
      # Relative path
      if not subpath.empty():
        resource_url.path += '/' + subpath
        local_resource_path = "%s/%s" % [scene_path, resource_path]
      else:
        local_resource_path = "%s/%s/%s" % [scene_path, subpath, resource_path]
      resource_url.path += '/' + resource_path
    var request_result = request_file(resource_url)
    output += input.substr(0, result.get_start("path"))
    output += local_resource_path
    input = input.substr(result.get_end("path"), input.length())
    while request_result is GDScriptFunctionState:
      request_result = yield(request_result, "completed")
    if request_result == null:
      # todo: Should we do something? Running the scene will most likely fail in this case anyway
      continue
    if not Shared.write_file(local_resource_path, request_result.body):
      continue
  output += input
  return Shared.write_temp_file(scene_path, output, "tscn")


func _on_link_meta_clicked(urlstring) -> void:
  var url_result = URL.parse(urlstring, self.url)
  if url_result.failure:
    push_error("Ill-formed url")
    return
  emit_signal("page_requested", url_result)


func _init() -> void:
  var path := Shared.make_temp_dir("res://temp")
  if path != "":
    print_debug("Created temporary directory at %s" % path)
    _temp_dir = path


func _notification(what) -> void:
  if what == NOTIFICATION_PREDELETE:
    # If this doesn't trigger, next startup will free all the temp files instead
    print_debug("Trying to free temporary directory %s" % self._temp_dir)
    Shared.free_dir(self._temp_dir)


func _private_setter(_any) -> void:
  assert(false, "Private setter is used")

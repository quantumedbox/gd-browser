extends Node
## Workaround for Godot's inability to resolve dependency trees

static func get_text_content(node: DomNode): # -> ?String:
  ## https://dom.spec.whatwg.org/#dom-node-textcontent
  var result: String = ""
  for child in node.get_children():
    if child is DomElement:
      var child_text_content = get_text_content(child)
      if child_text_content:
        result += child_text_content
    elif child is DomAttr:
      result += child.attr_value
    elif child is DomCharacterData:
      result += child.data
  
  if result.empty():
    return null
  else:
    return result

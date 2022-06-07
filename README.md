# gd-browser Simplistic Browser

## Building
Currently two GDNative modules are required that are adjacent to gd-browser: [gd-html-parser](https://github.com/quantumedbox/gd-html-parser) and [gd-url-parser](https://github.com/quantumedbox/gd-url-parser), you need to compile those and place their `bin` folder output into `project` folder, where Godot project is located.

Prebuilt binaries are possible in the future, but it's currently not in any stable state for that.

## Demo
Current gd-browser state:

![screenshot of https://serenityos.org](/assets/images/gd-browser.png)

Basic support for GDScript in `<script>` elements

![demonstration screenshot](/assets/images/script.png)

## TODO
- Interpreting of basic sectioning elements
- Simple attributes, such as links
- Inline text tags for styling of text, probably by using RichTextLabel and BBCode
- Parsing of HTTP response headers
- Make it pretty
- Make it snappy
- Standardize GDScript document scripting
- Ability to load Godot scenes as documents, and integrate them into page directly
- project.godot in embed, should direct to main scene, possibly respecting settings if possible
- Resolution of embedded scene's scripts `load()` and `preload()` functions, they need to point to local storage instead of `res://`

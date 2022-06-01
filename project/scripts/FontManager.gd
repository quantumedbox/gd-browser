extends Node
## Used for caching and reusing of Font resources with different parameters

# todo: Reference count fonts so that memory could be freed when unused

# Dictionary<String, Dictionary<String, Variant>
var _font_cache: Dictionary

const DEFAULT_FAMILY := "Roboto"
const DEFAULT_TYPEFACE := "Regular"
const DEFAULT_SIZE := 16


func _ready() -> void:
  var default_font := preload("res://resources/DefaultFont.tres") as Font
  _font_cache[DEFAULT_FAMILY] = {
    "font-family": "sans-serif",
    "path": "res://assets/fonts/roboto/",
    "typeface-data": {
      "Regular": default_font.font_data,
    },
    "typeface-variants": {
      "Regular": {
        default_font.size: default_font,
      }
    }
  }


func request_font(family: String = DEFAULT_FAMILY, typeface: String = DEFAULT_TYPEFACE, size: int = DEFAULT_SIZE) -> Font:
  # todo: Quite slow, need to find alternative
  if not family in _font_cache:
    family = DEFAULT_FAMILY
  var family_dict := _font_cache[family] as Dictionary
  var family_typeface_variants := family_dict["typeface-variants"] as Dictionary
  if not typeface in family_typeface_variants:
    if not _try_load_typeface(family, family_dict, typeface):
      typeface = DEFAULT_TYPEFACE
  var family_typeface := family_typeface_variants[typeface] as Dictionary
  if not size in family_typeface:
    var font := _create_font_variant(family_dict["typeface-data"][typeface], size)
    family_typeface[size] = font
    return font
  return family_typeface[size]


static func _create_font_variant(font_data: DynamicFontData, size: int) -> Font:
  var font := DynamicFont.new()
  font.size = size
  font.font_data = font_data
  return font


static func _try_load_typeface(family: String, family_dict: Dictionary, typeface: String) -> bool:
  # todo: Need to detect whether typeface file actually exists
  assert("path" in family_dict)
  var typeface_data := DynamicFontData.new()
  typeface_data.font_path = family_dict["path"] + family + "-" + typeface + ".ttf" # todo: Kinda really meh assumption?
  family_dict["typeface-data"][typeface] = typeface_data
  family_dict["typeface-variants"][typeface] = Dictionary()
  # todo: Should be able to return failure
  return true

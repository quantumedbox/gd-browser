extends Node
## URL Interface
## https://url.spec.whatwg.org/
## https://en.wikipedia.org/wiki/Uniform_Resource_Identifier

var _regex_parser: RegEx

class URLObject extends Resource:
  var failure: bool

  ## URI = scheme ":" ["//" [userinfo "@"] host [":" port]] path ["?" query] ["#" fragment]
  var scheme: String
  var userinfo: String
  var host: String
  var port: String # Integer representation is 2^16 - 1 at max
  var path: String
  var query: String
  var fragment: String

  func to_urlstring() -> String:
    assert(not self.failure)
    var result: String = ""
    if not self.scheme.empty():
      result += self.scheme + "://"
    # todo: Userinfo
    if not self.host.empty():
      result += self.host
    if not self.port.empty():
      result += ":" + self.port
    if not self.path.empty():
      result += self.path
    # todo: Query and fragment
    return result

  func subpaths() -> PoolStringArray:
    assert(not self.failure)
    return self.path.split('/')

  func query_parts(sep="&") -> PoolStringArray:
    assert(not self.failure)
    return self.query.split(sep)

  func is_relative() -> bool:
    # https://www.w3.org/TR/WD-html40-970917/htmlweb.html#h-5.1.2
    assert(not self.failure)
    return self.scheme.empty() and self.host.empty() and self.port.empty()

  static func new_failure() -> URLObject:
    var result := URLObject.new()
    result.failure = true
    return result


func _init() -> void:
  _regex_parser = RegEx.new()
  ## https://stackoverflow.com/questions/27745/getting-parts-of-a-url-regex
  # todo: Technically isn't fully compliant to URI, as for example `ftp:path` isn't parsed with this implementation, we might consider doing something simper to maintain + more robust
  Shared.ok(self._regex_parser.compile("^(([^:\\/\\s]+):\\/?\\/?(([^\\/\\s@]*)@)?([^\\/@:]*)?:?(\\d+)?)?(\\/[^?]*)?(\\?([^#]*))?(#([\\s\\S]*))?$"))


func parse(urlstring: String, base: URLObject = null) -> URLObject:
  assert(self._regex_parser != null and self._regex_parser.is_valid())
  if urlstring.find("://") == -1:
    assert(not base.failure)
    # Inferring relative path
    urlstring = base.scheme + "://" + base.host + ":" + base.port + base.path + "/" +urlstring
  var parse_result := self._regex_parser.search(urlstring)
  if parse_result == null:
    return URLObject.new_failure()
  else:
    assert(parse_result.get_group_count() == 11)
    var result := URLObject.new()
    result.scheme = parse_result.get_string(2)
    result.userinfo = parse_result.get_string(4)
    result.host = parse_result.get_string(5)
    result.port = parse_result.get_string(6)
    if result.port.empty():
      match result.scheme:
        "ftp": result.port = "21"
        "http": result.port = "80"
        "https": result.port = "443"
        "ws": result.port = "80"
        "wss": result.port = "443"
    result.path = parse_result.get_string(7)
    result.query = parse_result.get_string(9)
    result.fragment = parse_result.get_string(11)
    # todo: Check whether it's well-formed
    return result

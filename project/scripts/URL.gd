extends Node
## URL Interface
## https://url.spec.whatwg.org/

var n_URLParser: Node


class URLObject extends Resource:
  ## "scheme://host:port/path?query#fragment"
  var failure: bool

  var scheme: String
  var host: String
  var port: String # Integer representation is 2^16 - 1 at max
  var path: String
  var query: String
  var fragment: String

  var username: String
  var password: String

  func to_urlstring() -> String:
    assert(not self.failure)
    var result: String = ""
    if not self.scheme.empty():
      result += self.scheme + "://"
    if not self.host.empty():
      result += self.host
    if not self.port.empty():
      result += ":" + self.port
    if not self.path.empty():
      result += "/" + self.path
    # todo: Problem with current method of saving separated query is that we couldn't build the url string back, as separator is lost
    # todo: Username and password
    return result

  func subpaths() -> PoolStringArray:
    assert(not self.failure)
    return self.path.split('/')

  func is_relative() -> bool:
    # https://www.w3.org/TR/WD-html40-970917/htmlweb.html#h-5.1.2
    assert(not self.failure)
    return self.scheme.empty() and self.host.empty() and self.port.empty()

  static func new_failure() -> URLObject:
    var result := URLObject.new()
    result.failure = true
    return result


func _init() -> void:
  self.n_URLParser = preload("res://bin/gd-url-parser.gdns").new()
  self.add_child(self.n_URLParser)


func parse(urlstring: String, base: URLObject = null) -> URLObject:
  if urlstring.find("://") == -1:
    # Inferring of relative path
    urlstring = base.scheme + "://" + base.host + ":" + base.port + "/" + base.path + urlstring
  if not self.n_URLParser.parse(urlstring):
    return URLObject.new_failure()
  else:
    var result := URLObject.new()
    result.scheme = self.n_URLParser.scheme
    result.host = self.n_URLParser.host
    var port = self.n_URLParser.port
    if port == "0":
      port = "" # todo: Make it null?
    result.port = port
    result.path = self.n_URLParser.path
    result.fragment = self.n_URLParser.fragment
    result.username = self.n_URLParser.username
    result.password = self.n_URLParser.password
    result.query = self.n_URLParser.query
    _default_port(result)
    # todo: Check whether it's well-formed
    return result


func parse_query(url: URLObject, sep="&") -> Array:
  assert(not url.failure)
  # todo: Test
  return n_URLParser.parse_query("&")


static func _default_port(url: URLObject) -> void:
  # https://url.spec.whatwg.org/#url-miscellaneous
  assert(not url.scheme.empty())
  if not url.port.empty():
    return
  match url.scheme:
    "ftp": url.port = "21"
    "http": url.port = "80"
    "https": url.port = "443"
    "ws": url.port = "80"
    "wss": url.port = "443"

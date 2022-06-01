extends HTTPRequest

# todo: One performance concern is the fact that Pool*Array structures are passed 3 times here, by copy all the time. Request might contain big binary files, which will absolutely tank the performance here.

signal finished

var url: String

var result: int
var response_code: int
var headers: PoolStringArray
var body: PoolByteArray


func init(url_: String) -> Node:
  url = url_
  return self


func _ready() -> void:
  assert(not self.url.empty())
  Shared.ok(self.connect("request_completed", self, "_on_request_completed"))
  var err := self.request(self.url)
  if err != OK:
    push_error("An error occurred on the HTTP request.")
    self.result = err
    self.finished = true


func _on_request_completed(result_: int, response_code_: int, headers_: PoolStringArray, body_: PoolByteArray) -> void:
  self.result = result_
  self.response_code = response_code_
  self.headers = headers_
  self.body = body_
  emit_signal("finished")

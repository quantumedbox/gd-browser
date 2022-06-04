extends HTTPRequest

signal finished

class RequestResult extends Resource:
  var result: int
  var response_code: int
  var headers: PoolStringArray
  var body: PoolByteArray

var request_result: Resource # RequestResult


func request_get(url: URL.URLObject) -> int: # Error
  assert(not url.failure)
  Shared.ok(self.connect("request_completed", self, "_on_request_completed"))
  return self.request(url.to_urlstring())


func _on_request_completed(result_: int, response_code_: int, headers_: PoolStringArray, body_: PoolByteArray) -> void:
  var result := RequestResult.new()
  result.result = result_
  result.response_code = response_code_
  result.headers = headers_
  result.body = body_
  self.request_result = result
  emit_signal("finished")

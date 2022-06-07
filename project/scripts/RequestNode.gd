extends HTTPRequest

# (result: RequestResult)
signal finished(result)

class RequestResult extends Resource:
  var result: int
  var response_code: int
  var headers: PoolStringArray
  var body: PoolByteArray


func request_get(url: URL.URLObject) -> int: # Error
  assert(not url.failure)
  Shared.ok(self.connect("request_completed", self, "_on_request_completed"))
  return self.request(url.to_urlstring())


func _on_request_completed(result: int, response_code: int, headers: PoolStringArray, body: PoolByteArray) -> void:
  var output := RequestResult.new()
  output.result = result
  output.response_code = response_code
  output.headers = headers
  output.body = body
  emit_signal("finished", output)

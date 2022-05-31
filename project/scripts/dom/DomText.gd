extends DomCharacterData
class_name DomText
## https://dom.spec.whatwg.org/#text

func init(data: String = "") -> DomText:
  self.data = data
  return self

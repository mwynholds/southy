class Southy::CheckinDocument
  attr_accessor :flight, :group, :position

  def self.parse(node)
    doc = Southy::CheckinDocument.new
    doc.group = node.find('.group')[:alt]
    digits = node.all('.position').map { |p| p[:alt].to_i }
    doc.position = digits[0] * 10 + digits[1]
    doc
  end
end
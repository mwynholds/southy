class Southy::Message
  def initialize(client, channel)
    @client = client
    @channel = channel
  end

  def reply(msg)
    @client.message channel: @channel, text: msg
  end

  def type
    @client.typing channel: @channel
  end
end

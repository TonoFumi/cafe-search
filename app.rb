require 'sinatra'
require 'line/bot'


def client
  @client ||= Line::Bot::Client.new {|client|
    
  }
end


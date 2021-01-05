require 'sinatra'
require 'line/bot'
require 'dotenv'
require 'faraday'
require 'json'

get '/' do
  'Hello'
end

post '/callback' do
  body = request.body.read

  signature = request.env['HTTP_X_LINE_SIGNATURE']
  unless client.validate_signature(body, signature)
    error 400 do 'Bad Request' end
  end

  events = client.parse_events_from(body)
  events.each do |event|
    case event
    when Line::Bot::Event::Message
      case event.type
      when Line::Bot::Event::MessageType::Text
        message = {
          type: 'text',
          text: event.message['text']
        }
        client.reply_message(event['replyToken'], message)
      when Line::Bot::Event::MessageType::Location
        # 緯度経度を取得する
        lat = event.message['latitude']
        lng = event.message['longitude']

        # ジャンルマスタAPIに投げてジャンルコードを取得する
        uri = "https://webservice.recruit.co.jp"
        req = Faraday::Connection.new(url: uri) do |conn|
          conn.adapter Faraday.default_adapter
          conn.request :url_encoded 
          conn.headers['Content-Type'] = 'application/json'
        end
        master_query = URI.encode("/hotpepper/genre/v1/?key=#{ENV['HOTPEPPER_API_KEY']}&keyword=カフェ&format=json")
        master_res = req.get(master_query)
        body_master = JSON.parse(master_res.body)
        code = body_master['results']['genre'][0]['code'] # エラー

        # 緯度経度情報をホットペッパーAPIに投げ近くのカフェ情報をLINEクライアントに返す
        query = URI.encode("/hotpepper/gourmet/v1/?key=#{ENV['HOTPEPPER_API_KEY']}&lat=#{lat}&lng=#{lng}&range=1&genre=#{code}&type=lite&format=json")
        res = req.get(query)
        body = JSON.parse(res.body)
        ret = body['results']["shop"].each_with_object([]) do |shop, urls|
          urls << shop['urls']['pc']
        end
        messages = [
          { type: 'text', text: ret[0] },
          { type: 'text', text: ret[1] },
          { type: 'text', text: ret[2] }
        ]
        client.reply_message(event['replyToken'], messages)
      end
    end
  end

  "OK"
end

private
# LINEインタフェースを設定
# 依存元のことを知っているので保守性良くない
def client
  @client ||= Line::Bot::Client.new {|config|
    config.channel_id = ENV["LINE_CHANNEL_ID"]
    config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
    config.channel_token = ENV["LINE_CHANNEL_TOKEN"]    
  }
end


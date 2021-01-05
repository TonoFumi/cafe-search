require 'sinatra'
require 'line/bot'
require 'dotenv'
require 'faraday'

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
        master_uri = "https://webservice.recruit.co.jp"
        req = Faraday::Connection.new(url: master_uri) do |conn|
          conn.adapter Faraday.default_adapter
          conn.request :url_encoded 
          #conn.response :logger # ログを出す
          conn.headers['Content-Type'] = 'application/json'
        end
        master_query = URI.encode("/hotpepper/genre/v1/?key=#{ENV['HOTPEPPER_API_KEY']}&keyword=カフェ")
        # TODO
        # ホットペッパーからnilが帰ってきてるっぽい
        # ログ出力設定
        res = req.get(master_query)
        code = res.body['genre'][0]['code'] # エラー
        #code = res['results']['genre'] # エラー
        #code = res['genre'] # genreキーがおそらくないのでnilになりエラーならない
        #code = res['genre'][0] # エラー
        #code = res['genre'][0]['code']

        # 緯度経度情報をホットペッパーAPIに投げ近くのカフェ情報をLINEクライアントに返す
        uri = "https://webservice.recruit.co.jp"
        req = Faraday::Connection.new(url: uri) do |conn|
          conn.adapter Faraday.default_adapter
          conn.request :url_encoded 
          #conn.response :logger # ログを出す
          conn.headers['Content-Type'] = 'application/json'
        end
        query = URI.encode("/hotpepper/gourmet/v1/?key=#{ENV['HOTPEPPER_API_KEY']}&lat=#{lat}&lng=#{lng}&range=1&genre=#{code}&type=lite")
        #query = URI.encode("/hotpepper/gourmet/v1/?key=#{ENV['HOTPEPPER_API_KEY']}&lat=#{lat}&lng=#{lng}&range=1")
        res = req.get(query)
        message = {
          type: 'text',
          text: res.body['shop'][0]['urls']['pc']
        }
        client.reply_message(event['replyToken'], message)
#        res.body["shop"].each_with_index do |shop, i|
#          break if i == 3
#          message = {
#            type: 'text',
#            text: shop['urls']['pc']
#          }
#          client.reply_message(event['replyToken'], message)
#        end
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


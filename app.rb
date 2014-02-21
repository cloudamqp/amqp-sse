require 'sinatra'
require 'sinatra/streaming'
require 'haml'
require 'bunny'

url = ENV['CLOUDAMQP_URL'] || "amqp://guest:guest@localhost"
B = Bunny.new url
B.start

configure do
  disable :logging
end

get '/' do
  haml :index
end

post '/publish' do
  B.with_channel do |ch|
    ch.fanout("f1").publish "Hello, world!"
  end
  204
end

get '/stream', provides: 'text/event-stream' do
  channel = B.create_channel
  q = channel.queue('', exclusive: true).bind(channel.fanout("f1"))
  stream :keep_open do |out|
    q.subscribe do |_, _, payload|
      out << "data: #{payload}\n\n"
    end

    # add a timer to keep the connection alive 
    t = Thread.new { sleep 20; out << ":\n" }
    # clean up when the user closes the stream
    out.callback do
      t.kill
      channel.close
    end
    out.errback do |err|
      puts "errback", err
      t.kill
      channel.close
    end
  end
end

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
  puts "Threads: #{Thread.list.size}"
  B.with_channel do |ch|
    ch.fanout("f1").publish "Hello, world!"
  end
  204
end

get '/stream', provides: 'text/event-stream' do
  channel = B.create_channel
  q = channel.queue('', exclusive: true).bind(channel.fanout("f1"))
  stream do |out|
    # add a timer to keep the connection alive 
    t = Thread.new { sleep 50; out << ":\n" }
    # clean up when the user closes the stream
    out.callback do
      puts "callback"
      t.kill
      channel.close
    end
    out.errback do |err|
      puts "errback"
      t.kill
      channel.close
    end
    q.subscribe(block: true) do |_, _, payload|
      out << "data: #{payload}\n\n"
    end
  end
end

require 'sinatra'
require 'sinatra/streaming'
require 'haml'
require 'amqp'

enable :loggning
configure do
  EM.next_tick do
    AMQP.connection = AMQP.connect ENV['CLOUDAMQP_URL'] || 'amqp://guest:guest@localhost'
  end
end

get '/' do
  haml :index
end

post '/publish' do
  AMQP::Channel.new do |channel|
    channel.fanout("f1").publish "Hello, world!"
  end
  204
end

get '/stream', provides: 'text/event-stream' do
  stream :keep_open do |out|
    AMQP::Channel.new do |channel|
      channel.queue do |queue|
        queue.bind(channel.fanout("f1")).subscribe do |payload|
          out << "data: #{payload}\n\n"
        end
      end
      timer = EM.add_periodic_timer(20) { out << ":\n" } 
      out.callback do
        p 'closing'
        timer.cancel
        channel.close
      end
    end
  end
end

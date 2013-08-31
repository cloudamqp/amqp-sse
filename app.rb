require 'sinatra'
require 'sinatra/streaming'
require 'haml'
require 'amqp'

configure do
  EM.next_tick do
    # Connect to CloudAMQP and set the default connection
    url = ENV['CLOUDAMQP_URL'] || "amqp://guest:guest@localhost"
    AMQP.connection = AMQP.connect url
    PUB_CHAN = AMQP::Channel.new
  end
end

get '/' do
  haml :index
end

post '/publish' do
  # publish a message to a fanout exchange
  PUB_CHAN.fanout("f1").publish "Hello, world!"
  204
end

get '/stream', provides: 'text/event-stream' do
  stream :keep_open do |out|
    AMQP::Channel.new do |channel|
      channel.queue('', exclusive: true) do |queue|
        # create a queue and bind it to the fanout exchange
        queue.bind(channel.fanout("f1")).subscribe do |payload|
          out << "data: #{payload}\n\n"
        end
      end

      # add a timer to keep the connection alive 
      timer = EM.add_periodic_timer(20) { out << ":\n" } 

      # clean up when the user closes the stream
      out.callback do
        timer.cancel
        channel.close
      end
    end
  end
end

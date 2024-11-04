$stdout.sync = true
$stderr.sync = true

require "./app"
run Sinatra::Application

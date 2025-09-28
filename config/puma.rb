max_threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count

port ENV.fetch("PORT") { 3000 }
environment ENV.fetch("RAILS_ENV") { "development" }
pidfile ENV.fetch("CUSTOM_WEB_PID_FILE") { "/tmp/web_server.pid" }

workers ENV.fetch("WEB_CONCURRENCY") { 2 }
preload_app!

directory ENV.fetch("STACK_PATH") { "." }

socket = ENV["CUSTOM_WEB_SOCKET_FILE"]
if socket.nil? || socket.empty?
  bind "unix:///tmp/web_server.sock"
elsif socket =~ /\A[a-z]+:\/\//
  bind socket # already a full URI (unix://, tcp://, ssl://, http://, https://)
else
  bind "unix://#{File.expand_path(socket)}"
end

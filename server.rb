require 'sinatra'
require 'sinatra/streaming'
require 'pry'
require './channel'
require './samples/sleep'
require './samples/click'
require './samples/hover'
require './draw/draw'
require 'puma'
Puma::Server.class_eval{def cork_socket*;end;def uncork_socket*;end}

set :bind, '0.0.0.0'
set :server_settings, { Threads: '0:128' }

get '/' do
  samples = %w(clock1 clock2 click1 click2 countdown hover draw)
  out = '<h1>samples</h1>'
  samples.each do |name|
    out << "<a href='/#{name}'>#{name}</a><br>"
  end
  out
end

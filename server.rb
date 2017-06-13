require 'sinatra'
require 'sinatra/streaming'
require 'pry'
require './channel'
require './samples/sleep'
require './samples/click'
require './samples/hover'
require './draw/draw'

get '/' do
  samples = %w(clock1 clock2 click1 click2 countdown hover draw)
  out = '<h1>samples</h1>'
  samples.each do |name|
    out << "<a href='/#{name}'>#{name}</a><br>"
  end
  out
end
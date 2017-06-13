require 'sinatra'
require 'sinatra/streaming' # gem sinatra-contrib
require 'pry'
require './channel'
require './samples/sleep'
require './samples/click'
require './samples/hover'

get '/' do
  samples = %w(clock1 clock2 click1 click2 countdown hover)
  out = '<h1>samples</h1>'
  samples.each do |name|
    out << "<a href='/#{name}'>#{name}</a><br>"
  end
  out
end

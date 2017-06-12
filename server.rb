require 'sinatra'
require 'sinatra/streaming' # gem sinatra-contrib
require 'pry'
require './channel'
require './samples/sleep'
require './samples/click'
require './samples/hover'


get '/session_test' do
  stream do |out|
    begin
      channel = Channel.new
      out.write %(
      <style>iframe{display:none}input[type=image]{width:500px;height:200px;border:1px solid red}</style>
        <iframe name=a></iframe>
        <div class=canvas></div><form action='#{channel.path}' target=a><input type=image name=coord></form>
      )
      loop do
         coord = channel.deq timeout: 10
         unless coord
           out.write "\n"
           next
         end
         out.write %(<p>#{coord}</p>)
      end
    ensure
      p :closed
      channel.close
    end
  end
end

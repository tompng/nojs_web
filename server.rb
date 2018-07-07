require 'sinatra'
require 'sinatra/streaming'
require 'pry'
require './channel'
require './samples/sleep'
require './samples/click'
require './samples/hover'
require './draw/draw'
require './page'
require './samples/vdomtest'
require './samples/todo'
require 'puma'

# disable TCP_CORK for linux
Puma::Server.class_eval{def cork_socket*;end;def uncork_socket*;end}

set :bind, '0.0.0.0'
set :server_settings, { Threads: '0:128' }

get '/' do
  out = %(
    <meta charset=utf-8>
    <style>
      a{
        margin:10px;padding: 10px 40px;
        border-radius:4px;
        font-size:24px;
        box-shadow:0 0 2px gray;
        display:inline-block;
        color:black;
        text-decoration:none;
      }
      a:hover{background:#eee;}
      a:active{background:#ddd}
    </style>
    <h1>デモ</h1>
    <a id=drawdemo href='/draw'>お絵かきアプリのデモ</a>
    <hr>
    <h2>その他のデモ</h2>
  )
  samples = %w(clock1 clock2 click1 click2 countdown hover)
  samples.each do |name|
    out << "<a href='/#{name}'>#{name}</a>"
  end
  out << %(<div>ブラウザによって動作しないことがあります(スマホなど)</div>)
  out
end

__END__

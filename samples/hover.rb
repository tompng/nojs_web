
q=Queue.new

get '/hover' do
  x = params['x'].to_i
  y = params['y'].to_i
  q << [x, y, 'hover']
end
get '/click' do
  x = params['coord.x'].to_i
  y = params['coord.y'].to_i
  q << [x, y, 'click']
end

cellsize=10
cellnum=30
hovers = ->{
  cellnum.times.map{|i|
    cellnum.times.map{|j|
      "<input type=image class='hover' id='hover_#{i}_#{j}' style='left:#{i*cellsize};top:#{j*cellsize};'>"
    }
  }.join
}

get '/' do
  stream do |out|
    id = 0
    message = ->message{
      out.write "<style>.message#msg#{id}{display:none}</style>"
      id += 1
      out.write %(<div class=message id='msg#{id}'>#{message}</div>)
      out.flush
    }
    xymessage = ->x,y{
      out.write "<style>.message#msg#{id}{display:none}</style>"
      id += 1
      out.write %(<div class=message id='msg#{id}'>
        <svg width=300 height=300 viewBox="0 0 300 300">>
          <rect x="#{x}" y="#{y}" fill="#ffff00" stroke="#ff0000" width="10" height="10"/>
          <text x="10" y="20">you clicked #{x} #{y}</text>
        </svg>
      </div>)
      out.flush
    }
    hoverstyle = ->x,y{
      "#hover_#{x}_#{y}:hover{background-image:url('/hover?x=#{x}&y=#{y}&r=#{rand}');}\n"
    }
    hoverinitialstyle = ->{
      "<style>"+cellnum.times.flat_map{|x|cellnum.times.map{|y|hoverstyle.call x, y}}.join+"</style>"
    }
    hovermessage = ->x,y{
      out.write "<style>#{hoverstyle.call x, y}.hover{display:block}</style>"
    }
    iframe = "<iframe name=a></iframe>"
    style = %(<style>
      body{user-select: none;}
      iframe{position:fixed;width:1;height:1;left:-5;top:-5;border:none;}
      .canvas{border:1px solid red;}
      .canvas,input{position:fixed;left:0;top:0;width:300;height:300;}
      input{opacity:0.01;z-index:10000;}
      .message{position:fixed;left:0;top:0;}
      .hover{position:fixed;width:#{cellsize};height:#{cellsize};z-index:10000;box-shadow:0 0 1px red;}
    </style>)
    canvas = "<div class=canvas></div><form action='/click' target=a><input type=image name=coord></form>"
    canvas=hovers.call
    out.write "#{iframe}#{style}#{hoverinitialstyle.call}#{canvas}"
    out.flush
    message.call 'click anywhere'
    prev=nil
    loop do
      break if out.closed?
      xy = Timeout.timeout(1){q.deq} rescue nil
      if xy
        x, y = xy
        hovermessage.call *prev if prev
        prev=x,y
        xymessage.call x*cellsize, y*cellsize
      end
    end
  end
end

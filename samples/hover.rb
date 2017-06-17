get '/hover' do
  stream do |out|
    channel = Channel.new
    out.write '<style>'
    out.write %(
      iframe{display:none}
      input[type=image]{
        position:absolute;left:0;top:0;width:100%;height:100%;opacity:0;
      }
      form{position:relative;height:256px;}
      .cell{
        position:absolute;width:32px;height:32px;
        box-shadow: 0 0 1px gray;
        background:silver;
      }
    )
    colors=8.times.map{8.times.map{false}}
    out.write 8.times.to_a.repeated_permutation(2).map{|i,j|
      %(
        #h_#{i}_#{j} input:hover{
          background-image:url(#{channel.path}?type=hover&i=#{i}&j=#{j}&r=#{rand})
        }
      )
    }.join
    out.write '</style>'
    out.write %(
      <iframe name=a></iframe>
      <form target=a method=post action=#{channel.path}>
    )
    out.write 8.times.to_a.repeated_permutation(2).map{|i,j|
      %(
        <div class=cell id='h_#{i}_#{j}' style='left:#{i*32};top:#{j*32};'>
          <input type=image name='h' value='#{i}/#{j}'>
        </div>
      )
    }.join
    out.write '</form>'
    prev = nil
    id = 0
    mode = true
    loop{
      cmd = channel.deq
      unless cmd
        out.write "\n"
        next
      end
      black = ->{ '#'+3.times.map { rand(0..4) }.join }
      white = ->{ '#'+3.times.map { rand(11..15).to_s(16) }.join }
      if cmd[:h]
        i, j = cmd[:h].split('/').map &:to_i
        out.write %(<p id=p#{id}>click at #{32*i+cmd['h.x'].to_i} #{32*j+cmd['h.y'].to_i}</p>)
        mode = !colors[i][j]
        colors[i][j] = mode
        out.write %(<style>
          #h_#{i}_#{j}{background:#{colors[i][j] ? black.call : white.call};}
        </style>)
        id+=1
      elsif cmd[:type]=='hover'
        i, j = [cmd[:i], cmd[:j]].map &:to_i
        colors[i][j] = mode
        out.write '<style>'
        if prev && prev != [i, j]
          out.write %(
            #h_#{prev.join '_'} input:hover{background-image:url(#{channel.path}?type=hover&i=#{prev[0]}&j=#{prev[1]}&r=#{rand})}
          )
        end
        out.write %(
          #h_#{i}_#{j}{background:#{colors[i][j] ? black.call : white.call};}
        )
        out.write '</style>'
        prev = [i, j]
        out.write %(<p id=p#{id}>hover on #{i} #{j}</p>)
        id+=1
      end
      out.write %(<style>#p#{id-6}{display:none}</style>)
    }
  end
end

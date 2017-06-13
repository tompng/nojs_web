get '/click1' do
  stream do |out|
    begin
      ch = Channel.new
      out.puts %(
        <title>countdown watch</title>
        <iframe name=a style='display:none'></iframe>
        <form action='#{ch.path}' target=a><input name=data type=submit value='buttonA'></form>
        <form action='#{ch.path}' target=a><input name=data type=submit value='buttonB'></form>
        <form action='#{ch.path}' target=a><input name=data type=submit value='buttonC'></form>
      )
      id = 1
      loop do
        btn = ch.deq
        next unless btn
        btn[:data]
        out.puts "<div id='d#{id}'>#{btn[:data]} at #{Time.now.strftime '%H:%M:%S'}</div>"
        out.puts "<style>#d#{id-1}{display:none}</style>"
        id += 1
      end
    ensure
      ch.close
    end
  end
end

get '/click2' do
  stream do |out|
    begin
      channel = Channel.new
      out.write %(
        <style>iframe{display:none}input[type=image]{width:500px;height:200px;border:1px solid red}</style>
        <iframe name=a></iframe>
        <div class=canvas></div><form action='#{channel.path}' target=a><input type=image name=coord></form>
      )
      id = 1
      loop do
         coord = channel.deq timeout: 10
         unless coord
           out.write "\n"
           next
         end
         out.write %(
           <p id='p#{id}'>(#{coord['coord.x']}, #{coord['coord.y']})</p>
           <style>#p#{id-1}{display:none}</style>
         )
         id+=1
      end
    ensure
      p :closed
      channel.close
    end
  end
end

get '/countdown' do
  stream do |out|
    begin
      ch = Channel.new
      out.puts %(
        <title>countdown watch</title>
        <iframe name=a style='display:none'></iframe>
        <style>
          form{display:inline-block;}
          input{
            width:80px;height:40px;
            background:white;
            font-size:16px;
            border-radius:8px;
            border:2px solid gray
          }
          input[type=image], #tick, #outer, .time{position:fixed;left:15;top:15px;width:240px;height:240px;}
          #outer{border:4px solid gray;border-radius:50%;box-sizing:border-box;}
          .time{font-size:60px;text-align:center;line-height:240px;margin:0;font-weight:bold;}
          .time.paused{font-size:50px;line-height:210px;}
          .time.paused:after{
            content:'click to start';
            position:absolute;
            left:0;top:40px;width:240px;height:200px;text-align:center;
            line-height:200px;
            font-size:16px;
            color:gray;
          }
          #tick{transition:0.1s ease-out transform;}
          input[type=image]{
            left:0;top:0px;width:270px;height:270px;border:none;
            opacity:0;
            z-index:100;
          }
          #tick:before{
            content: '';
            position:absolute;left:118px;top:-8px;width:4px;height:20px;background:gray;
          }
        </style>
        <div id=outer></div>
        <div id=tick></div>
        <form action='#{ch.path}' target=a><input type=image name=coord></form>
      )
      count = 10
      count_at = Time.now
      id = 1
      state = nil
      paused = true
      remaining = ->{
        paused ? count : [count + (count_at - Time.now).round, 0].max
      }
      send = ->{
        cnt = remaining.call
        next_state = [cnt, paused]
        if state == next_state
          out.write "\n"
          return
        end
        state = next_state
        paused = false if cnt == 0
        out.puts %(
          <div class='time#{' paused' if paused}' id='d#{id}'>
            #{"%02d"%cnt}
          </div>
          <style>
            #d#{id-1}{display:none}\n#tick{transform: rotate(#{360*cnt/60}deg)}
          </style>
        )
        id += 1
      }
      Thread.new{
        until ch.closed?
          cmd = ch.deq
          next unless cmd
          dx, dy = %w(coord.x coord.y).map { |key| cmd[key].to_i - 270 / 2 }
          if dx*dx+dy*dy < 80*80
            if paused
              paused = false
              count_at = Time.now
            else
              count = remaining.call
              paused = true
            end
          else
            count = (Math.atan2(dx, -dy)*60/(2*Math::PI)).round
            count += 60 if count < 0
            paused = true
          end
          send.call
        end
      }
      loop do
        send.call
        now = Time.now
        d = (now - count_at)
        sleep (d+0.1).ceil - d
      end
    ensure
      ch.close
    end
  end
end

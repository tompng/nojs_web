get '/click_sample' do
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
          #tick, #outer, .time{position:fixed;left:15;top:60px;width:240px;height:240px;}
          #outer{border:4px solid gray;border-radius:50%;box-sizing:border-box;}
          .time{font-size:60px;text-align:center;line-height:240px;margin:0;font-weight:bold;}
          #tick{transition:0.1s ease-out transform;}
          #tick:before{
            content: '';
            position:absolute;left:118px;top:-8px;width:4px;height:20px;background:gray;
          }
        </style>
        <div id=outer></div>
        <div id=tick></div>
      )
      [10,20,30].each do |time|
        out.puts %(<form action='#{ch.path}' target=a><input name=data type=submit value='#{time}'></form>)
      end
      count = 0
      count_at = Time.now
      id = 1
      last_remaining = nil
      send = ->{
        remaining = [count + (count_at - Time.now).round, 0].max
        return if last_remaining == remaining
        last_remaining = remaining
        out.puts "<div class=time id='d#{id}'>#{"%02d"%remaining}</div>"
        out.puts "<style>#d#{id-1}{display:none}\n#tick{transform: rotate(#{360*remaining/60}deg)}</style>"
        id += 1
      }
      Thread.new{
        until ch.closed?
          cmd = ch.deq
          next unless cmd
          count = cmd[:data].to_i
          count_at = Time.now
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

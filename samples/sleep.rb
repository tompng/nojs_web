get '/clock1' do
  stream do |out|
    out.puts '<html>'
    out.puts '  <head><title>clock1</title></head>'
    out.puts '  <body>'
    loop do
      now = Time.now.localtime 9*60*60
      out.puts "    <p>#{now.strftime '%Y/%m/%d %H:%M:%S'}</p>"
      sleep 1
    end
  end
end

get '/clock2' do
  stream do |out|
    out.puts '<html>'
    out.puts '  <head>'
    out.puts '    <title>clock2</title>'
    out.puts '    <style>body{font-size:48px;}</style>'
    out.puts '  </head>'
    out.puts '  <body>'
    (0..Float::INFINITY).each do |i|
      now = Time.now.localtime 9*60*60
      out.puts "    <center id='d#{i}'>#{now.strftime '<small>%Y/%m/%d</small><br>%H:%M:%S'}</center>"
      out.puts "    <style>#d#{i-1}{display:none}</style>"
      sleep 1
    end
  end
end

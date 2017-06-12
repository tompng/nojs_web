get '/clock1' do
  stream do |out|
    loop do
      out.puts "<p>#{Time.now.strftime '%Y/%m/%d %H:%M:%S'}</p>"
      sleep 1
    end
  end
end

get '/clock2' do
  stream do |out|
    out.puts '<style>body{font-size:48px;}</style>'
    (0..Float::INFINITY).each do |i|
      out.puts "<center id='d#{i}'>#{Time.now.strftime '<small>%Y/%m/%d</small><br>%H:%M:%S'}</center>"
      out.puts "<style>#d#{i-1}{display:none}</style>"
      sleep 1
    end
  end
end

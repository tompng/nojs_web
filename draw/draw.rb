template = File.read "#{File.dirname(__FILE__)}/draw.html"

get '/draw' do
  stream do |out|
    begin
      channel = Channel.new
      action_path = channel.path
      html = template.gsub /{{[^{]+}}/ do |pattern|
        exp = pattern[2...-2]
        eval exp
      end
      out.write html
      tool = 'curve'
      stamp = 0
      color = '#000'
      loop do
        cmd = channel.deq
        p cmd
        unless cmd
          out.write "\n"
          next
        end
        case cmd[:type]
        when 'tool'
          case cmd[:tool]
          when 'eraser'
            out.write "<style>##{tool}{border-color:silver}</style>"
            out.write "<style>#eraser{border-color:black}</style>"
            tool = 'eraser'
          when 'curve'
            out.write "<style>##{tool}{border-color:silver}</style>"
            out.write "<style>#curve{border-color:black}</style>"
            tool = 'curve'
          when 'color'
            out.write "<style>#color_modal{display:flex}</style>"
          when 'stamp'
            if tool == 'stamp'
              out.write "<style>#stamp_modal{display:flex}</style>"
            else
              out.write "<style>##{tool}{border-color:silver}</style>"
              tool = 'stamp'
              out.write "<style>#stamp{border-color:black}</style>"
            end
          end
        when 'canvas'
        when 'color'
          color = cmd[:color]
          out.write "<style>#color{background:#{cmd[:color]}}</style>"
          out.write "<style>#color_modal{display:none}</style>"
        when 'stamp'
          stamp = cmd[:stamp]
          out.write "<style>#stamp_modal{display:none}</style>"
        when 'close'
          out.write "<style>##{cmd[:target]}_modal{display:none}</style>"
        end
      end
    rescue
      channel.close
    end

  end
end

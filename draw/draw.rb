require_relative './canvas'
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

      a,b,c,d = 4.times.map{
        Point.new rand(100..400), rand(100..400)
      }
      bez = Bezier.new a,b,c,d, line_width: 4, color: :blue

      out.write html
      out.write bez.to_svg
      tool = 'curve'
      stamp = 0
      color = '#000'
      strokes = []
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
            strokes = []
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
            strokes = []
            if tool == 'stamp'
              out.write "<style>#stamp_modal{display:flex}</style>"
            else
              out.write "<style>##{tool}{border-color:silver}</style>"
              tool = 'stamp'
              out.write "<style>#stamp{border-color:black}</style>"
            end
          end
        when 'canvas'
          if tool == 'curve'
            x, y = cmd[:x].to_i, cmd[:y].to_i
            strokes << Point.new(x, y)
            if strokes.length >= 2
              bez = Bezier.new strokes[-2], strokes[-2], strokes[-1], strokes[-1], color: color
              out.write bez.to_svg
            end
          end
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
    rescue => e
      channel.close
      raise e
    end

  end
end

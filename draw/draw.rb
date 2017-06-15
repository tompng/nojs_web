require_relative './canvas'
template = File.read "#{File.dirname(__FILE__)}/draw.html"

canvas = Canvas.new

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


      queue = Queue.new
      Thread.new { loop { sleep 1;queue << nil } }
      Thread.new { loop { queue << channel.deq(timeout: nil) } }
      callback = -> type, data { queue << { type: type, data: data } }
      canvas.listen callback

      loop do
        cmd = queue.deq
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
            strokes << [Point.new(x, y)]
            if strokes.size == 1
              circle = Circle.new strokes[0][0], color: color
              id, z = canvas.add circle
              strokes[0][1] = id
              strokes[0][2] = z
            elsif strokes.size == 2
              canvas.remove strokes[0][1]
            end
            if strokes.size >= 2
              points = strokes.map(&:first)
              xs, ys = [:x, :y].map { |axis| Bezier.bezparam1d points.map(&axis) }
              z = strokes[0][2]
              (strokes.size - 4 .. strokes.size - 3).each do |i|
                next if i < 0
                canvas.remove strokes[i][1]
              end
              (strokes.size - 4 .. strokes.size - 2).each do |i|
                next if i < 0
                pa, pb = points[i], points[i+1]
                ca = Point.new pa.x+xs[i]/3, pa.y+ys[i]/3
                cb = Point.new pb.x-xs[i+1]/3, pb.y-ys[i+1]/3
                bez = Bezier.new pa, ca, cb, pb, color: color
                id, z = canvas.add bez, z: z
                strokes[i][1] = id
                strokes[i][2] = z
              end
            end
          end
        when 'initial'
          cmd[:data].each do |id, (z, bez)|
            out.write bez.to_svg id: id, z: z
          end
        when 'add'
          id, z, bez = cmd[:data]
          out.write bez.to_svg id: id, z: z
        when 'remove'
          out.write %(<style>##{cmd[:data]}{display:none}</style>)
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
      canvas.unlisten callback
      queue.close
      channel.close
      raise e
    end

  end
end

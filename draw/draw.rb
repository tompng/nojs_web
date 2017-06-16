require_relative './canvas'
template = File.read "#{File.dirname(__FILE__)}/draw.html"

canvas = Canvas.new

get '/draw' do
  stream do |out|
    buffer = []
    flush = lambda do
      out.write buffer.join
      buffer = []
    end
    begin
      channel = Channel.new
      action_path = channel.path
      html = template.gsub /{{[^{]+}}/ do |pattern|
        exp = pattern[2...-2]
        eval exp
      end

      buffer << html
      tool = 'curve'
      stamp = 0
      color = '#000'
      strokes = []

      queue = Queue.new
      Thread.new { loop { sleep 1;queue << nil } }
      Thread.new { loop { queue << channel.deq(timeout: nil) } }
      callback = -> type, data { queue << { type: type, data: data } }
      canvas.listen callback

      cancel_curve = ->{
        strokes = []
        buffer << %(<style>.pnt{display:none}</style>)
      }

      loop do
        cmd = queue.deq
        unless cmd
          buffer << "\n"
          flush.call
          next
        end
        case cmd[:type]
        when 'tool'
          cancel_curve.call
          case cmd[:tool]
          when 'eraser'
            buffer << "<style>##{tool}{border-color:silver}</style>"
            buffer << "<style>#eraser{border-color:black}</style>"
            tool = 'eraser'
          when 'curve'
            buffer << "<style>##{tool}{border-color:silver}</style>"
            buffer << "<style>#curve{border-color:black}</style>"
            tool = 'curve'
          when 'color'
            buffer << "<style>#color_modal{display:flex}</style>"
          when 'stamp'
            if tool == 'stamp'
              buffer << "<style>#stamp_modal{display:flex}</style>"
            else
              buffer << "<style>##{tool}{border-color:silver}</style>"
              tool = 'stamp'
              buffer << "<style>#stamp{border-color:black}</style>"
            end
          end
        when 'dump'
          canvas.dump
        when 'canvas'
          p = Point.new cmd[:x].to_i, cmd[:y].to_i
          case tool
          when 'curve'
            if strokes[-1] && (strokes[-1][0].x-p.x)**2+(strokes[-1][0].y-p.y)**2<8**2
              cancel_curve.call
            else
              buffer << %(<style>.pnt{display:block;left:#{p.x}px;top:#{p.y}px}</style>)
              strokes << [p]
              if strokes.size == 1
                circle = Circle.new strokes[0][0], color: color
                id, z = canvas.add circle
                strokes[0][1] = id
                strokes[0][2] = z
              end
              if strokes.size >= 2
                points = strokes.map(&:first)
                xs, ys = [:x, :y].map { |axis| Bezier.bezparam1d points.map(&axis) }
                z = strokes[0][2]
                (strokes.size - 4 .. strokes.size - 2).each do |i|
                  next if i < 0
                  pa, pb = points[i], points[i+1]
                  ca = Point.new pa.x+xs[i]/3, pa.y+ys[i]/3
                  cb = Point.new pb.x-xs[i+1]/3, pb.y-ys[i+1]/3
                  bez = Bezier.new pa, ca, cb, pb, color: color
                  if strokes[i][1]
                    id, z = canvas.replace strokes[i][1], bez, z: z
                  else
                    id, z = canvas.add bez, z: z
                  end
                  if id && z
                    strokes[i][1] = id
                    strokes[i][2] = z
                  end
                end
              end
            end
          when 'eraser'
            puts [:erase, p].inspect
            canvas.erase p, 48
          end
        when 'initial'
          cmd[:data].each do |id, (z, bez)|
            buffer << bez.to_svg(id: id, z: z)
          end
        when 'add'
          id, z, bez = cmd[:data]
          buffer << bez.to_svg(id: id, z: z)
        when 'remove'
          buffer << %(<style>##{cmd[:data]}{display:none}</style>)
        when 'color'
          color = cmd[:color]
          buffer << "<style>#color{background:#{cmd[:color]}}</style>"
          buffer << "<style>#color_modal{display:none}</style>"
        when 'stamp'
          stamp = cmd[:stamp]
          buffer << "<style>#stamp_modal{display:none}</style>"
        when 'close'
          buffer << "<style>##{cmd[:target]}_modal{display:none}</style>"
        end
        flush.call
      end
    rescue => e
      canvas.unlisten callback
      queue.close
      channel.close
      raise e
    end
  end
end

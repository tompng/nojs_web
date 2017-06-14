class Canvas


end



class Point
  attr_accessor :x, :y
  def initialize x, y
    @x, @y = x, y
  end
end

class Bezier
  attr_accessor :a, :b, :c, :d
  attr_accessor :min, :max
  def initialize a, b, c, d, line_width: 2, color: 'black'
    @a, @b, @c, @d = a, b, c, d
    @color = color
    @line_width = line_width
    calc_boundingbox
  end

  def calc_boundingbox
    xmin, xmax = abcdminmax *[a,b,c,d].map(&:x)
    ymin, ymax = abcdminmax *[a,b,c,d].map(&:y)
    @min = Point.new xmin, ymin
    @max = Point.new xmax, ymax
  end

  def to_svg id: nil, zindex: 0
    w = @max.x.ceil - @min.x.floor + @line_width + 2
    h = @max.y.ceil - @min.y.floor + @line_width + 2
    x = @min.x.floor - @line_width/2 - 1
    y = @min.y.floor - @line_width/2 - 1
    style = %(left:#{x}px;top:#{y}px;z-index:zindex)
    path_style = %(stroke:#{@color};stroke-width:#{@line_width};fill:none)
    path = %(M#{a.x.round-x} #{a.y.round-y} C#{[b,c,d].map{|p|"#{p.x.round-x} #{p.y.round-y}"}.join(',')})
    %(
      <svg id='#{id}' width='#{w}px' height='#{h}' style='#{style}'>
        <path d="#{path}" style='#{path_style}'/>
      </svg>
    )
  end

  def abcdminmax a, b, c, d
    # a*ttt 3*b*t*t*(1-t) 3*c*t*(1-t)*(1-t) d*(1-t)*(1-t)*(1-t)
    # tt*a + b*(2*t-3*tt) + c*(1-4t+3tt) - d*(1-2t+tt)
    t2 = a - 3*b + 3*c - d
    t1 = 2*b - 4*c + 2*d
    t0 = c - d
    det = t1*t1 - 4*t2*t0
    if det < 0
      return [a, d].minmax
    end
    tav = -t1/2.0/t2
    tdif = Math.sqrt(det)/2/t2
    ta, tb = tav-tdif, tav+tdif
    at = ->t{a*t**3+3*b*t**2*(1-t)+3*c*t*(1-t)**2+d*(1-t)**3}
    [
      a, d,
      (at[ta] if 0 < ta && ta < 1),
      (at[tb] if 0 < tb && tb < 1)
    ].compact.minmax
  end
end

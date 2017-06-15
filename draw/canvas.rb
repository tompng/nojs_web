require 'set'
class Canvas
  def initialize
    @id_max = 0
    @z_max = 0
    @objects = {}
    @listeners = Set.new
    @mutex = Mutex.new
  end

  def listen block
    @mutex.synchronize do
      block.call 'initial', @objects.dup
      @listeners << block
    end
  end

  def unlisten block
    @mutex.synchronize do
      @listeners.delete block
    end
  end

  def broadcast type, data
    @listeners.each do |l|
      l.call type, data
    end
  end

  def add bezier, z: nil
    @mutex.synchronize do
      z ||= @z_max += 1
      id = "bz#{@id_max += 1}"
      @objects[id] = [z, bezier]
      broadcast 'add', [id, z, bezier]
      [id, z]
    end
  end

  def remove id
    @mutex.synchronize do
      @objects.delete id
      broadcast 'remove', id
    end
  end
end

class Point
  attr_accessor :x, :y
  def initialize x, y
    @x, @y = x, y
  end
end

class Circle
  attr_accessor :point
  def initialize point, line_width: 4, color: 'black'
    @point = point
    @color = color
    @line_width = line_width
  end
  def to_svg id: nil, z: 0
    size = @line_width + 2
    x = @point.x.floor - @line_width/2 - 1
    y = @point.y.floor - @line_width/2 - 1
    style = %(left:#{x}px;top:#{y}px;z-index:#{z})
    circle_style = %(fill:#{@color};)
    %(
      <svg id='#{id}' width='#{size}px' height='#{size}' style='#{style}'>
        <circle cx='#{@point.x.round-x}' cy='#{@point.y.round-y}' r='#{@line_width/2}' style='#{circle_style}'/>
      </svg>
    )
  end
end

class Bezier
  attr_accessor :a, :b, :c, :d
  attr_accessor :min, :max
  def initialize a, b, c, d, line_width: 4, color: 'black'
    @a, @b, @c, @d = a, b, c, d
    @color = color
    @line_width = line_width
    calc_boundingbox
  end

  def calc_boundingbox
    xmin, xmax = self.class.abcdminmax *[a,b,c,d].map(&:x)
    ymin, ymax = self.class.abcdminmax *[a,b,c,d].map(&:y)
    @min = Point.new xmin, ymin
    @max = Point.new xmax, ymax
  end

  def to_svg id: nil, z: 0
    w = @max.x.ceil - @min.x.floor + @line_width + 2
    h = @max.y.ceil - @min.y.floor + @line_width + 2
    x = @min.x.floor - @line_width/2 - 1
    y = @min.y.floor - @line_width/2 - 1
    style = %(left:#{x}px;top:#{y}px;z-index:#{z})
    path_style = %(stroke:#{@color};stroke-width:#{@line_width};fill:none;stroke-linecap:round)
    path = %(M#{a.x.round-x} #{a.y.round-y} C#{[b,c,d].map{|p|"#{p.x.round-x} #{p.y.round-y}"}.join(',')})
    %(
      <svg id='#{id}' width='#{w}px' height='#{h}' style='#{style}'>
        <path d='#{path}' style='#{path_style}'/>
      </svg>
    )
  end

  def self.abcdminmax a, b, c, d
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

  def self.bezparam1d values, closed: false, iterate: 4
    params = values.map { 0 }
    iterate.times do
      params = params.each_with_index.map do |p, i|
        ia = (i-1)%params.size
        ib = (i+1)%params.size
        k = 4
        unless closed
          ia, k = i, 2 if i == 0
          ib, k = i, 2 if i == params.size - 1
        end
        (3.0 * (values[ib] - values[ia]) - params[ia] - params[ib]) / k
      end
    end
    params
  end
end

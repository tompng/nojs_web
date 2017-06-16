require 'set'
require_relative './approx.rb'

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

  def replace id, bezier, z: nil
    @mutex.synchronize {
      return unless @objects[id]
      remove_without_mutex id
      add_without_mutex bezier, z: z
    }
  end

  def add bezier, z: nil
    @mutex.synchronize { add_without_mutex bezier, z: z }
  end

  def remove id
    @mutex.synchronize { remove_without_mutex id }
  end

  def add_without_mutex bezier, z: nil
    z ||= @z_max += 1
    id = "bz#{@id_max += 1}"
    @objects[id] = [z, bezier]
    broadcast 'add', [id, z, bezier]
    [id, z]
  end

  def remove_without_mutex id
    @objects.delete id
    broadcast 'remove', id
  end

  def erase p, r
    @mutex.synchronize do
      @objects.to_a.each do |id, (z, bezier)|
        new_objects = bezier.erase p, r
        next unless new_objects
        remove_without_mutex id
        new_objects.each do |obj|
          add_without_mutex obj, z: z
        end
      end
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

  def erase p, r
    [] if (point.x - p.x)**2 + (point.y - p.y)**2 < r**2
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

  def slice t0, t1
    dscale = (t1 - t0) / 3.0
    slice_abcd = lambda do |a, b, c, d|
      at = ->t{a*t**3+3*b*t**2*(1-t)+3*c*t*(1-t)**2+d*(1-t)**3}
      dat = ->t{3*a*t**2+b*(6*t-9*t*t)+c*(3-12*t+9*t*t)-3*d*(1-t)**2}
      a2 = at[t0]
      d2 = at[t1]
      [a2, a2 + dat[t0] * dscale, d2 - dat[t1] * dscale, d2]
    end
    xs = slice_abcd.call a.x, b.x, c.x, d.x
    ys = slice_abcd.call a.y, b.y, c.y, d.y
    ps = xs.zip(ys).map { |x, y| Point.new x, y }
    Bezier.new *ps, line_width: @line_width, color: @color
  end

  def erase p, r
    dx = (min.x..max.x).include?(p.x) ? 0 : [(p.x - min.x).abs, (p.x - max.x).abs].min
    dy = (min.y..max.y).include?(p.y) ? 0 : [(p.y - min.y).abs, (p.y - max.y).abs].min
    return if dx * dx + dy * dy > r * r
    $a=0;
    sections = Approx.extract_negative 0, 1, diff: 1e-5 do |t|
      $a+=1
      time=Time.now
      tt = t*t
      ttt = tt*t
      s = (t - 1)*(-1)
      ss = s*s
      sss = ss*s
      tts = tt*s
      tss = t*ss
      x = ttt*a.x+tts*3*b.x+tss*3*c.x+sss*d.x-p.x
      y = ttt*a.y+tts*3*b.y+tss*3*c.y+sss*d.y-p.y
      out = (x*x+y*y)*(-1) + r*r
      p Time.now-time
      out
    end
    $a
    return if sections == [[0, 1]]
    sections.map { |t0, t1| slice t0, t1 }
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

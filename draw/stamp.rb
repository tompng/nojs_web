require 'base64'
require_relative './canvas'
class Stamp
  def initialize strokes
    @strokes = strokes.map { |stroke|
      Stroke === stroke ? stroke : Stroke.new(stroke)
    }
  end

  def to_svg size
    beziers = beziers scale: size
    [
      %(<?xml version='1.0'?>),
      %(<svg viewBox='0 0 #{size} #{size}' version='1.1' xmlns='http://www.w3.org/2000/svg'>),
      beziers(scale: size).map(&:to_path).join,
      %(</svg>)
    ].join
  end

  def data_url
    "data:image/svg+xml;base64,#{Base64.encode64(to_svg(128)).delete("\n")}"
  end

  def beziers offset: Point.new(0, 0), scale: 1, color: 'black'
    @strokes.flat_map { |s| s.beziers offset: offset, scale: scale, color: color }
  end

  class Stroke
    attr_reader :points, :closed
    def initialize points, closed: false
      @points = points.map { |p|
        Point === p ? p : Point.new(*p)
      }
      @closed = closed
    end
    def beziers offset: Point.new(0, 0), scale: 1, color: 'black'
      xs = Bezier.bezparam1d points.map(&:x), closed: closed
      ys = Bezier.bezparam1d points.map(&:y), closed: closed
      conv = -> p { Point.new offset.x + p.x * scale, offset.y + p.y * scale}
      (closed ? points.size : points.size - 1).times.map do |i|
        pa, pb = points[i], points[(i+1)%points.size]
        ca = Point.new pa.x+xs[i]/3, pa.y+ys[i]/3
        cb = Point.new pb.x-xs[(i+1)%points.size]/3, pb.y-ys[(i+1)%points.size]/3
        Bezier.new conv[pa], conv[ca], conv[cb], conv[pb], color: color
      end
    end
    def self.circle x, y, r
      n = 8
      new(n.times.map { |i|
        t = 2*Math::PI*i/n
        Point.new x+r*Math.cos(t), y+r*Math.sin(t)
      }, closed: true)
    end
  end

end

Stamp::Star = Stamp.new(5.times.map { |i|
  t1 = 2*Math::PI*i/5
  t2 = 2*Math::PI*(i+2)/5
  Stamp::Stroke.new([t1, t2].map { |t| Point.new(0.5+0.48*Math.sin(t), 0.5-0.48*Math.cos(t)) })
})

Stamp::Smile = Stamp.new([
  Stamp::Stroke.circle(0.5, 0.5, 0.48),
  Stamp::Stroke.circle(0.32, 0.38, 0.04),
  Stamp::Stroke.circle(0.68, 0.38, 0.04),
  Stamp::Stroke.new(7.times.map { |i|
    t = (i-3.0)/3
    r = 0.32
    th = Math::PI/2.8
    Point.new 0.5+r*Math.sin(th*t), 0.76+r*(Math.cos(th*t)-1)
  })
])

Stamp::Sun = Stamp.new([
  Stamp::Stroke.circle(0.5, 0.5, 0.3),
  12.times.map{ |i|
    r1, r2 = 0.3, 0.48
    t1, t2, t3 = 2*Math::PI*(i-0.4)/12, 2*Math::PI*i/12, 2*Math::PI*(i+0.4)/12
    [
      Stamp::Stroke.new([
        Point.new(0.5+r1*Math.cos(t1), 0.5+r1*Math.sin(t1)),
        Point.new(0.5+r2*Math.cos(t2), 0.5+r2*Math.sin(t2))
      ]),
      Stamp::Stroke.new([
        Point.new(0.5+r1*Math.cos(t3), 0.5+r1*Math.sin(t3)),
        Point.new(0.5+r2*Math.cos(t2), 0.5+r2*Math.sin(t2))
      ])
    ]
  }
].flatten)

Stamp::Fish = Stamp.new([
  [[0.66,0.37],[0.42,0.26],[0.16,0.3],[0.01,0.49],[0.15,0.69],[0.38,0.73],[0.65,0.64],[0.78,0.77],[0.84,0.76],[0.82,0.54],[0.9,0.24],[0.82,0.21],[0.65,0.36]],
  [[0.31,0.47],[0.48,0.42],[0.44, 0.58],[0.33, 0.55]],
  [[0.42,0.25],[0.57,0.18],[0.64,0.25],[0.57,0.31]],
  [[0.44,0.71],[0.57,0.75],[0.62,0.69],[0.58,0.67]],
  [[0.68,0.43],[0.81,0.34]],
  [[0.69,0.48],[0.79,0.49]],
  [[0.68,0.55],[0.76,0.6]],
  [[0.14,0.38],[0.13,0.41],[0.16,0.42],[0.18,0.39],[0.14,0.38]],
  [[0.26, 0.4],[0.29, 0.49],[0.2, 0.58]]
])
Stamp::Cat = Stamp.new([
  [[0.16,0.47],[0.11,0.7],[0.28,0.87],[0.75,0.85],[0.9,0.65],[0.85,0.45],[0.9,0.19],[0.67,0.32]],
  [[0.16,0.46],[0.06,0.2],[0.34,0.32],[0.49,0.28],[0.66,0.32]],
  [[0.37,0.56],[0.34,0.57],[0.32,0.53],[0.34,0.47],[0.38,0.5],[0.37,0.55]],
  [[0.61,0.58],[0.57,0.54],[0.59,0.47],[0.63,0.47],[0.63,0.52],[0.61,0.57]],
  [[0.33,0.72],[0.38,0.78],[0.46,0.78],[0.47,0.73],[0.47,0.76],[0.52,0.77],[0.58,0.76],[0.46,0.72],[0.43,0.71],[0.44,0.67],[0.48,0.68],[0.46,0.71]],
  [[0.64,0.63],[0.72,0.62]],
  [[0.64,0.66],[0.72,0.67]],
  [[0.19,0.62],[0.28,0.62]],
  [[0.19,0.71],[0.28,0.67]]
])

Stamp::Penguin = Stamp.new([
  [[0.39,0.37],[0.31,0.38],[0.28,0.37],[0.29,0.31],[0.34,0.29],[0.38,0.27],[0.39,0.17],[0.51,0.11],[0.65,0.18],[0.69,0.27],[0.68,0.36]],
  [[0.38,0.28],[0.4,0.28],[0.42,0.23],[0.46,0.17],[0.53,0.17],[0.59,0.2],[0.6,0.28],[0.59,0.33],[0.6,0.36]],
  [[0.47,0.28],[0.45,0.28],[0.45,0.23],[0.48,0.24],[0.49,0.26],[0.46,0.27]],
  [[0.38,0.38],[0.39,0.41],[0.39,0.51],[0.36,0.58],[0.34,0.73],[0.36,0.82]],
  [[0.39,0.47],[0.35,0.52],[0.33,0.6],[0.33,0.63]],
  [[0.36,0.83],[0.3,0.85],[0.34,0.85],[0.32,0.87],[0.36,0.87],[0.35,0.89]],
  [[0.39,0.84],[0.36,0.82]],
  [[0.37,0.88],[0.35,0.89]],
  [[0.69,0.46],[0.68,0.36]],
  [[0.69,0.46],[0.7,0.53],[0.74,0.67],[0.74,0.77],[0.69,0.82],[0.61,0.8],[0.58,0.69],[0.57,0.52],[0.57,0.48]],
  [[0.39,0.84],[0.44,0.86],[0.48,0.89],[0.57,0.9],[0.65,0.86],[0.67,0.82]],
  [[0.54,0.91],[0.47,0.95],[0.47,0.92],[0.43,0.93],[0.44,0.9],[0.4,0.9],[0.45,0.87]],
  [[0.37,0.88],[0.41,0.84]],
  [[0.29,0.36],[0.36,0.35]],
  [[0.38,0.57],[0.44,0.49],[0.51,0.49],[0.54,0.55],[0.55,0.68],[0.54,0.79],[0.49,0.84],[0.39,0.79],[0.37,0.68],[0.38,0.57]]
])

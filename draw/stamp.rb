require_relative './canvas'
class Stamp
  def initialize strokes
    @strokes = strokes
  end

  def to_svg size
    beziers = beziers scale: size
    [
      %(<?xml version='1.0'?>),
      %(<svg width='#{size}' height='#{size}px' version='1.1' xmlns='http://www.w3.org/2000/svg'>),
      beziers(scale: size).map(&:to_path).join,
      %(</svg>)
    ].join
  end

  def beziers offset: Point.new(0, 0), scale: 1, color: 'black'
    @strokes.flat_map { |s| s.beziers offset: offset, scale: scale, color: color }
  end

  class Stroke
    attr_reader :points, :closed
    def initialize points, closed: false
      @points = points
      @closed = closed
    end
    def beziers offset: Point.new(0, 0), scale: 1, color: 'black'
      xs = Bezier.bezparam1d points.map(&:x)
      ys = Bezier.bezparam1d points.map(&:y)
      conv = -> p { Point.new offset.x + p.x * scale, offset.y + p.y * scale}
      (points.size - 1).times.map do |i|
        pa, pb = points[i], points[i+1]
        ca = Point.new pa.x+xs[i]/3, pa.y+ys[i]/3
        cb = Point.new pb.x-xs[i+1]/3, pb.y-ys[i+1]/3
        Bezier.new conv[pa], conv[ca], conv[cb], conv[pb], color: color
      end
    end
  end
end

Stamp::Star = Stamp.new(5.times.map { |i|
  t1 = 2*Math::PI*i/5
  t2 = 2*Math::PI*(i+2)/5
  Stamp::Stroke.new([t1, t2].map { |t| Point.new(0.5+0.48*Math.sin(t), 0.5-0.48*Math.cos(t)) })
})
require 'pry'
binding.pry

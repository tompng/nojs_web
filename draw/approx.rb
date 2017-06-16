class Approx
  attr_reader :min, :max, :slope
  def initialize min, max=min, slope=0
    @min, @max, @slope = min.to_f, max.to_f, slope.to_f
  end
  def - x
    case x
    when Approx
      Approx.new min - x.max, max - x.min, slope - x.slope
    else
      Approx.new min - x, max - x, slope
    end
  end
  def + x
    case x
    when Approx
      Approx.new min + x.min, max + x.max, slope + x.slope
    else
      Approx.new min + x, max + x, slope
    end
  end
  def * x
    case x
    when Approx
      # (s1*(t-0.5)+A1)(s2*(t-0.t)+A2)
      # s1*s2*(t-0.5)**2 + (s1*A2+s2*A1)*(t-0.5) + A1*A2
      a1min, a1max = min + slope / 2, max + slope / 2
      a2min, a2max = x.min + x.slope / 2, x.max + x.slope / 2
      s12 = slope * x.slope
      s12min, s12max = [0, s12 / 4].minmax
      smin12, smax12 = [slope*a2min, slope*a2max].minmax
      smin21, smax21 = [x.slope*a1min, x.slope*a1max].minmax
      smin, smax = smin12 + smin21, smax12 + smax21
      vslope = (smin + smax) / 2
      sdif = (smax - smin) / 2
      a12min, a12max = [[0, 0], [0, 1], [1, 0], [1, 1]].map { |s, t|
        (a1min+s*(a1max-a1min))*(a2min+t*(a2max-a2min))
      }.minmax
      vmin = a12min - sdif + s12min - vslope / 2
      vmax = a12max + sdif + s12max - vslope / 2
      # require 'pry';binding.pry
      Approx.new vmin, vmax, vslope
    else
      if x > 0
        Approx.new min * x, max * x, slope * x
      else
        Approx.new max * x, min * x, slope * x
      end
    end
  end

  def sgn
    neg = min <= 0 || min + slope <= 0
    pos = max >= 0 || max + slope >= 0
    !neg ? 1 : !pos ? -1 : 0
  end

  def zero_range
    return nil unless sgn == 0
    tmin, tmax = [-min/slope, -max/slope].minmax
    if tmin.finite? && tmax.finite?
      [
        tmin < 0 ? 0 : tmin > 1 ? 1 : tmin,
        tmax < 0 ? 0 : tmax > 1 ? 1 : tmax
      ]
    else
      [0, 1]
    end
  end

  def self.extract_negative tmin, tmax
    cache_t = nil
    cache_y = nil
    cache_calc = lambda do |t|
      return cache_y if cache_t == t
      cache_t = t
      cache_y = yield t
    end
    ranges = []
    add = lambda do |min, max|
      if ranges.last&.[](1) == min
        ranges.last[1] = max
      else
        ranges << [min, max]
      end
    end
    rec = lambda do |t0, t1|
      t = Approx.new(t0, t1, t1-t0)
      y = yield t
      sgn = y.sgn
      return if sgn == 1
      return add.call t0, t1 if sgn == -1
      zr = y.zero_range
      ta = t0+(t1-t0)*zr[0]
      tb = t0+(t1-t0)*zr[1]
      add.call t0, ta if t0 != ta && cache_calc.call(t0) <= 0
      if tb - ta < 1e-4
        y0 = cache_calc.call(ta)
        y1 = cache_calc.call(tb)
        add.call ta, tb if y0 <= 0 && y1 <= 0
      else
        if tb - ta > (t1 - t0) / 2
          tab = (ta + tb) / 2
          rec.call ta, tab
          rec.call tab, tb
        else
          rec.call ta, tb
        end
      end
      add.call tb, t1 if t1 != tb && cache_calc.call(t1) <= 0
    end
    rec.call tmin.to_f, tmax.to_f
    ranges
  end
end

# Approx.extract_negative(-1, 1){|t|t*t*2 - t*t*t*t*4 - 0.1}

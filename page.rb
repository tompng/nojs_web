class Model
  def initialize
    @version = rand
    @watcher = Set.new
  end

  def _subscribe(block)
    @watcher.add block
  end

  def _unsubscribe(block)
    @watcher.delete block
  end

  def _notify
    @watcher.each(&:call)
  end

  def self.convert(value)
    case value
    when Model, ArrayModel
      value
    when Hash
      HashModel.new value
    when Array
      ArrayModel.new value
    else
      value.dup.freeze
    end
  end
end

class HashModel < Model
  def initialize(data = {})
    super()
    @data = data.transform_keys!(&:to_sym)
  end

  def method_missing(name, *args)
    if name =~ /\A[a-z][a-z_]*=\z/ && args.size == 1
      key = name[0...-1].to_sym
      @data[key] = args.first
      _notify
    elsif name =~ /\A[a-z][a-z_]*\z/ && args.empty?
      @data[name.to_sym]
    else
      super
    end
  end

  def _transform!(output = [])
    @data.transform_values!(&Model.method(:convert))
    @data.each_value do |value|
      value._transform! output if value.is_a? Model
    end
  end

  def inspect
    @data.inspect
  end
end

class ArrayModel < Model
  def initialize(data = [])
    super()
    @data = data
  end

  def [](i)
    @data[i]
  end

  def []=(i, v)
    @data[i] = Model.convert v
    _notify
  end

  def push(v)
    v = Model.convert v
    @data.push v
    _notify
    v
  end

  alias << push

  def _transform!(output = [])
    @data.map!(&Model.method(:convert))
    @data.each do |value|
      value._transform! output if value.is_a? Model
    end
  end

  %i[shift unshift pop push sort! map! replace <<].each do |name|
    define_method name do |*args, &block|
      v = @data.send name, *args, &block
      _notify
      v
    end
  end

  ((Enumerator.instance_methods - Object.instance_methods) & Array.instance_methods).each do |name|
    define_method name do |*args, &block|
      @data.send name, *args, &block
    end
  end

  def inspect
    @data.inspect
  end
end

class PageView
  def initialize(global, stream, channel)
    @global = global
    @stream = stream
    @channel = channel
    @data = HashModel.new
    @global_watchings = []
    @local_watchings = []
    @needs_render = true
    @changed = lambda do
      next if @needs_render
      @needs_render = true
      channel << :changed rescue nil
    end
  end

  def unsubscribe
    @global_watchings.each { |model| model._unsubscribe @changed }
    @local_watchings.each { |model| model._unsubscribe @changed }
  end

  def subscribe
    @global_watchings = @global._transform!
    @local_watchings = @data._transform!
    @global_watchings.each { |model| model._subscribe @changed }
    @local_watchings.each { |model| model._subscribe @changed }
  end

  def render
    @needs_render = false
    unsubscribe
    subscribe
  end

  def run
    loop do
      command = @channel.deq
      if command == :changed
        render

      end
    end
  ensure
    unsubscribe
  end
end

def page(path, &block)
  global = HashModel.new
  get path do
    stream do |out|
      ch = Channel.new
      page = PageView.new global, out, ch, &block
      page.run
    ensure
      ch.close
    end
  end
end

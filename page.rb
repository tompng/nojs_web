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

class View
  def initialize
    @body = []
    @current = @body
  end

  def contents
    @contents_added = true
    { type: :contents }
  end

  def text(text)
    raise 'no dom after contents' if @contents_added
    @current << text.to_s
  end

  %i[
    a b u center h1 h2 h3 h4 h5 h6 div span
    form input article header hr i img label table li ol ul
    svg tbody thead textarea br strong small dl dt tr th td
  ].each do |name|
    define_method name do |*args, &block|
      tag name, *args, &block
    end
  end

  def tag(name, style: nil, onclick: nil, onsubmit: nil, text: nil, **attr)
    raise 'no dom after contents' if @contents_added
    raise 'onclick is only for tag a' if name != :a && onclick
    raise 'onsubmit is only for tag form' if name != :form && onsubmit
    raise 'text xor block' if text && block_given?
    el = {
      type: :tag,
      name: name,
      attr: attr,
      style: style,
      onclick: onclick,
      onsubmit: onsubmit,
      children: []
    }
    puts :block_given_test, block_given?, name
    if block_given?
      tmp = @current
      @current = el[:children]
      puts :block_call
      yield
      @current = tmp
    elsif text
      el[:children] << text.to_s
    end
    @current << el
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

  def view
  end

  def css
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

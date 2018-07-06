class Model
  def initialize
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
    output << self
    @data.transform_values!(&Model.method(:convert))
    @data.each_value do |value|
      value._transform! output if value.is_a? Model
    end
    output
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
    output << self
    @data.map!(&Model.method(:convert))
    @data.each do |value|
      value._transform! output if value.is_a? Model
    end
    output
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
  attr_reader :actions
  def initialize(channel, &block)
    renderer = DOMRenderer.new allow_contents: true
    renderer.instance_eval(&block)
    @dom_tree = renderer.dom_tree
    @contents_block = renderer.contents_block
    @actions = {}
    @styles = {}
    @channel = channel
    @initial_rendered = false
    @rendered_contents = []
  end

  def render
    return initial_render unless @initial_rendered
    render_diff + render_contents_diff
  end

  def render_contents_diff
    renderer = DOMRenderer.new allow_contents: false
    renderer.instance_eval(&@contents_block)
    new_doms = renderer.dom_tree
    removes = []
    diffs = []
    first_fingerprint = dom_fingerprint new_doms.first if new_doms.first
    @rendered_contents.each do |content|
      next removes << content unless content[:fingerprint] == first_fingerprint
      diffs << [content, new_doms.first]
      new_doms.shift
      first_fingerprint = dom_fingerprint new_doms.first if new_doms.first
    end
    style_updates = []
    removes.each { |content| style_updates << "##{content[:id]}{display: none}" }
    new_contents = []
    removes.each do |content|
      content[:action_keys].each { |id| @actions.delete id }
    end
    diffs.map do |content, dom|
      styles = []
      actions = []
      extract_style_actions dom, styles, actions
      content[:styles].to_a.zip styles do |(id, old_style), new_style|
        changed = new_style.to_a - old_style.to_a
        style_updates << "##{id}{#{View.css_to_string(changed)}}"
        content[:styles][id] = new_style
      end
      content[:action_keys].zip(actions) { |id, action| @actions[id] = action }
      new_contents << content
    end
    htmls = []
    new_doms.each do |dom|
      html = ''
      styles = {}
      actions = {}
      prepare_html dom, html, styles, actions
      content_id = random_id
      htmls << "<div id='#{content_id}'>#{html}</div>"
      actions.each { |id, action| @actions[id] = action }
      new_contents << {
        id: content_id,
        styles: styles.transform_values(&:call),
        action_keys: actions.keys,
        fingerprint: dom_fingerprint(dom)
      }
    end
    p [:update, diffs.size, removes.size, new_doms.size]
    @rendered_contents = new_contents
    htmls << "<style>#{style_updates.join "\n"}</style>" unless style_updates.empty?
    htmls.join("\n")
  end

  def dom_fingerprint dom
    case dom
    when String
      dom
    when Hash
      dom.slice(:name, :attr, :style, :onclick, :submit).merge(
        children: dom_fingerprint(dom[:children]),
      ).transform_values { |v| v.is_a?(Proc) ? true : v}
    when Array
      dom.map(&method(:dom_fingerprint))
    end
  end

  def render_diff
    diff = []
    @styles.each do |id, value|
      style = value[:block].call
      next if value[:current] == style
      changed = style.to_a - value[:current].to_a
      value[:current] = style
      diff << "##{id}{#{View.css_to_string(changed)}}"
    end
    "<style>#{diff.join("\n")}</style>"
  end

  def initial_render
    @initial_rendered = true
    html = '<iframe name=iframe style="display:none"></iframe>'.dup
    styles = {}
    prepare_html @dom_tree, html, styles, @actions
    style_list = []
    styles.each do |id, block|
      css = block.call
      @styles[id] = { current: css, block: block }
      style_list << "##{id}{#{View.css_to_string block.call}}"
    end
    @dom_tree = nil
    style_html = "<style>#{style_list.join "\n"}</style>"
    html + style_html + render_contents_diff
  end

  def extract_style_actions dom, styles, actions
    return dom.each { |d| extract_style_actions d, styles, actions } if dom.is_a? Array
    return if dom.is_a? String
    styles << dom[:style] if dom[:style]
    handler = dom[:onclick] || dom[:onsubmit]
    actions << handler if handler
    extract_style_actions dom[:children], styles, actions
  end

  def random_id
    'id' + rand(0xffffffffffffffff).to_s(36)
  end

  def prepare_html dom, output, styles, actions
    return dom.each { |d| prepare_html d, output, styles, actions } if dom.is_a? Array
    return output << CGI.escape_html(dom) if dom.is_a? String
    return output.freeze if dom[:type] == :contents
    attributes = dom[:attr].dup
    if dom[:style] || dom[:onclick] || dom[:onsubmit]
      id = random_id
      attributes[:id] = id
    end
    styles[id] = dom[:style] if dom[:style]
    handler = dom[:onclick] || dom[:onsubmit]
    if handler
      actions[id] = handler
      attributes[:target] = 'iframe'
    end
    if dom[:onclick]
      attributes[:href] = "#{@channel.path}?handler=#{id}"
    elsif dom[:onsubmit]
      attributes[:action] = "#{@channel.path}?handler=#{id}"
      attributes[:method] = :post
    end
    attr_string = attributes.map do |key, value|
      %(#{key}="#{CGI.escape_html value}")
    end
    output << "<#{dom[:name]} #{attr_string.join ' '}>"
    prepare_html dom[:children], output, styles, actions
    output << "</#{dom[:name]}>" unless output.frozen?
  end

  def self.css_to_string css
    css.map { |key, value| "#{key}: #{value};" }.join
  end
end

class DOMRenderer
  attr_reader :dom_tree, :contents_block
  def initialize allow_contents:
    @allow_contents = allow_contents
    @dom_tree = []
    @current = @dom_tree
  end

  def contents(&block)
    raise unless @allow_contents
    raise unless block_given?
    @contents_block = block
    { type: :contents, block: block }
  end

  def text(text)
    raise 'no dom after contents' if @contents_block
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
    raise 'no dom after contents' if @contents_block
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
    if block_given?
      tmp = @current
      @current = el[:children]
      yield
      @current = tmp
    elsif text
      el[:children] << text.to_s
    end
    @current << el
  end
end

class Page
  def initialize(global, stream, channel, &block)
    @global = global
    @stream = stream
    @channel = channel
    @data = HashModel.new
    @global_watchings = []
    @local_watchings = []
    @needs_render = true
    @styles = {}
    @changed = lambda do
      next if @needs_render
      @needs_render = true
      channel << :changed rescue nil
    end
    instance_exec @global, @data, &block
  end

  def style(selector, &block)
    @styles[selector] = { current: {}, block: block }
  end

  def view(&block)
    @view = View.new @channel, &block
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
    return unless @needs_render
    @needs_render = false
    unsubscribe
    subscribe
    output = @view.render
    style_updates = []
    @styles.each do |selector, style|
      new_css = style[:block].call
      diff = new_css.to_a - style[:current].to_a
      style[:current] = new_css
      next if diff.empty?
      style_updates << "#{selector}{#{View.css_to_string diff}}"
    end
    output << "<style>#{style_updates.join "\n"}</style>" unless style_updates.empty?
    @stream.puts output
  end

  def run
    loop do
      render
      command = @channel.deq
      if command == :changed
        render
      elsif command.is_a? Hash
        action = @view.actions[command[:handler]]
        action.arity.zero? ? action.call : action&.call(command) if action
      end
      @stream.puts
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
      page = Page.new global, out, ch, &block
      page.run
    ensure
      ch.close
    end
  end
end

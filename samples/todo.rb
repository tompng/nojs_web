page '/test', { color: 'silver' } do |global, local|
  local.count = 4
  decrese = -> { local.count -= 1 if local.count > 0 }
  increse = -> { local.count += 1 }
  view do
    h1 style: -> { { color: global.color } }, text: 'Framework Sample'
    div class: 'plusminus' do
      a text: '-', onclick: -> { decrese.call }
      a text: '+', onclick: -> { increse.call }
    end
    div class: 'colors' do
      a text: 'red', onclick: -> { global.color = 'red' }
      text ' '
      a text: 'blue', onclick: -> { global.color = 'blue' }
      text ' '
      a text: 'green', onclick: -> { global.color = 'green' }
    end
    div class: 'contents-here' do
      contents do
        local.count.times do |i|
          div style: ->{ { opacity: 1 - i.fdiv(local.count) } } do
            text "Hello #{i}"
            a text: 'x', onclick: -> { local.count = i }
          end
        end
      end
    end
  end
end

initial_global = {
  todos: [
    { id: 0, name: 'job', done: true },
    { id: 1, name: 'game', done: false }
  ]
}

page '/todo', initial_global do |global, local|
  local.show_mode = :all

  add_task = lambda do |name|
    name = name.to_s.strip
    return if name.empty?
    return if global.todos.any? { |task| task.name == name }
    global.todos.push(id: rand, name: name, done: false)
  end

  toggle_task = lambda do |id, done|
    task = global.todos.find { |t| t.id == id }
    task.done = done if task
  end

  toggle_check_all = lambda do
    all_done = global.todos.all?(&:done)
    global.todos.each { |task| task.done = !all_done }
  end

  remove_task = lambda do |id|
    global.todos = global.todos.reject { |task| task.id == id }
  end

  remove_completed = lambda do
    global.todos = global.todos.reject(&:done)
  end

  style 'h1' do
    { position: 'absolute', left: global.x }
  end
  style '.items-left:before' do
    count = global.todos.count { |task| !task.done }
    { content: "'#{count} items left'" }
  end

  checkbox_css = lambda do |done|
    color = done ? '#88f' : '#ddd'
    { 'border-color' => color, color: color }
  end

  show_task = lambda do |task|
    case local.show_mode
    when :complete
      task.done
    when :active
      !task.done
    else
      true
    end
  end

  view do
    tag :style, text: File.read('samples/todo.css')
    div class: 'todoapp' do
      div class: 'header' do
        form onsubmit: ->(params) { add_task.call params[:name] } do
          input name: :name, autocomplete: :off, placeholder: 'add new task...'
        end
        a(
          class: 'task-checkbox',
          style: -> { checkbox_css.call global.todos.all?(&:done) },
          onclick: -> { toggle_check_all.call }
        ) do
          span text: '✔︎', style: -> { { display: global.todos.all?(&:done) ? 'block' : 'none' } }
        end
      end
      div class: 'footer' do
        span class: 'items-left'
        span class: 'show-mode-buttons' do
          %i[all active complete].each do |mode|
            a(
              text: mode.capitalize,
              onclick: -> { local.show_mode = mode },
              style: -> { { 'border-color' => local.show_mode == mode ? 'silver' : 'transparent' } }
            )
          end
          a text: 'Clear completed', onclick: -> { remove_completed.call }, style: -> {
            {
              float: 'right',
              display: global.todos.any?(&:done) ? 'inline-block' : 'none'
            }
          }
        end
      end
      div class: 'todos' do
        contents do
          global.todos.each do |task|
            div class: 'task', style: -> { { display: show_task.call(task) ? 'block' : 'none' } } do
              a(
                class: 'task-checkbox',
                style: -> { checkbox_css.call task.done },
                onclick: -> { toggle_task.call task.id, !task.done }
              ) do
                span text: '✔︎', style: -> { { display: task.done ? 'block' : 'none' } }
              end
              div class: 'task-name', text: task.name
              a class: 'task-delete', onclick: -> { remove_task.call task.id }, text: '×'
            end
          end
        end
      end
    end
  end
end

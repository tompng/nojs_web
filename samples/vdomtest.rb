page '/vdomtest', { color: 'silver' } do |global, local|
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

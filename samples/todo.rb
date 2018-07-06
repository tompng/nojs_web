page '/todo' do |global, local|
  local.color = 'red'
  global.x = rand(200)
  style 'h1' do
    { position: 'absolute', left: global.x }
  end
  view do
    h1 text: 'hello', style: -> { { color: local.color } }
    div do
      a onclick: -> { global.x = rand(200) } do
        text 'click'
      end
      contents do
        a text: 'red', onclick: -> { local.color = 'red' }
        a text: 'green', onclick: -> { local.color = 'green' }
        a text: 'blue', onclick: -> { local.color = 'blue' }
        div text: local.color if local.color == 'blue'
      end
    end
  end
end

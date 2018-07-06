page '/todo' do |global, local|
  local.color = 'red'
  style 'h1' do
    { position: 'absolute', left: rand(200) }
  end
  view do
    h1 text: 'hello', style: -> { { color: local.color } }
    div do
      a onclick: -> { local.color = %w[green blue].sample } do
        text 'click'
      end
      contents do
        div text: local.color + rand.to_s
      end
    end
  end
end

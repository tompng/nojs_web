page '/todo' do |global, local|
  local.color = 'red'
  view do
    h1 text: 'hello', style: -> { { color: local.color } }
    div do
      a onclick: -> { local.color = %w[green blue].sample } do
        text 'click'
      end
      contents do
        div text: local.color
      end
    end
  end

end

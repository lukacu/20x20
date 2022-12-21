-- Showing some Cryptopunks

local function cryptopunks(state, screen)

    if state == nil then
        state = {
            sprites = Sprites.open("cryptopunks.dat"),
            count = 0
        }
  
    end

    if state.count % 200 == 0 then
        local i = node.random(1, state.sprites.count)
        state.sprites:display(screen, i, 1, 1)
    end

    state.count = state.count + 1
    return state

end

return cryptopunks;
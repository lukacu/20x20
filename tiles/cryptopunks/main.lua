-- Showing some Cryptopunks

function cryptopunks(state, screen)

    if state == nil then
        state = {
            sprites = Sprites.load("cryptopunks.dat"),
            count = 0
        }
  
    end

    if state.count % 100 == 0 then
        local i = (math.floor(state.count / 100)+1) % state.sprites.count
        state.sprites:display(screen, i, 0, 0)
    end

    state.count = state.count + 1

    return state

end


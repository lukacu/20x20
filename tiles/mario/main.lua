-- Super Mario walking

function mario(state, screen)

    if state == nil then
        state = {
            sprites = Sprites.load("mario.dat"),
            count = 0, 
            direction = 0
        }
        state.direction = node.random(1, state.sprites.count / 2)
    end

    if state.count % 5 == 0 then
        local i = state.direction * 2 - 1
        if state.count % 10 < 5 then
            i = i + 1
        end
        state.sprites:display(screen, i, 0, 0)        
    end

    if state.count == 40 then
        state.direction = node.random(1, state.sprites.count / 2)
        state.count = 0
    end

    state.count = state.count + 1

    return state

end


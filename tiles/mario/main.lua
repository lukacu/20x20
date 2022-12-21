-- Super Mario walking

local function mario(state, screen)

    if state == nil then
        local db = Sprites.open("mario.dat")
        state = {
            sprites = db:load(1, 8),
            cache = nil,
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
        state.sprites:display(screen, i, 1, 1)        
    end

    if state.count == 40 then
        state.direction = node.random(1, state.sprites.count / 2)
        state.count = 0
    end

    state.count = state.count + 1

    return state

end

return mario;
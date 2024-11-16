-- Super Mario walking

local direction = {
    [1] = {0, 1}, 
    [2] = {0, -1}, 
    [3] = {1, 0},  
    [4] = {-1, 0} 
}

local function mario(state, screen)

    if state == nil then
        local Sprites = load_sprites();
        local db = Sprites.open("mario.dat")
        state = {
            sprites = db:load(1, 8),
            cache = nil,
            count = 0, 
            direction = 4,
            x = 1,
            y = 1
        }
    end

    if state.count % 5 == 0 then

        screen.buffer:fill(0, 0, 0)

        if state.x > (screen.width+1) or state.y > (screen.height+1) or state.x < -screen.width or state.y < -screen.height then
            state.direction = node.random(1, state.sprites.count / 2)
            state.count = 0
        end

        local i = state.direction * 2 - 1
        if state.count % 10 < 5 then
            i = i + 1
        end

        state.sprites:display(screen, i, state.x, state.y)        

        state.x = state.x + direction[state.direction][1]
        state.y = state.y + direction[state.direction][2]
    end

    state.count = state.count + 1

    return state

end

return mario;
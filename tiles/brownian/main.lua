-- Brownian motion visualization

local function brownian(state, screen)

    if state == nil then
        state = { counter = 1000,
            x = node.random(1, screen.width),
            y = node.random(1, screen.height),
            r = node.random(0, 255),
            g = node.random(0, 255),
            b = node.random(0, 255)
        }   
        screen.buffer:fill(0, 0, 0)
    end

    if state.counter == 0 then
        return nil
    end

    screen:add(-3)

    state.x = math.max(math.min(screen.width, state.x + node.random(-1, 1)), 1)
    state.y = math.max(math.min(screen.height, state.y + node.random(-1, 1)), 1)  
    
    screen:set(state.x, state.y, state.r, state.g, state.b)

    state.counter = state.counter - 1

    state.r = math.min(255, math.max(state.r + node.random(-15, 15), 0))
    state.g = math.min(255, math.max(state.g + node.random(-15, 15), 0))
    state.b = math.min(255, math.max(state.b + node.random(-15, 15), 0))


    return state

end

return brownian;
-- Brownian motion visualization

function brownian(state, screen)

    if state == nil or state.counter == 0 then
        state = { counter = 300,
            x = node.random(1, screen.width),
            y = node.random(1, screen.height)
        }   
        screen.buffer:fill(0, 0, 0)
    end

    screen.buffer:fade(2)

    state.x = math.max(math.min(screen.width, state.x + node.random(-1, 1)), 1)
    state.y = math.max(math.min(screen.height, state.y + node.random(-1, 1)), 1)  

    r = node.random(0, 255)
    g = node.random(0, 255)
    b = node.random(0, 255)
    
    screen.set(state.x, state.y, r, g, b)

    state.counter = state.counter - 1

    return state

end


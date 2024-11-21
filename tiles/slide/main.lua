-- Slide

local direction = {
    [1] = {0, 1, 1, 0, 0, 0}, 
    [2] = {-1, 1, 1, 1, 0, 0},
    [3] = {-1, 0, 0, 1, 0, 0}, 
    [4] = {-1, -1, 0, 1, 1, 0},
    [5] = {0, -1, 0, 0, 1, 0},
    [6] = {1, -1, 0, 0, 1, 1},
    [7] = {1, 0, 0, 0, 0, 1},
    [8] = {1, 1, 0, 0, 0, 1}
}

local function slide(state, screen)

    if state == nil then
        state = { counter = 10,
            direction = node.random(1, 8),
            r = node.random(0, 255),
            g = node.random(0, 255),
            b = node.random(0, 255)
        }   
        --screen.buffer:fill(0, 0, 0)
    end

    if state.counter == 0 then
        return nil
    end

    screen:slide(direction[state.direction][1], direction[state.direction][2])
    screen:add(-2)

    state.counter = state.counter - 1

    -- clear border
    if direction[state.direction][3] == 1 then
        screen:fill(1, 1, screen.width, 1, 0, 0, 0)
    end
    if direction[state.direction][6] == 1 then
        screen:fill(1, 1, 1, screen.height, 0, 0, 0)
    end
    if direction[state.direction][5] == 1 then
        screen:fill(1, screen.height, screen.width, 1, 0, 0, 0)
    end
    if direction[state.direction][4] == 1 then
        screen:fill(screen.width, 1, 1, screen.height, 0, 0, 0)
    end
    -- set random pixel to random color
    screen:set(node.random(1, screen.width), node.random(1, screen.height), node.random(0, 255), node.random(0, 255), node.random(0, 255))

    return state

end

return slide;

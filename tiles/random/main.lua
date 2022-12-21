-- Painting random pixels

local function random(state, screen)

    if state == nil or state == 0 then
        state = 500
        screen.buffer:fill(0, 0, 0)
    end

    i = node.random(1, screen.buffer:size())
    r = node.random(0, 255)
    g = node.random(0, 255)
    b = node.random(0, 255)
    screen.buffer:set(i, r, g, b)

    return state - 1

end

return random;
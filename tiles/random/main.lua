-- Painting random pixels

local function random(state, screen)

    if state == nil or state.progress == 0 then
        state = {
            progress = 50,
            mode = node.random(0, 4),
            fade = node.random(2, 10)
        }
        screen:clear()
    end

    r = node.random(0, 255)
    g = node.random(0, 255)
    b = node.random(0, 255)
    x = node.random(1, screen.width)
    y = node.random(1, screen.height)

    screen:add(-state.fade)

    if state.mode == 0 then
        screen:set(x, y, r, g, b)
    elseif state.mode == 1 then
        screen:line(x, 1, x, screen.height, r, g, b)
    elseif state.mode == 2 then
        screen:line(1, y, screen.width, y, r, g, b)
    elseif state.mode == 3 then
        screen:line(x - screen.width, y - screen.height, x + screen.width, y + screen.height, r, g, b)
    elseif state.mode == 4 then
        screen:line(x + screen.width, y - screen.height, x - screen.width, y + screen.height, r, g, b)
    end

    state.progress = state.progress - 1

    return state

end

return random;
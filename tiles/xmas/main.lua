-- XMas tree

local function xmas(state, screen)

    if state == nil then
        local db = Sprites.open("tree.dat")
        state = {
            sprites = db:load(1, 1),
            cache = nil,
            count = 0, 
            snow = {},
            intensity = node.random(10, 20)
        }
        for i=1, state.intensity do
          state.snow[i] = {node.random(1, screen.width), node.random(1, screen.height), node.random(200, 255)}
        end
    end

    if state.count % 8 == 0 then
        state.sprites:display(screen, 1, 1, 1)        

        for i=1, state.intensity do
            local x = state.snow[i][1]
            local y = state.snow[i][2]
            local v = state.snow[i][3]
            y = y + 1
            x = math.min(screen.width, math.max(1, x + node.random(-1, 1)))

            if y > screen.height then
                x = node.random(1, screen.width)
                y = 1
            end
            state.snow[i] = {x, y, node.random(200, 255)}
            screen:set(x, y, v, v, v)
        end
    end

    state.count = state.count + 1

    return state
end

return xmas;
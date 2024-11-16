
local function main(state, screen)

    if state == nil then
        local Font = load_font()
        state = {
            text = "Welcome to FRI!",
            offset = 0,
            font = Font.create(),
            y = 5,
            width = 0,
            cr = node.random(160, 255),
			cg = node.random(160, 255),
			cb = node.random(160, 255),
        }
        state.y = node.random(1, screen.height - state.font.height)
        state.width = state.font.width * #state.text
        state.offset = -screen.width
    end

    screen.buffer:fill(0, 0, 0)
    state.font:print(screen, state.text, -state.offset, state.y, state.cr, state.cg, state.cb)

    state.offset = state.offset + 1

    if state.offset > state.width then
        state.offset = -screen.width
        state.cr = node.random(100, 255)
        state.cg = node.random(100, 255)
        state.cb = node.random(100, 255)
        state.y = node.random(1, screen.height - state.font.height)
    end

    return state
end

return main;
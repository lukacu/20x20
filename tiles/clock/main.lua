
local apiurl = "https://www.timeapi.io/api/Time/current/zone?timeZone=Europe/Amsterdam"

local time = {time = nil, day = nil}

local function updateclock(code, body, headers)

    if code == 200 then
        data = sjson.decode(body)
        time.time = data.time
        time.date = string.format("%02d-%02d", data.day, data.month)
        time.day = data.dayOfWeek:sub(1, 3)
    end
end

local function main(state, screen)

    if state == nil then
        state = {
            counter = 1000,
			time = time,
            font = Font.create()
        }
    end

    if state.counter > 600 then
        http.get(apiurl, nil, updateclock)
        state.counter = 0
    end

    screen.buffer.fill(0, 0, 0)

    state.font:print(screen, state.time.date, 1, 2, 255, 255, 255)
    state.font:print(screen, state.time.time, 1, 8, 255, 0, 255)
    state.font:print(screen, state.time.day, 5, 15, 255, 255, 255)

    state.counter = state.counter + 1

    return state
end

return main;

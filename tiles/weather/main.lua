
local latitude = "46.05"
local longitude = "14.51"

local apiurl = "https://api.open-meteo.com/v1/forecast?latitude="..latitude.."&longitude="..longitude.."&current_weather=true&timeformat=unixtime"

local codes = {
    [0] = 0, -- sun
    [1] = 1, -- overcast
    [2] = 1, 
    [3] = 1,
    [45] = 2, -- fog
    [48] = 2,
    [51] = 3, -- light rain
    [53] = 3,
    [55] = 3,
    [56] = 3,
    [57] = 3,
    [61] = 4, -- rain
    [63] = 4,
    [65] = 4,
    [80] = 4,
    [81] = 4,
    [82] = 4,
    [66] = 5, -- freezing rain
    [67] = 5,
    [71] = 6, -- snow
    [73] = 6,
    [75] = 6,
    [77] = 6,
    [85] = 6,
    [86] = 6,
    [95] = 7, -- storm
    [96] = 7,
    [99] = 7,
}

-- data.current_weather.weathercode

local weather = {temperature = nil, code = nil}

local function updateweather(code, body, headers)

    if code == 200 then
        data = sjson.decode(body)
        weather.temperature = data.current_weather.temperature
        weather.code = data.current_weather.weathercode
    end
end

local function main(state, screen)

    if state == nil then
        state = {
            counter = 0,
			weather = weather
        }
    end

    if state.counter > 1000 then
        http.get(apiurl, nil, updateweather)
    end

    state.counter = state.counter + 1

    return state
end

return main;


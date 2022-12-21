
local framerate = 10

local rinfo, einfo = node.bootreason()

print(rinfo, einfo)

if rinfo == 4 or (einfo > 0 and einfo < 4) then
  print("Halting execution due to reset")
  return
end

dofile("sprites.lua")

do
	Screen = {}
	local mt = { __index = Screen }

	function Screen.create(width, height)
        local buffer = pixbuf.newBuffer(width * height, 3)
        buffer:fill(0, 0, 0)
		return setmetatable({
			  width = width,
        height = height,
        buffer = buffer
		}, mt)
	end

	function Screen:set(x, y, r, g, b)
		local buffer = self.buffer
        buffer:set((y-1) * self.width + x, r, g, b)
	end
end

local function pass(state, screen)
    return state
end

local screen = Screen.create(20, 20)
local current = pass
local state = nil
local timeout = node.random(framerate * 20, framerate * 60)

ws2812.init()

local function set_hostname(name)
    if file.open("hostname", "w") then
      file.write(name);
      file.close();
    end
end

local function setup_wifi()

    if not file.open("hostname", "r") then

        local charset = {} do -- [0-9a-z]
            for c = 48, 57 do table.insert(charset, string.char(c)) end
            for c = 65, 90 do table.insert(charset, string.char(c)) end
        end

        local HOSTNAME = 'node-'

        for i = 1, 10 do
            HOSTNAME = HOSTNAME .. charset[node.random(1, #charset)]
        end
        print("Generating new hostname " .. HOSTNAME);
        set_hostname(HOSTNAME);

    else
        HOSTNAME = file.readline();
        file.close();
        print("Using hostname " .. HOSTNAME);
    end

    if file.open("_config.lua") then
        file.close();
        dofile("_config.lua");
    end

    wifi.sta.disconnect()

    if (not WIFI_SSID) and (not WIFI_PASSWORD) then
        return
    end

    wifi_connect_event = function(T)
      print("Connection to AP (" .. T.SSID .. ") established")
      if disconnect_ct ~= nil then disconnect_ct = nil end
    end

    wifi_got_ip_event = function(T)
        print("IP address is: " .. T.IP .. ", configuring network")

        if mdns then
            mdns.register(HOSTNAME, {hardware='NodeMCU'}) -- service="http", port=80,
        end

    end

    wifi_disconnect_event = function(T)
      if T.reason == wifi.eventmon.reason.ASSOC_LEAVE then
        return
      end

      local total_tries = 5
      print("\nWiFi connection to AP (" .. T.SSID .. ") has failed!")

      for key,val in pairs(wifi.eventmon.reason) do
        if val == T.reason then
          print("Disconnect reason: "..val.." ("..key..")")
          break
        end
      end

      if disconnect_ct == nil then
        disconnect_ct = 1
      else
        disconnect_ct = disconnect_ct + 1
      end
      if disconnect_ct < total_tries then
        print("Retrying connection... (attempt "..(disconnect_ct+1).." of "..total_tries..")")
      else
        wifi.sta.disconnect()
        disconnect_ct = nil
      end
    end

    wifi.eventmon.register(wifi.eventmon.STA_CONNECTED, wifi_connect_event)
    wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, wifi_got_ip_event)
    wifi.eventmon.register(wifi.eventmon.STA_DISCONNECTED, wifi_disconnect_event)
    wifi.setmode(wifi.STATION)
    wifi.sta.config({ssid=WIFI_SSID, pwd=WIFI_PASSWORD, save=false})

end

local tiles = {}

local l = file.list();
for k,v in pairs(l) do
  if k:match("^tile_(.*).lua$") then
    local m = require(string.sub(k, 1, -5))
    tiles[#tiles+1] = {handle = m};
    print("Found tile " .. string.sub(k, 6, -5) .. " = " .. #tiles)
  end
end 

print("Found " .. #tiles .. " tiles")

--setup_wifi()

local ok = true
local loop = nil

function run(i) 
  if loop ~= nil then
    loop:unregister()
  end

  if i == nil then
    if table.getn(tiles) > 0 then
      i = node.random(1, table.getn(tiles))
    else 
      i = -1
    end
  end

  if i < 1 then
    current = pass
    state = nil
    return
  else
    current = tiles[i].handle;
    state = nil;
    timeout = node.random(framerate * 20, framerate * 60)
  end

  loop = tmr.create()
  loop:alarm(1000 / framerate, tmr.ALARM_AUTO, function()
    --ok, state = pcall(current(state, screen))
    state = current(state, screen)
    ws2812.write(screen.buffer)
    if not ok then 
      print(state)
      run(-1)
    end
    timeout = timeout - 1
    if timeout < 1 then
      state = nil
    end
    if not ok or state == nil then
        print("restart", state)
        run()
    end
  end)
end

tmr.create():alarm(500, tmr.ALARM_SINGLE, function () run() end)

local framerate = 10

local rinfo, einfo = node.bootreason()

function load_sprites()
  m = require("sprites");
  package.loaded["sprites"] = nil;
  return m;
end

function load_font()
  m = require("font");
  package.loaded["font"] = nil;
  return m;
end

--if rinfo == 4 or (einfo > 0 and einfo < 4) then
--  print("Halting execution due to reset")
--  return
--end

dofile("utilities.lua")

local function pass(state, screen)
    return state
end

local screen = Screen.create(20, 20)
local current = pass
local current_name = ""
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

print(node.egc.meminfo())

local l = file.list();
for k,v in pairs(l) do
  if k:match("^tile_(.*).lua$") then
    local name = string.sub(k, 1, -5)
    require(name);
    package.loaded[name] = nil;
    tiles[#tiles+1] = {name=name};
  end
end 

print(node.egc.meminfo())

function list_tiles()
  for k,v in pairs(tiles) do
    print("Tile " .. v.name .. " = " .. k)
  end
end

print("Found " .. #tiles .. " tiles")

list_tiles()

setup_wifi()

print(node.egc.meminfo())

local loop = nil

function list_tiles()
  for k,v in pairs(tiles) do
    print("Tile " .. v.name .. " = " .. k)
  end
end

function run(i) 
  if loop ~= nil then
    loop:unregister()
  end

  if i == nil then
    if table.getn(tiles) > 0 then
      i = node.random(1, table.getn(tiles))
    else 
      i = 0
    end
  end

  if i < 1 then
    current = pass
    state = nil
    return
  else
    package.loaded[current_name] = nil
    current_name = tiles[i].name
    current = require(current_name);
    state = nil;
    timeout = node.random(framerate * 20, framerate * 60)
  end

  loop = tmr.create()
  loop:alarm(1000 / framerate, tmr.ALARM_AUTO, function()
    state = current(state, screen)
    ws2812.write(screen.buffer)
    if not ok then 
      print(current_name, state)
      state = nil
      run(0)
      return
    end
    timeout = timeout - 1
    if timeout < 1 then
      state = nil
    end
    if state == nil then
        run()
    end
  end)
end

if rinfo == 4 or (einfo > 0 and einfo < 4) then
  print("Halting auto start due to previous error")
  return
end

local onerror = function(s)
  print("Error: "..s)
  -- TODO: perhaps remove faulty tile in production mode?
  state = nil
  run(0)
end

node.setonerror(onerror)

tmr.create():alarm(500, tmr.ALARM_SINGLE, function () run() end)
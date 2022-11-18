
local network_hooks = {}

function network_ready(hook)
    table.insert(network_hooks, hook);
end

local function set_hostname(name)
    if file.open("hostname", "w") then
      file.write(name);
      file.close();
    end
end

local function command_server(timeout)

    command_server = net.createServer(net.TCP, 180)

    local bound = false

    print("Opening command server")

    if command_server then

        command_server:listen(9091, function(socket)
        
            if bound then    
                socket:close()
            end

            bound = true
        
            local fifo = {}
            local fifo_drained = true

            local function sender(c)
                if #fifo > 0 then
                    c:send(table.remove(fifo, 1))
                else
                    fifo_drained = true
                end
            end

            local function s_output(str)
                table.insert(fifo, str)
                if socket ~= nil and fifo_drained then
                    fifo_drained = false
                    sender(socket);
                end
            end

            node.output(s_output, 0)   -- re-direct output to function s_ouput.

            socket:on("receive", function(c, l)
                node.input(l);           -- works like pcall(loadstring(l)) but support multiple separate line
            end)
            socket:on("disconnection", function(c)
                node.output(nil);        -- un-register the redirect output function, output goes to serial
                bound = false;
                
                -- TODO: should we close server with timeout anyway?
            end)
            socket:on("sent", sender);

        end)

        if timeout > 0 then
            tmr.create():alarm(timeout * 1000, tmr.ALARM_SINGLE, function ()
                if not bound then
                    print("Closing command server")
                    command_server:close()
                end
            end)
        
        end
      
    end

end

tmr.create():alarm(1000, tmr.ALARM_SINGLE, function ()

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

        command_server(0);

        for _, hook in ipairs(network_hooks) do
            hook();
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

    tmr.create():alarm(5000, tmr.ALARM_SINGLE, function ()

        for _, v in pairs({"main.lua", "main.lc"}) do

            if file.open(v) then
                print("Running application");
                file.close();
                dofile(v);
                break;
            end

        end

    end)

end)



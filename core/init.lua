tmr.create():alarm(1000, tmr.ALARM_SINGLE, function () for _, v in pairs({"main.lua", "main.lc"}) do if file.open(v) then file.close(); dofile(v); break; end end end);


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
        pixmod.set(buffer, self.width, self.height, x, y, r, g, b)
	end

    function Screen:line(x1, y1, x2, y2, r, g, b)
        local buffer = self.buffer
        pixmod.line(buffer, self.width, self.height, x1, y1, x2, y2, r, g, b)
    end

    function Screen:fill(x, y, w, h, r, g, b)
        local buffer = self.buffer
        pixmod.fill(buffer, self.width, self.height, x, y, w, h, r, g, b)
    end

    function Screen:clear()
        self:fill(1, 1, self.width, self.height, 0, 0, 0)
    end

    function Screen:add(v)
        local buffer = self.buffer
        pixmod.add(buffer, self.width, self.height, v)
    end

    function Screen:blit(src, src_w, src_h, x, y, w, h, dx, dy)
        local screen = self.buffer
        pixmod.blit(src, src_w, src_h, screen, self.width, self.height, x, y, w, h, dx, dy)
    end

    function Screen:blit_color(src, src_w, src_h, x, y, w, h, dx, dy, r, g, b)
        local screen = self.buffer
        pixmod.blit_color(src, src_w, src_h, screen, self.width, self.height, x, y, w, h, dx, dy, r, g, b)
    end
end

function deepcopy(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for index, value in pairs(object) do
            new_table[_copy(index)] = _copy(value)
        end
        return setmetatable(new_table, getmetatable(object))
    end
    return _copy(object)
end

function isprefix(s, prefix)
    return string.sub(s,1,string.len(prefix)) == prefix
end
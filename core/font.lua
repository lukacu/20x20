
do
	Font = {}
	local mt = { __index = Font }

	function Font.create()
        local handle = file.open("font.dat", "r")

        local header = handle:read(6);

        local count = header:byte(2) * 255 + header:byte(1)
        local width = header:byte(4) * 255 + header:byte(3)
        local height = header:byte(6) * 255 + header:byte(5)

        local data = pixbuf.newBuffer(width * height * (count-32), 1)
        handle:seek("set", width * height * (32) + 6)
        data:set(1, handle:read(width * height * (count-32)))

		return setmetatable({
			data = data,
			count = count - 32,
			width = width,
            height = height
		}, mt)
	end

	function Font:print(screen, text, x, y, cr, cg, cb)
        if text == nil then return end
        local offset = x
        for c in text:gmatch"." do
            self:char(screen, string.byte(c) + 1, offset, y, cr, cg, cb)
            offset = offset + self.width
            if offset > screen.width then break end
        end
    end

	function Font:char(screen, index, x, y, cr, cg, cb)
		local data = self.data

        index = index - 32

        if index < 1 or index > self.count then return end

        screen:blit_color(data, self.width, self.height * self.count, 1, 1 + (index-1) * self.height, self.width, self.height, x, y, cr, cg, cb)

	end

	function Font:char_old(screen, index, x, y, cr, cg, cb)
		local data = self.data

        index = index - 32

        if index < 1 or index > self.count then return end

        local dst_left = math.min(math.max(x-1, 0), screen.width-1)
        local dst_top = math.min(math.max(y-1, 0), screen.height-1)

        local dst_right = math.min(math.max(x + self.width - 1, 0), screen.width-1)
        local dst_bottom = math.min(math.max(y + self.height - 1, 0), screen.height-1)

        if dst_left == dst_right or dst_top == dst_bottom then return end

        local src_left = math.min(math.max(-dst_left - x + 1, 0), self.width-1)
        local src_top = math.min(math.max(-dst_top - y + 1, 0), self.height-1)

        local src_right = math.min(math.max(src_left + dst_right - dst_left + 1, 0), self.width-1)
        local src_bottom = math.min(math.max(src_top + dst_bottom - dst_top + 1, 0), self.height-1)

        local src_offset = self.width * self.height * (index - 1) + (src_left)
        local dst_offset = (dst_left)

        local line = src_right - src_left
        local lines = src_bottom - src_top

        local buffer = pixbuf.newBuffer(line, 3)

        local mapper = function(rs,gs,bs,m) if m == 0 then return rs, gs, bs else return cr, cg, cb end end

        for i = 0, lines do
            local soffset = src_offset + ((i + src_top) * self.width) + 1
            local doffset = dst_offset + ((i + dst_top) * screen.width) + 1
            buffer:map(mapper, screen.buffer, doffset, doffset + line - 1, self.data, soffset)
            screen.buffer:replace(buffer, doffset)
        end	
	end

    return Font
end

do
	Sprites = {}
	local mt = { __index = Sprites }

	function Sprites.load(filename)
        local handle = file.open(filename, "r")

        local data = handle:read(6);

        local count = data:byte(2) * 255 + data:byte(1)
        local width = data:byte(4) * 255 + data:byte(3)
        local height = data:byte(6) * 255 + data:byte(5)

		return setmetatable({
			handle = handle,
			count = count,
			width = width,
            height = height
		}, mt)
	end

	function Sprites:display(screen, index, x, y)
		local handle = self.handle

        if index < 1 or index > self.count then
            return
        end

        local dst_left = math.min(math.max(x, 1), screen.width)
        local dst_top = math.min(math.max(y, 1), screen.height)

        local dst_right = math.min(math.max(x + self.width, 1), screen.width)
        local dst_bottom = math.min(math.max(y + self.height, 1), screen.height)

        if dst_left == dst_right or dst_top == dst_bottom then
            return
        end

        local src_left = math.min(math.max(-dst_left - x + 1, 1), self.width)
        local src_top = math.min(math.max(-dst_top - y + 1, 1), self.height)

        local src_right = math.min(math.max(src_left + dst_right - dst_left + 1, 1), self.width)
        local src_bottom = math.min(math.max(src_top + dst_bottom - dst_top + 1, 1), self.height)

        local src_offset = 6 + self.width * self.height * 3 * (index - 1) + (src_left-1) * 3
        local dst_offset = (dst_left-1) + (dst_top-1) * screen.width + 1

        local line = src_right - src_left + 1
        local lines = src_bottom - src_top + 1

		for i = 0, lines do
            handle:seek("set", src_offset + ((i + src_top - 1) * self.width) * 3)    
            local data = handle:read(3 * line)
            screen.buffer:set(dst_offset + ((i + dst_top - 1) * screen.width), data)
		end	
	end
end



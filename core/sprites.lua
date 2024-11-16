
do
	Sprites = {}
	local mt = { __index = Sprites }

	function Sprites.open(filename)
        local handle = file.open(filename, "r")

        local data = handle:read(6);

        local count = data:byte(2) * 255 + data:byte(1)
        local width = data:byte(4) * 255 + data:byte(3)
        local height = data:byte(6) * 255 + data:byte(5)

		return setmetatable({
			data = handle,
			count = count,
			width = width,
            height = height
		}, mt)
	end

    function Sprites:load(position, count)
		local source = self.data

        local offset = self.width * self.height * 3 * (position - 1)
        local length = self.width * self.height * 3 * count
        local data = nil

        if type(source) == "Buffer" then
            data = source:sub(offset + 1, offset + length)
        else
            source:seek("set", offset + 6)
            data = pixbuf.newBuffer(self.width*self.height*count, 3)
            data:set(1, source:read(length))
        end

		return setmetatable({
			data = data,
			count = count,
			width = self.width,
            height = self.height
		}, mt)
    end

	function Sprites:display(screen, index, x, y)
		local data = self.data

        if index < 1 or index > self.count then
            return
        end
        if type(data) == "Buffer" then
            screen:blit(data, self.width, self.height * self.count, 1, 1 + (index-1) * self.height, self.width, self.height, x, y)
        else
            tmp = self:load(index, 1)
            tmp:display(screen, 1, x, y)
        end

	end

    return Sprites
end



-- Game of life automata

do
	Life = {}
	local mt = { __index = Life }

	function Life.new(m, n)
		local world = pixbuf.newBuffer(m * n, 1)
		local temporary = pixbuf.newBuffer(m * n, 1)

		world:fill(0)
		temporary:fill(0)

		return setmetatable({
			world = world,
			temporary = temporary,
			m = m,
			n = n,
			l = 1,
			cr = node.random(100, 255),
			cg = node.random(100, 255),
			cb = node.random(100, 255),
		}, mt)
	end

	function Life:set_pos(x,y)
		self.world:set((y-1) * self.m + x, 1)
	end

	function Life:unset_pos(x,y)
		self.world:set((y-1) * self.m + x, 0)
	end

	function Life:step(c)
		local O = self.temporary
		local I = self.world

		for j = self.l, math.min(self.l + c, self.n) do
			for i = 1, self.m do
				local s = 0
				for p = i-1,i+1 do
					for q = j-1,j+1 do
						if p > 0 and p <= self.m and q > 0 and q <= self.n then
							s = s + I:get((q-1)*self.m + p)
						end
					end
				end
				local x = I:get((j-1) * self.m + i)
				s = s - x
				if s == 3 or (s+x) == 3 then
					O:set((j-1) * self.m + i, 1)
				else
					O:set((j-1) * self.m + i, 0)
				end
			end
		end
		self.l = math.min(self.l + c, self.n) 
		if self.l == self.n then
			I:replace(O)
			self.l = 1
			return true
		end
		return false
	end

	function Life:display(screen)
		local f = function(v) 
			if v == 1 then 
				return self.cg, self.cr, self.cb; 
			else 
				return 0, 0, 0;
			end
		end
		screen.buffer:map(f, self.world, 1)
	end
end

local function life(state, screen)

    if state == nil or state.counter > 200 then
        state = {
            counter = 0,
			progress = 0,
            game = Life.new(screen.width, screen.height)
        }

        for i=1,200 do
            x = node.random(1, screen.width)
            y = node.random(1, screen.height) 
            state.game:set_pos(x,y)
        end

    end

    if state.game:step(3) then
		state.game:display(screen)
	end

	state.counter = state.counter + 1

    return state
end

return life;
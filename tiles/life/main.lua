-- Game of life automata

do
	Life = {}
	local mt = { __index = Life }

	function Life.new(m, n)
		local matrix = {}

		for i = 1, m do
			local row = {}
			for j = 1, n do
				row[j] = 0
			end
			matrix[i] = row
		end

		return setmetatable({
			matrix = matrix,
			m = m,
			n = n,
		}, mt)
	end

	function Life:set_pos(x,y)
		self.matrix[x][y] = 1
	end

	function Life:unset_pos(x,y)
		self.matrix[x][y] = 0
	end

	function Life:step()
		local X = deepcopy(self.matrix)
		local matrix = self.matrix
		for i = 1, self.m do
			for j = 1, self.n do
				local s = 0
				for p = i-1,i+1 do
					for q = j-1,j+1 do
						if p > 0 and p <= self.m and q > 0 and q <= self.n then
							s = s + self.matrix[p][q]
						end
					end
				end
				s = s - self.matrix[i][j]
				if s == 3 or (s+self.matrix[i][j]) == 3 then
					X[i][j] = 1
				else
					X[i][j] = 0
				end
			end
		end
		self.matrix = deepcopy(X)
	end

	function Life:display(screen)
		local matrix = self.matrix
		for i = 1, self.m do
			for j = 1, self.n do
				if matrix[i][j] == 0 then
					screen.set(i, j, 0, 0, 0)
				else 
					screen.set(i, j, 255, 255, 255)
				end
			end
		end	
	end
end

function life(state, screen)

    if state == nil or state.counter > 100 then
        state = {
            counter = 0,
            game = Life.new(screen.width, screen.height)
        }

        for i=1,200 do
            x = node.random(1, screen.width)
            y = node.random(1, screen.height) 
            state.game:set_pos(x,y)
        end

     end

    state.game:step()
    state.game:display(screen)
    state.counter = state.counter + 1


    return state
end



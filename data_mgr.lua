-- Created by Krock
-- License: WTFPL

player_notes.load_data = function()
	local file = io.open(player_notes.data_file, "r")
	if not file then
		return
	end
	for line in file:lines() do
		if line ~= "" then
			local data = string.split(line, "|")
			--[1] player_name, [2] key 1, [3] notice 1, [?] key X, [?+1] notice X
			if #data > 1 then
				player_notes.player[data[1]] = {}
				local index = 2
				while index <= #data do
					if data[index] ~= "" then
						-- if not empty
						player_notes.player[data[1]][data[index]] = data[index + 1]
					end
					index = index + 2
				end
			end
		end
	end
	io.close(file)
end

-- Load late, because not much used
minetest.after(3, player_notes.load_data)

player_notes.save_data = function()
	local file = io.open(player_notes.data_file, "w")
	for player, notes in pairs(player_notes.player) do
		local str = ""
		for key, _note in pairs(notes) do
			local note = string.gsub(_note, "|", "/")
			str = str..key.."|"..note.."|"
		end
		if string.len(str) > 2 then
			file:write(player.."|"..str.."\n")
		end
	end
	io.close(file)
end

-- string2 = string.gsub(string2, "|", "/")
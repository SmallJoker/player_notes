--Old... player_notes CLI

minetest.register_chatcommand("add_note", {
	params = "<name> <note>",
	description = "Adds a player note",
	privs = {player_notes=true},
	func = function(name, param)
		local found, _, target, note = param:find("^([^%s]+)%s(.+)$")
		if not found then
			minetest.chat_send_player(name, "Invalid parameters. See /help add_note")
			return
		end
		
		if not minetest.auth_table[target] then
			minetest.chat_send_player(name, "Unknown player: "..target)
			return
		end
		if string.len(note) < 3 or string.len(note) > 60 then
			minetest.chat_send_player(name, "Note is too short or too long to add. Sorry.")
			return
		end
		if not player_notes.player[target] then
			player_notes.player[target] = {}
		end
		-- generate random key
		local key = tostring(math.random(player_notes.key_min, player_notes.key_max))
		if player_notes.enable_timestamp ~= "" then
			player_notes.player[target][key] = "<"..name.." at ("..os.date(player_notes.enable_timestamp)..")> "..note
		else
			player_notes.player[target][key] = "<"..name.."> "..note
		end
		minetest.chat_send_player(name, "Added note!")
		player_notes.save_data()
	end
})

minetest.register_chatcommand("rm_note", {
	params = "<name> <key>",
	description = "Remove player note with <key>",
	privs = {player_notes=true},
	func = function(name, param)
		local target, key = string.match(param, "^([^ ]+) +(.+)$")
		if not target or not key then
			minetest.chat_send_player(name, "Invalid parameters. See /help rm_note")
			return
		end
		if not player_notes.player[target] then
			minetest.chat_send_player(name, "Player has no notes so far.")
			return
		end
		-- must be unique key
		key = tonumber(key)
		if not key or key < player_notes.key_min or key > player_notes.key_max then
			minetest.chat_send_player(name, "Key must be a number between 1000 and 9999.")
			return
		end
		if not player_notes.player[target][tostring(key)] then
			minetest.chat_send_player(name, "Key does not exist. Can not remove unknown note.")
			return
		end
		player_notes.player[target][tostring(key)] = nil
		local delete = true
		for key, note in pairs(player_notes.player[target]) do
			if string.len(note) > 2 then
				delete = false
				break
			end
		end
		-- remove empty players
		if delete then
			player_notes.player[target] = nil
		end
		minetest.chat_send_player(name, "Removed note!")
		player_notes.save_data()
	end
})

minetest.register_chatcommand("notes", {
	params = "[<name>]",
	description = "Lists all notes / Lists notes of <name>",
	privs = {player_notes=true},
	func = function(name, param)
		if param == "" then
			-- list (all)
			minetest.chat_send_player(name, "== Listing all notes (Player | Amount) ==")
			for player, notes in pairs(player_notes.player) do
				local num = 0
				for key, note in pairs(notes) do
					num = num + 1
				end
				minetest.chat_send_player(name, player.." | "..tostring(num))
			end
		else
			-- list player
			if not player_notes.player[param] then
				minetest.chat_send_player(name, "Player has no notes so far.")
				return
			end
			minetest.chat_send_player(name, "== Notes of '"..param.."' (Key | Adder | Note) ==")
			for key, note in pairs(player_notes.player[param]) do
				minetest.chat_send_player(name, "["..tostring(key).."] "..note)
			end
		end
	end
})
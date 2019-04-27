if not minetest.safe_file_write then
	error("[player_notes] Your Minetest version is no longer supported."
		.. " (version < 0.4.17)")
end

player_notes = {}
player_notes.player = {}
player_notes.mod_path = minetest.get_modpath("player_notes")
player_notes.data_file = minetest.get_worldpath().."/player_notes.data"
player_notes.mgr = {}

-- to generate unique 4-digit long numbers as key
player_notes.enable_timestamp = "%x" -- %x = date | %X = time -> "%x %X"
player_notes.key_min = 100
player_notes.key_max = 999

dofile(player_notes.mod_path.."/data_mgr.lua")
minetest.register_privilege("player_notes", "Can view and modify player's notes.")

minetest.register_chatcommand("notes", {
	description = "Lists all notes / Lists notes of <name>",
	privs = {player_notes=true},
	func = function(name, param)
		player_notes.mgr[name] = { indx={}, data="", note={}, key="" }
		player_notes.show_formspec(0, name)
	end
})

minetest.register_on_player_receive_fields(function(player,formname,fields)
	if formname ~= "player_notes:conf" then
		return
	end

	local player_name = player:get_player_name()
	local mgr = player_notes.mgr[player_name]

	if fields.quit then -- exit
		if mgr then
			player_notes.mgr[player_name] = nil
		end
		return
	end
	if not mgr or not minetest.check_player_privs(player_name, {player_notes=true}) then
		return
	end

	if fields.close then -- exit to main
		player_notes.show_formspec(0, player_name)
		return
	end
	if fields.m_all then -- list-click-event
		local event = minetest.explode_textlist_event(fields.m_all)
		if event.type == "CHG" then
			mgr.data = mgr.indx[event.index] or ""
			player_notes.show_formspec(0, player_name)
			return
		end
		if event.type == "DCL" and mgr.indx[event.index] then
			mgr.data = mgr.indx[event.index]
			player_notes.show_formspec(3, player_name)
			return
		end
	end
	if fields.p_all then -- list-click-event
		local selected_note = ""
		local event = minetest.explode_textlist_event(fields.p_all)
		if event.type == "CHG" then
			selected_note = tostring(mgr.note[event.index])
		end
		mgr.key = selected_note
		player_notes.show_formspec(2, player_name)
		return
	end
	if fields.m_add and fields.p_name then -- show adding formspec
		if not minetest.player_exists(fields.p_name) then
			minetest.chat_send_player(player_name, "Unknown player: "..fields.p_name)
			return
		end
		mgr.data = fields.p_name
		player_notes.show_formspec(1, player_name)
		return
	end
	if fields.m_rm then -- show removing formspec
		if not player_notes.player[mgr.data] then
			minetest.chat_send_player(player_name, "Please select a player name.")
			return
		end
		player_notes.show_formspec(2, player_name)
		return
	end
	if fields.m_so then -- show player notes only
		if not player_notes.player[mgr.data] then
			minetest.chat_send_player(player_name, "Please select a player name.")
			return
		end
		player_notes.show_formspec(3, player_name)
		return
	end
	
	if fields.p_add and fields.p_name and fields.p_note then -- add note
		local fail_msg = player_notes.add_note(player_name, fields.p_name, fields.p_note)
		if not fail_msg then
			player_notes.save_data()
		end
		minetest.chat_send_player(player_name, fail_msg or "Added note!")
		player_notes.show_formspec(fail_msg and 1 or 0, player_name)
		return
	end
	if fields.p_rm and fields.p_key then -- ReMove note
		local fail_msg = player_notes.rm_note(mgr.data, fields.p_key)
		if not fail_msg then
			player_notes.save_data()
		end
		minetest.chat_send_player(player_name, fail_msg or "Removed note!")
		player_notes.show_formspec(2, player_name)
	end
end)


function player_notes.get_formspec()
	error("Deprecated function call")
end

function player_notes.show_formspec(mode, player_name)
	local formspec = {}
	local mgr = player_notes.mgr[player_name]

	if mode == 0 then
		--main formspec
		formspec = {
			"size[5,8]",
			"label[0,0.2;Player note manager]",
			"button_exit[4,0;1,1;exit;X]",
			"field[0.3,7;5,0.5;p_name;Player name;" .. (mgr.data or "") .. "]",
			"button[0   ,7.4;1.5,1;m_add;Add]",
			"button[1.75,7.4;1.5,1;m_so;Info]",
			"button[3.50,7.4;1.5,1;m_rm;Del]",
			"textlist[0,0.8;4.75,5.1;m_all;"
		}
		mgr.indx = {}
		local i = 1
		for player, notes in pairs(player_notes.player) do
			local num = 0 -- Amount of notes
			for key, note in pairs(notes) do
				num = num + 1
			end
			formspec[#formspec + 1] = player .. " (" .. tostring(num) .. "),"
			mgr.indx[i] = player
			i = i + 1
		end
		formspec[#formspec + 1] = ";;false]"
	elseif mode == 1 then
		--player add note
		formspec = {
			"size[7,4]",
			"label[1,0;Add a player note]",
			"field[0.3,1.5;4,0.5;p_name;Player name:;" .. mgr.data .. "]",
			"field[0.3,3;7,0.5;p_note;Note text:;]",
			"button[1.5,3.5;2,1;p_add;Add]",
			"button[3.5,3.5;2,1;close;Close]"
		}
	elseif mode == 2 then
		--player remove note
		formspec = {
			"size[10,6]",
			"label[1,0;Remove a player note]",
			"label[0,5.6;Key:]",
			"field[1.4,6;3,0.5;p_key;;" .. mgr.key .. "]"..
			"button[4,5.5;2,1;p_rm;Remove]",
			"button[6,5.5;2,1;close;X]",
			"textlist[0,0;9.8,4.8;p_all;"
		}
		mgr.note = {}
		local i = 1
		if player_notes.player[mgr.data] then
			for key, note in pairs(player_notes.player[mgr.data]) do
				formspec[#formspec + 1] = key .. " - "
					.. minetest.formspec_escape(note) .. ","
				mgr.note[i] = key
				i = i + 1
			end
		end
		formspec[#formspec + 1] = ";;false]"
	elseif mode == 3 then
		formspec = {
			"size[14,5]",
			"label[1,0;Notes of: ".. mgr.data .. "]",
			"button[5.5,4.5;3,1;close;Close]",
			"textlist[0,0;13.8,4.5;p_see;"
		}
		mgr.note = {}
		if player_notes.player[mgr.data] then
			for key, note in pairs(player_notes.player[mgr.data]) do
				formspec[#formspec + 1] = minetest.formspec_escape(note)..","
			end
		end
		formspec[#formspec + 1] = ";;false]"
	end

	if #formspec == 0 then
		return
	end
	minetest.show_formspec(player_name, "player_notes:conf", table.concat(formspec))
end

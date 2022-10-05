local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local make_entry = require("telescope.make_entry")
local fn, api, loop, lsp = vim.fn, vim.api, vim.loop, vim.lsp

local Mansession = {}
-- local mansessions = {}
Mansession.__index = Mansession
function Mansession:new(opts)
	opts = opts or {}
	local obj = setmetatable({
		sessionDir = opts.sessionDir or vim.fn.stdpath("data") .. "/vimSession",
	}, self)
	return obj
end

function Mansession:start(opts)
	opts = opts or {}
	opts.cwd = opts.cwd or vim.fn.stdpath("data") .. "/vimSession"
	opts.sessionDir = opts.sessionDir or vim.fn.stdpath("data") .. "/vimSession"
	opts.find_command = opts.find_command or { "ls", opts.sessionDir }
	opts.entry_maker = opts.entry_maker or make_entry.gen_from_file(opts)
	pickers
		.new(opts, {
			prompt_title = "Manage Session",
			finder = finders.new_oneshot_job(opts.find_command, opts),
			previewer = conf.file_previewer(opts),
			sorter = conf.file_sorter(opts),
			attach_mappings = function(prompt_bufnr, map)
				map(
					"n",
					"<cr>",
					(function()
						local load_session = function()
							actions.close(prompt_bufnr)
							local selection = action_state.get_selected_entry()
							local current_spath = vim.v.this_session or ""
							--save current session if exist
							if current_spath ~= "" then
								api.nvim_command("mksession! " .. fn.fnameescape(current_spath))
							end
							-- Stop all LSP clients first
							for _, client in pairs(lsp.get_active_clients()) do
								lsp.stop_client(client)
							end
							-- Scedule buffers cleanup to avoid callback issues and source the session
							vim.schedule(function()
								-- save opened buffer and delete buffer
								api.nvim_cmd(vim.api.nvim_parse_cmd("wall", {}), {})
								api.nvim_cmd(vim.api.nvim_parse_cmd("%bwipeout", {}), {})
								-- source session
								api.nvim_cmd(
									vim.api.nvim_parse_cmd("source " .. opts.sessionDir .. "/" .. selection[1], {}),
									{}
								)
							end)
						end
						return load_session
					end)()
				)
				map(
					"n",
					"d",
					(function()
						local delete_session = function()
							actions.close(prompt_bufnr)
							-- create trush dir under sessionDir
							-- local trushDir = opts.sessionDir .. "/trush"
							-- if fn.isdirectory(trushDir) == 0 then
							-- 	fn.mkdir(trushDir, "p")
							-- end
							local selection = action_state.get_selected_entry()
							-- move session file to trush
							-- vim.cmd([[!mv ]] .. opts.sessionDir .. "/" .. selection[1] .. " " .. trushDir)
							vim.cmd([[!rm ]] .. opts.sessionDir .. "/" .. selection[1])
						end
						return delete_session
					end)()
				)
				return true
			end,
		})
		:find()
end

function Mansession.session_save(opts)
	opts = opts or {}
	--  see https://github.com/glepnir/dashboard-nvim/blob/master/lua/dashboard/session.lua for details
	local home = loop.os_homedir()
	local sessionDir = opts.sessionDir or vim.fn.stdpath("data") .. "/vimSession"
	local function isWindows()
		if loop.os_uname().sysname == "Windows_NT" then
			return true
		else
			return false
		end
	end
	local function project_name()
		local cwd = fn.resolve(fn.getcwd())
		cwd = fn.substitute(cwd, "^" .. home .. "/", "", "")
		if isWindows() then
			cwd = fn.fnamemodify(cwd, [[:p:gs?\?_?]])
			cwd = (string.gsub(cwd, "C:", ""))
		else
			cwd = fn.fnamemodify(cwd, [[:p:gs?/?_?]])
		end
		cwd = fn.substitute(cwd, [[^\.]], "", "")
		return cwd
	end
	if isWindows() then
		-- overwrite sessionDir for Windows in this file
		sessionDir = string.gsub(sessionDir, "/", "\\")
	end
	-- create directory where the session files are located
	if fn.isdirectory(sessionDir) == 0 then
		fn.mkdir(sessionDir, "p")
	end
	-- if the result of input is null,the default file_name will be used
	local file_name = fn.input("session name: ", "")
	if file_name:len() == 0 then
		file_name = project_name()
	end
	local file_path = sessionDir .. "/" .. file_name .. ".vim"
	api.nvim_command("mksession! " .. fn.fnameescape(file_path))
	vim.notify("\nSession " .. file_name .. " is now persistent")
end

-- deprecated
-- mansessions.new = function(opts, defaults)
-- 	opts = opts or {}
-- 	defaults = defaults or {}
-- 	local results = {}
-- 	for key, value in pairs(opts) do
-- 		results[key] = value
-- 	end
-- 	for key, value in pairs(defaults) do
-- 		results[key] = value
-- 	end
-- 	return Mansession:new(results)
-- end

-- Test
-- local abc = Mansession:new({ sessionDir = vim.fn.stdpath("data") .. "/vimSession" })
-- abc:start({})
-- abc.session_save()

-- print(abc.sessionDir)
-- print(vim.pretty_print(abc.find_command))
return Mansession

local Mansession = require("session-manage")
local man_session
local opts = {}
return require("telescope").register_extension({
	setup = function(ext_config, config)
		-- access extension config and user config
		ext_config = ext_config or {}
		config = config or {}
		config.sessionDir = ext_config.sessionDir or vim.fn.stdpath("data") .. "/vimSession"
		config.cwd = ext_config.sessionDir or vim.fn.stdpath("data") .. "/vimSession"
		man_session = Mansession:new(ext_config)
		for key, value in pairs(config) do
			opts[key] = value
		end
	end,
	exports = {
		list = function()
			man_session:start(opts)
		end,
		save = function()
			man_session.session_save(opts)
		end,
	},
})

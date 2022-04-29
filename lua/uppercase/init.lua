-- init.lua
local M = {}

-- convert a string to uppercase
local to_uppercase = function(text)
	assert(type(text) == "string", "to_uppercase requires a string")

	return text:upper()
end

M.to_uppercase = to_uppercase

-- get the content of the current buffer, convert each line to uppercase, and replace
M.buffer_to_uppercase = function()
	for i, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
		local converted = to_uppercase(line)
		vim.api.nvim_buf_set_lines(0, i - 1, i, false, { converted })
	end
end

-- set up a command for easier uppercasing
M.setup = function()
	vim.cmd('command! ToUppercase lua require("uppercase").buffer_to_uppercase()')
end

return M

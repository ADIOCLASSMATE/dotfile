-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

local function prepend_path(dir)
	if vim.fn.isdirectory(dir) ~= 1 then
		return
	end

	local current_path = vim.env.PATH or ""
	if not string.find(":" .. current_path .. ":", ":" .. dir .. ":", 1, true) then
		vim.env.PATH = dir .. ":" .. current_path
	end
end

prepend_path(vim.fn.expand("~/.cargo/bin"))
prepend_path(vim.fn.expand("~/.local/bin"))
prepend_path(vim.fn.expand("~/.bun/bin"))

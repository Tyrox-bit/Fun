-- Real Luau syntax check for every script (compiles each file with Lune's Luau compiler).
-- Usage: lune run tools/check_syntax.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local files, failed = 0, 0
local function walk(dir: string)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path)
		elseif string.sub(name, -5) == ".luau" then
			files += 1
			local ok, err = pcall(luau.compile, fs.readFile(path))
			if not ok then
				failed += 1
				print(path .. ": " .. tostring(err))
			end
		end
	end
end
walk(process.args[1] or "src")
walk("tools")
print(string.format("compiled %d files, %d with syntax errors", files, failed))
if failed > 0 then
	process.exit(1)
end

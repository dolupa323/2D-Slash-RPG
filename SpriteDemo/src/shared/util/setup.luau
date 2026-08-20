-- 공식 SpaceFighter 예제(notreux/SpaceFighter)의 src/shared/util/setup.luau 그대로 재활용.
local exports = {}

--[[
    Retrieves all ModuleScripts from a given path and requires them.
    Returns a table mapping module names to the required module.
]]
function exports.getModulesByPath(path)
	local modules = {}
	for _, module in path:GetChildren() do
		if module:IsA("ModuleScript") then
			modules[module.Name] = require(module)
		end
	end

	return modules
end

--[[
    Iterates over a table of modules and calls the specified method on each,
    passing any additional arguments provided.
]]
function exports.run(modules, methodName, ...)
	for _, module in modules do
		if module[methodName] then
			module[methodName](...)
		end
	end
end

return exports

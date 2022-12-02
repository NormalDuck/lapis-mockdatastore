local Constants = require(script.Constants)
local validateString = require(script.validateString)

local function copyDeep(value)
	if typeof(value) ~= "table" then
		return value
	end

	local copy = {}

	for a, b in value do
		copy[a] = copyDeep(b)
	end

	return copy
end

local GlobalDataStore = {}
GlobalDataStore.__index = GlobalDataStore

function GlobalDataStore.new(clock, errors)
	return setmetatable({
		data = {},
		getCache = {},
		writeCooldowns = {},
		clock = clock,
		errors = errors,
	}, GlobalDataStore)
end

function GlobalDataStore:UpdateAsync(key, transform)
	validateString("key", key, Constants.MAX_KEY_LENGTH)

	if typeof(transform) ~= "function" then
		error("`transform` must be a function")
	end

	if self.errors ~= nil then
		self.errors:simulateError("UpdateAsync")
	end

	if self.writeCooldowns[key] ~= nil and self.clock() < self.writeCooldowns[key] then
		self.budget:yieldForBudgetAndWriteCooldown(
			key,
			self.writeCooldowns,
			{ Enum.DataStoreRequestType.SetIncrementAsync }
		)
	else
		local usingGetCache = self.getCache[key] ~= nil and self.clock() < self.getCache[key]

		local requestsTypes = if usingGetCache
			then { Enum.DataStoreRequestType.SetIncrementAsync }
			else { Enum.DataStoreRequestType.GetAsync, Enum.DataStoreRequestType.SetIncrementAsync }

		self.budget:yieldForBudget(requestsTypes)
	end

	local oldValue = self.data[key]
	local transformed = transform(copyDeep(oldValue))

	if transformed == nil then
		return nil
	end

	-- TODO: Make sure transformed data is savable.

	self.data[key] = copyDeep(transformed)

	self.getCache[key] = self.clock() + Constants.GET_CACHE_DURATION
	self.writeCooldowns[key] = self.clock() + Constants.WRITE_COOLDOWN

	return copyDeep(transformed)
end

return GlobalDataStore

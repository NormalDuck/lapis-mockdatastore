local RunService = game:GetService("RunService")

local Budget = require(script.Budget)
local Constants = require(script.Constants)
local GlobalDataStore = require(script.GlobalDataStore)
local SimulatedErrors = require(script.SimulatedErrors)
local validateString = require(script.validateString)

local function assertServer()
	if not RunService:IsServer() then
		error("DataStore can't be accessed from the client")
	end
end

local DataStoreServiceMock = {}
DataStoreServiceMock.__index = DataStoreServiceMock

function DataStoreServiceMock.new()
	return setmetatable({
		dataStores = {},
		budget = Budget.new(os.clock),
		clock = os.clock,
	}, DataStoreServiceMock)
end

function DataStoreServiceMock.manual()
	local now = 0

	local function clock()
		return now
	end

	local self = setmetatable({
		dataStores = {},
		errors = SimulatedErrors.new(),
		budget = Budget.manual(clock),
	}, DataStoreServiceMock)

	self.clock = clock

	function self:tick(seconds)
		now += seconds
		self.budget:tick(seconds)
	end

	return DataStoreServiceMock
end

function DataStoreServiceMock:GetDataStore(name, scope)
	assertServer()
	validateString("name", name, Constants.MAX_NAME_LENGTH)
	validateString("scope", scope, Constants.MAX_SCOPE_LENGTH)

	if self.dataStores[name] == nil then
		self.dataStores[name] = {}
	end

	if self.dataStores[name][scope] == nil then
		self.dataStores[name][scope] = GlobalDataStore.new(self.clock, self.errors)
	end

	return self.dataStores[name][scope]
end

function DataStoreServiceMock:GetRequestBudgetForRequestType(requestType)
	local budget = self.budget.budgets[requestType]

	if budget == nil then
		error("`requestType` must be an Enum.DataStoreRequestType")
	end

	return budget
end

return DataStoreServiceMock

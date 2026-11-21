-- PowerService: sector power. Switches tagged lights (FZ_SectorLight) and unlocks/locks
-- doors whose PowerSector attribute matches. State is replicated as "Power_<sector>".

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SessionState = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SessionState"))

local PowerService = {}

local DEFAULT = { A = true, B = false, C = true, D = true, E = true, CONTROL = true, CORE = false, HALL = true, HALLS = false }
local powered: { [string]: boolean } = {}
local OFF_COLOR = Color3.fromRGB(40, 40, 38)

local doorService = nil -- injected to avoid a require cycle

local function applyLight(fixture: Instance)
	local sector = fixture:GetAttribute("Sector")
	if type(sector) ~= "string" or not fixture:IsA("BasePart") then
		return
	end
	local on = powered[sector] ~= false
	fixture:SetAttribute("Powered", on)
	local onColor = fixture:GetAttribute("OnColor")
	fixture.Color = if on then (if typeof(onColor) == "Color3" then onColor else fixture.Color) else OFF_COLOR
	for _, child in fixture:GetChildren() do
		if child:IsA("Light") then
			child.Enabled = on
			if typeof(onColor) == "Color3" then
				child.Color = onColor
			end
		end
	end
end

function PowerService.IsOn(sector: string): boolean
	return powered[sector] ~= false
end

function PowerService.Set(sector: string, on: boolean)
	powered[sector] = on
	SessionState.Set("Power_" .. sector, on)
	for _, fixture in CollectionService:GetTagged("FZ_SectorLight") do
		if fixture:GetAttribute("Sector") == sector then
			applyLight(fixture)
		end
	end
	if doorService then
		for _, panel in CollectionService:GetTagged("FZ_Door") do
			if panel:GetAttribute("PowerSector") == sector then
				doorService.SetLocked(panel, not on)
			end
		end
	end
end

function PowerService.Reset()
	-- sectors a chapter switched off that have no default come back on
	for sector in table.clone(powered) do
		if DEFAULT[sector] == nil then
			PowerService.Set(sector, true)
		end
	end
	for sector, on in DEFAULT do
		PowerService.Set(sector, on)
	end
end

function PowerService.Start(injectedDoorService)
	doorService = injectedDoorService
	CollectionService:GetInstanceAddedSignal("FZ_SectorLight"):Connect(applyLight)
	PowerService.Reset()
end

return PowerService

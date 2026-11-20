-- StoryService: sends story content (subtitles, documents, objectives) to clients.
-- Only localization KEYS travel over the network; every client renders them in its own
-- language. Targets can be a single player (individual perception) or "all".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local SessionState = require(Shared.SessionState)

local StoryService = {}

export type Line = {
	text: string, -- localization key
	speaker: string?, -- localization key
	params: { [string]: any }?,
	duration: number?,
	channel: string?, -- "radio" | "world" | "sfx"
	critical: boolean?, -- shown even with subtitles off (safety-relevant sounds)
	delay: number?, -- seconds to wait before this line (Sequence only)
}

type Target = Player | "all"

local subtitleRemote = Net.Event("Subtitle")
local documentRemote = Net.Event("Document")
local flags: { [string]: any } = {}

function StoryService.Say(target: Target, line: Line)
	if target == "all" then
		subtitleRemote:FireAllClients(line)
	else
		subtitleRemote:FireClient(target :: Player, line)
	end
end

function StoryService.Sequence(target: Target, lines: { Line })
	task.spawn(function()
		for _, line in lines do
			if line.delay then
				task.wait(line.delay)
			end
			if target ~= "all" and (target :: Player).Parent == nil then
				return
			end
			StoryService.Say(target, line)
		end
	end)
end

function StoryService.ShowDocument(player: Player, document: { [string]: any })
	documentRemote:FireClient(player, document)
end

function StoryService.SetObjective(key: string?)
	SessionState.Set("Objective", key)
end

function StoryService.GetObjective(): string?
	return SessionState.Get("Objective")
end

-- Session flags are shared by the whole team and replicated as "Flag_<name>".
function StoryService.SetFlag(name: string, value: any)
	flags[name] = value
	SessionState.Set("Flag_" .. name, value)
end

function StoryService.GetFlag(name: string): any
	return flags[name]
end

return StoryService

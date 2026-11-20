-- Redeemable codes. Lives in ServerStorage: never replicated to clients.
-- Key = exactly what the player types (normalized: uppercase, no whitespace).
-- id   = stable save id. Never reuse or rename an id, or players could redeem twice.
-- Each code must be physically findable in the world (see docs/GAME_DESIGN.md, "Codes").

return {
	-- Lobby notice board, maintenance note (Chapter 1).
	["SIGNAL-017"] = { id = "signal_017", reward = { signalMarks = 25 }, active = true },
	-- Gatehouse logbook, last line (Chapter 1).
	["VESPER-0214"] = { id = "vesper_0214", reward = { signalMarks = 40 }, active = true },
}

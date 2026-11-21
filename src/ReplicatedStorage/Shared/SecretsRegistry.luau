-- Community secrets: puzzles hidden in the maps, fully solvable inside the game.
-- Public part only (what unlocks, rewards). The ANSWERS live in
-- ServerStorage/Secrets/SecretAnswers.luau and never reach a client.
-- Add a new secret: one entry here + one answer there + its archive file in Lore.luau.

return {
	{
		id = "zero_frequency",
		unlock = "file_null", -- archive entry revealed when solved
		marks = 250,
		-- in-world clues: the fax time (02:14), June's tape (41 minutes), the core screen (run 0007)
	},
}

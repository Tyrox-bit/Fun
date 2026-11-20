-- Who may use the owner/maintenance tools.
-- Authorization is ALWAYS decided here on the server. The in-game "gesture code" only
-- reveals the menu for people who are already authorized; it never grants rights.

return {
	-- Additional developer UserIds (numbers). The experience owner is detected automatically:
	-- * user-owned experience: game.CreatorId
	-- * group-owned experience: members with rank >= MinGroupRank in the owning group
	UserIds = {
		-- 123456789,
	},
	MinGroupRank = 254,

	-- Everyone who can open the place in Studio is a developer of it, so Studio test
	-- sessions are authorized by default. Set to false to test the "denied" path.
	AllowAllInStudio = true,
}

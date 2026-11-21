-- Achievements: clear conditions, one-time server-side rewards, no daily obligations.
-- Conditions are checked where the event happens (see AchievementService.Award calls).

return {
	{ id = "first_contact", name = "ACH_FIRST_CONTACT", description = "ACH_FIRST_CONTACT_DESC", marks = 50 },
	{ id = "unseen", name = "ACH_UNSEEN", description = "ACH_UNSEEN_DESC", marks = 300 },
	{ id = "archivist", name = "ACH_ARCHIVIST", description = "ACH_ARCHIVIST_DESC", marks = 250 },
	{ id = "last_survivor", name = "ACH_LAST_SURVIVOR", description = "ACH_LAST_SURVIVOR_DESC", marks = 300 },
	{ id = "nobody_left", name = "ACH_NOBODY_LEFT", description = "ACH_NOBODY_LEFT_DESC", marks = 250 },
	{ id = "forecast_breaker", name = "ACH_BREAKER", description = "ACH_BREAKER_DESC", marks = 100 },
	{ id = "night_shift_10", name = "ACH_SHIFT10", description = "ACH_SHIFT10_DESC", marks = 400 },
	{ id = "decoder", name = "ACH_DECODER", description = "ACH_DECODER_DESC", marks = 200 },
	{ id = "rescuer", name = "ACH_RESCUER", description = "ACH_RESCUER_DESC", marks = 100 },
}

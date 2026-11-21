-- Archive entries (DAS ARCHIV). Every entry has a permanent id saved in data.secrets.logs.
--   category: photo | report | tape | observation | radio | confidential | past | insight
--   links:    insights unlock automatically once every linked entry has been found
--   photo:    rendered live from avatar copies (see EvidenceService / PhotoView)
-- New entries for new chapters are simply appended here (+ texts in the language files).

return {
	-- Chapter 1 · Relay Station 07
	{ id = "rec_c1_arrival", category = "radio", title = "ARCH_REC_ARRIVAL_TITLE", body = "ARCH_REC_ARRIVAL_BODY", map = "relay07" },
	{ id = "rec_c1_relay", category = "radio", title = "ARCH_REC_RELAY_TITLE", body = "ARCH_REC_RELAY_BODY", map = "relay07" },
	{ id = "calendar_2009", category = "past", title = "CAL_TITLE", body = "CAL_BODY", map = "relay07" },
	{ id = "log_okafor", category = "tape", title = "LOG_OKAFOR_TITLE", body = "LOG_OKAFOR_BODY", map = "relay07" },
	{ id = "log_venn", category = "report", title = "LOG_VENN_TITLE", body = "LOG_VENN_BODY", map = "relay07" },
	{ id = "log_ehle", category = "observation", title = "LOG_EHLE_TITLE", body = "LOG_EHLE_BODY", map = "relay07" },
	{ id = "log_0006", category = "confidential", title = "LOG_0006_TITLE", body = "LOG_0006_BODY", map = "relay07" },
	{ id = "photo_past_self", category = "photo", title = "PHOTO_PAST_TITLE", body = "PHOTO_PAST_BODY", map = "relay07", photo = "past_self" },
	{ id = "photo_team_future", category = "photo", title = "PHOTO_FUTURE_TITLE", body = "PHOTO_FUTURE_BODY", map = "relay07", photo = "team_future" },
	{ id = "photo_mate_dark", category = "photo", title = "PHOTO_DARK_TITLE", body = "PHOTO_DARK_BODY", map = "relay07", photo = "mate_dark" },
	-- Insights: connections between documents (optional secrets)
	{ id = "insight_same_words", category = "insight", title = "INSIGHT_WORDS_TITLE", body = "INSIGHT_WORDS_BODY", map = "relay07", links = { "log_okafor", "rec_c1_relay" }, reward = 100 },
	{ id = "insight_how_long", category = "insight", title = "INSIGHT_LOOP_TITLE", body = "INSIGHT_LOOP_BODY", map = "relay07", links = { "log_0006", "photo_past_self", "calendar_2009" }, reward = 150 },
	-- Community secret (see Shared/SecretsRegistry): only unlocked by solving it
	{ id = "file_null", category = "confidential", title = "FILE_NULL_TITLE", body = "FILE_NULL_BODY", map = "relay07", secret = true },
}

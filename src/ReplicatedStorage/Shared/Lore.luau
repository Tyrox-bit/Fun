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
	-- Chapter 2 · Staumauer 3
	{ id = "rec_c2_arrival", category = "radio", title = "ARCH_REC_C2_ARRIVAL_TITLE", body = "ARCH_REC_C2_ARRIVAL_BODY", map = "dam03" },
	{ id = "rec_c2_plea", category = "radio", title = "ARCH_REC_C2_PLEA_TITLE", body = "ARCH_REC_C2_PLEA_BODY", map = "dam03" },
	{ id = "c2_keeper_log", category = "report", title = "C2_KEEPER_TITLE", body = "C2_KEEPER_BODY", map = "dam03" },
	{ id = "c2_correction_1", category = "confidential", title = "C2_CORR1_TITLE", body = "C2_CORR1_BODY", map = "dam03" },
	{ id = "c2_correction_2", category = "confidential", title = "C2_CORR2_TITLE", body = "C2_CORR2_BODY", map = "dam03" },
	{ id = "c2_correction_3", category = "confidential", title = "C2_CORR3_TITLE", body = "C2_CORR3_BODY", map = "dam03" },
	{ id = "c2_coffee", category = "observation", title = "C2_COFFEE_TITLE", body = "C2_COFFEE_BODY", map = "dam03" },
	{ id = "c2_dorm_tape", category = "tape", title = "C2_DORM_TITLE", body = "C2_DORM_BODY", map = "dam03" },
	{ id = "log_kessler", category = "tape", title = "LOG_KESSLER_TITLE", body = "LOG_KESSLER_BODY", map = "dam03" },
	{ id = "insight_corrections", category = "insight", title = "INSIGHT_CORR_TITLE", body = "INSIGHT_CORR_BODY", map = "dam03", links = { "c2_correction_1", "c2_correction_2", "c2_correction_3" }, reward = 150 },
	-- Chapter 3 · Kapelle
	{ id = "c3_memorial", category = "past", title = "C3_MEMORIAL_TITLE", body = "C3_MEMORIAL_BODY", map = "church" },
	{ id = "c3_hymn", category = "observation", title = "C3_HYMN_TITLE", body = "C3_HYMN_BODY", map = "church" },
	{ id = "c3_priest_note", category = "report", title = "C3_PRIEST_TITLE", body = "C3_PRIEST_BODY", map = "church" },
	{ id = "c3_index_card", category = "report", title = "C3_INDEX_TITLE", body = "C3_INDEX_BODY", map = "church" },
	{ id = "log_marek", category = "tape", title = "LOG_MAREK_TITLE", body = "LOG_MAREK_BODY", map = "church" },
	{ id = "rec_c3_run0007", category = "confidential", title = "ARCH_REC_C3_RUN_TITLE", body = "ARCH_REC_C3_RUN_BODY", map = "church" },
	{ id = "insight_six", category = "insight", title = "INSIGHT_SIX_TITLE", body = "INSIGHT_SIX_BODY", map = "church", links = { "c3_memorial", "log_kessler", "log_marek" }, reward = 150 },
	-- Chapter 4 · Mine
	{ id = "rec_c4_arrival", category = "radio", title = "ARCH_REC_C4_ARRIVAL_TITLE", body = "ARCH_REC_C4_ARRIVAL_BODY", map = "mine" },
	{ id = "c4_mine_notice", category = "past", title = "C4_NOTICE_TITLE", body = "C4_NOTICE_BODY", map = "mine" },
	{ id = "c4_shift_log", category = "report", title = "C4_SHIFT_TITLE", body = "C4_SHIFT_BODY", map = "mine" },
	{ id = "c4_loop_tape", category = "tape", title = "C4_LOOP_TITLE", body = "C4_LOOP_BODY", map = "mine" },
	{ id = "insight_june", category = "insight", title = "INSIGHT_JUNE_TITLE", body = "INSIGHT_JUNE_BODY", map = "mine", links = { "log_okafor", "c4_loop_tape", "rec_c3_run0007" }, reward = 200 },
	-- Community secret (see Shared/SecretsRegistry): only unlocked by solving it
	{ id = "file_null", category = "confidential", title = "FILE_NULL_TITLE", body = "FILE_NULL_BODY", map = "relay07", secret = true },
}

class_name HighScores
extends RefCounted

## Persistent top-5 high score leaderboard for Assault Flight.
##
## Uses static state so scores survive scene reloads (same pattern as
## GameSettings / MainMenu.quick_start) and saves to user:// so the board
## persists across game restarts.

const SCORES_PATH := "user://highscores.cfg"
## How many entries the leaderboard keeps.
const MAX_ENTRIES := 5
## Sorting key in each entry dictionary.
const SCORE_KEY := "score"
const DATE_KEY := "date"

## Sorted highest-first list of { "score": int, "date": String }.
static var _scores: Array[Dictionary] = []
## Guards ensure_loaded() so the disk read happens at most once per process.
static var _loaded := false


## Loads the saved scores from disk once (empty board on first run), validating
## entries and trimming to MAX_ENTRIES.
static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(SCORES_PATH) != OK:
		return
	var raw: Array = cfg.get_value("leaderboard", "entries", [])
	for entry: Variant in raw:
		if not (entry is Dictionary):
			continue
		var score := int(entry.get("score", 0))
		if score <= 0:
			continue
		_scores.append({"score": score, "date": str(entry.get("date", ""))})
	_sort_and_trim()


## Submits a run's score to the leaderboard. Only positive scores enter the
## board (a 0-point run doesn't pollute it). Returns true only when the new run
## becomes the #1 score (drives the "NEW HIGH SCORE!" callout).
static func submit(score: int) -> bool:
	ensure_loaded()
	if score <= 0:
		return false
	var was_best := best()
	_scores.append({"score": score, "date": Time.get_date_string_from_system()})
	_sort_and_trim()
	save()
	return score > was_best


## The current best score (0 if the board is empty).
static func best() -> int:
	ensure_loaded()
	if _scores.is_empty():
		return 0
	return _scores[0].get(SCORE_KEY, 0)


## A multi-line string of the leaderboard, e.g.:
##   HIGH SCORES
##   1. 1234 — 2025-01-01
##   ...
##   (or "No scores yet" when empty)
static func board_text() -> String:
	ensure_loaded()
	if _scores.is_empty():
		return "No scores yet"
	var lines := PackedStringArray(["HIGH SCORES"])
	for i in range(_scores.size()):
		var entry: Dictionary = _scores[i]
		lines.append("%d. %d — %s" % [i + 1, int(entry.get(SCORE_KEY, 0)), str(entry.get(DATE_KEY, ""))])
	return "\n".join(lines)


## The ranked rows without the "HIGH SCORES" header, for embedding under a
## panel's own title (e.g. the main-menu leaderboard popup).
static func entries_text() -> String:
	ensure_loaded()
	if _scores.is_empty():
		return "No scores yet"
	var lines := PackedStringArray()
	for i in range(_scores.size()):
		var entry: Dictionary = _scores[i]
		lines.append("%d. %d — %s" % [i + 1, int(entry.get(SCORE_KEY, 0)), str(entry.get(DATE_KEY, ""))])
	return "\n".join(lines)


## Sorts the board highest-first and keeps only the top MAX_ENTRIES.
static func _sort_and_trim() -> void:
	_scores.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get(SCORE_KEY, 0)) > int(b.get(SCORE_KEY, 0))
	)
	if _scores.size() > MAX_ENTRIES:
		_scores.resize(MAX_ENTRIES)


## Writes the current board to user://highscores.cfg.
static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("leaderboard", "entries", _scores)
	cfg.save(SCORES_PATH)
extends RefCounted

# Safety replies for the text chat. Checked before anything else the pet says.
#  - Self-harm ("I want to die", "kill myself"): a caring reply, and a note for a
#    grown-up (grownup_overlay) that comes back every time the chat opens until
#    they tap "I've checked in".
#  - A figure of speech ("this is so embarrassing I want to die") is fine: only the
#    soft phrases are excused, and only with an embarrassment cue.
#  - Someone hurting or touching them: "That's not your fault", Childhelp number.
#    No grown-up alert for this one on purpose: the person hurting them could be
#    the grown-up.
# Only the time of an alert is saved, never what was typed.

const CRISIS_PHRASES := [
	"want to die", "wanna die", "wish i was dead", "wish i were dead", "want to be dead", "kill myself", "kill me",
	"killing myself", "end my life", "end it all", "suicide", "suicidal", "hurt myself", "harm myself", "cut myself",
	"dont want to live", "do not want to live", "dont wanna live", "better off dead", "no reason to live",
	"dont want to be alive", "do not want to be alive", "want to disappear forever", "going to kill myself",
]
const SOFT_PHRASES := ["want to die", "wanna die", "kill me", "want to be dead", "wish i was dead", "wish i were dead"]
const FIGURATIVE_CUES := ["embar", "enbar", "emabar", "awkward", "cringe", "morti"]
const NOT_PHRASES := ["dont want to die", "do not want to die", "not want to die", "never kill myself", "wont kill myself", "would never hurt myself", "not going to hurt myself"]

const CRISIS_REPLY := "I'm so glad you told me. 💛 You matter so much, and I care about you. This is too big for me to help with by myself, so please go tell a grown-up you trust right now, like mom, dad or a teacher. You are not alone. 🫂"
const ABUSE_REPLY := "I'm so sorry. 💛 That's not your fault. Nobody should ever hurt you, and you did nothing wrong. You were brave to tell me. 🫂 Please tell a grown-up you trust who isn't hurting you, like a teacher, a school counsellor, a relative or a friend's parent. You can also call or text Childhelp any time: 1-800-422-4453. If you are in danger right now, call 911."
const GRIEF_REPLY := "Oh, I'm so sorry. 💛 Losing someone you love is really hard, and it's okay to feel sad. They were lucky to have you. 🫂 Do you want to tell me about them?"

const ADULTS := ["dad", "mom", "mother", "father", "stepdad", "stepmom", "uncle", "aunt", "brother", "sister", "teacher", "babysitter", "boyfriend", "girlfriend", "coach", "grandpa", "grandma", "someone", "he", "she", "they", "parent", "parents", "family", "neighbor", "stranger"]
const FAMILY := ["dad", "mom", "mother", "father", "stepdad", "stepmom", "uncle", "aunt", "grandpa", "grandma", "parent", "parents"]
const HARD_VERBS := ["hit", "hits", "hitting", "beat", "beats", "beating", "punch", "punches", "punched", "kick", "kicks", "kicked", "slap", "slaps", "slapped", "choke", "chokes", "choked", "grab", "grabs", "grabbed", "shove", "shoves", "shoved", "touch", "touches", "touched", "touching", "abuse", "abuses", "abused", "abusing"]
const SOFT_VERBS := ["hurt", "hurts", "hurting"]

static func _plain(text: String) -> String:
	var out := ""
	for ch in text.to_lower().replace("’", "").replace("'", ""):
		out += ch if (ch >= "a" and ch <= "z") else " "
	return " " + " ".join(out.split(" ", false)) + " "

static func _has_any(words: PackedStringArray, list: Array) -> bool:
	for w in list:
		if words.has(w):
			return true
	return false

# {} when the message is fine, otherwise {"say": reply, "alert": "crisis" or ""}.
static func check(text: String) -> Dictionary:
	var plain := _plain(text)
	var denied := false
	for n in NOT_PHRASES:
		if plain.contains(" " + n + " "):
			denied = true
	var figurative := false
	for cue in FIGURATIVE_CUES:
		if plain.contains(cue):
			figurative = true
	if not denied:
		for ph in CRISIS_PHRASES:
			if plain.contains(" " + ph + " "):
				if figurative and SOFT_PHRASES.has(ph):
					continue
				return {"say": CRISIS_REPLY, "alert": "crisis"}
	var words := plain.strip_edges().split(" ", false)
	var me := words.has("me") or words.has("my")
	var hard := _has_any(words, HARD_VERBS)
	var soft_ok := _has_any(words, FAMILY) and _has_any(words, SOFT_VERBS) and words.has("me")
	if soft_ok or (hard and me and _has_any(words, ADULTS + ["abuse", "abused"])):
		return {"say": ABUSE_REPLY, "alert": ""}
	if plain.contains(" died ") or plain.contains(" death ") or plain.contains(" passed away ") or plain.contains(" funeral ") or plain.contains(" put to sleep "):
		return {"say": GRIEF_REPLY, "alert": ""}
	return {}

# Two steps: a note for the child ("get a grown-up"), then one for the grown-up.
# `first_time` false = the reminder shown when the chat opens.
static func grownup_overlay(host: Control, first_time: bool = true) -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(overlay)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.23, 0.16, 0.16, 0.8)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 0.96, 0.98, 1)
	style.set_corner_radius_all(24)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.72, 0.31, 0.47, 1))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	var body := Label.new()
	body.add_theme_font_size_override("font_size", 20)
	body.add_theme_color_override("font_color", Color(0.3, 0.2, 0.3, 1))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)

	var grownup_step := func() -> void:
		for c in row.get_children():
			c.queue_free()
		title.text = "💛 For the grown-up"
		body.text = "Something typed to the pet suggests this player may be thinking about hurting themselves or not wanting to live.\n\nPlease check in with them calmly and kindly. Listen without judging, and don't leave them alone if you're worried.\n\nIn the US you can call or text 988 (Suicide & Crisis Lifeline) any time, or call 911 in an emergency. Elsewhere, findahelpline.com lists local services."
		var done := Button.new()
		done.text = "I've checked in"
		done.add_theme_font_size_override("font_size", 20)
		done.pressed.connect(func() -> void:
			PetalState.clear_safety_alerts()
			overlay.queue_free())
		row.add_child(done)
		var later := Button.new()
		later.text = "Remind me later"
		later.add_theme_font_size_override("font_size", 20)
		later.pressed.connect(overlay.queue_free)
		row.add_child(later)
	if first_time:
		title.text = "💛 Please get a grown-up"
		body.text = "You matter, and a grown-up you trust can help. Please find one now, like mom, dad or a teacher, and tap the button when they're with you."
		var here := Button.new()
		here.text = "A grown-up is here"
		here.add_theme_font_size_override("font_size", 20)
		here.pressed.connect(grownup_step)
		row.add_child(here)
	else:
		grownup_step.call()

extends Node

const VisitorExport = preload("res://scripts/visitor_check.gd")

# Care stats for Princess Petal. All stats are 0-100; 100 is best.
# Decay is slow and mood language stays gentle - this is a game for a
# 5-year-old, so nothing here should ever feel like "failing".

signal stats_changed
signal accessories_changed
signal perch_decor_changed
signal play_animation_requested
signal bell_animation_requested
signal friend_changed
signal sticker_earned
signal navigate_to_room(room_id: String)
signal photo_taken
signal pet_changed
signal coins_changed
signal milestone_reached(total: int)

const MAX_STAT := 100.0
const DECAY_PER_SEC := 0.15

# Every playable pet: display name, sit pose, optional frame-based
# animations (walk/jump/sleep/dance/play - omitted if the pet doesn't have
# art for it yet, in which case PetCameo falls back to simple tweens), and
# her dress-up accessories (icon + overlay anchor, proportional to her
# TextureRect so it lands right no matter which room-sized box she's in).
# "exclusive_groups" lists accessory ids that can't be worn together (e.g.
# only one collar at a time) - toggling one off clears the rest.
const PETS := {
	"petal": {
		"name": "Princess Petal",
		"species": "cat",
		"cutout": "res://Sprites/petal_cutout.png",
		"walk": {"path": "res://Sprites/petal_walk/frame_%02d.png", "count": 10},
		"jump": {"path": "res://Sprites/petal_jump/frame_%02d.png", "count": 5},
		"sleep": {"path": "res://Sprites/petal_sleep/frame_%02d.png", "count": 11},
		"dance": {"path": "res://Sprites/petal_dance/frame_%02d.png", "count": 10},
		"play": {"path": "res://Sprites/petal_play/frame_%02d.png", "count": 10},
		"inline_play": true,
		"blowdried": "res://Sprites/petal_blowdried.png",
		"accessories": {
			"bow": {"icon": "res://Sprites/bow.png", "anchor": {"l": 0.327, "t": 0.025, "r": 0.427, "b": 0.196}, "cost": 0},
			"flower": {"icon": "res://Sprites/flower.png", "anchor": {"l": 0.573, "t": 0.025, "r": 0.673, "b": 0.196}, "cost": 0},
			"sunglasses": {"icon": "res://Sprites/sunglasses.png", "anchor": {"l": 0.373, "t": 0.294, "r": 0.633, "b": 0.491}, "cost": 15},
			"scarf": {"icon": "res://Sprites/scarf.png", "anchor": {"l": 0.333, "t": 0.515, "r": 0.667, "b": 0.699}, "cost": 15},
			"blush": {"icon": "res://Sprites/blush.png", "anchor": {"l": 0.28, "t": 0.32, "r": 0.72, "b": 0.5}, "cost": 10},
			"mascara": {"icon": "res://Sprites/mascara.png", "anchor": {"l": 0.373, "t": 0.294, "r": 0.633, "b": 0.44}, "cost": 10},
			"lipstick": {"icon": "res://Sprites/lipstick.png", "anchor": {"l": 0.40, "t": 0.44, "r": 0.60, "b": 0.52}, "cost": 10},
		},
		"exclusive_groups": [],
	},
	"noodles": {
		"name": "Noodles",
		"species": "cat",
		# The ETCGAME kitten art as drawn. Her frames are a seated kitten, so
		# idle stands in for walking and happy for jumping.
		"cutout": "res://Sprites/noodles_cutout.png",
		"walk": {"path": "res://Sprites/noodles_idle/frame_%02d.png", "count": 9},
		"jump": {"path": "res://Sprites/noodles_happy/frame_%02d.png", "count": 9},
		"dance": {"path": "res://Sprites/noodles_happy/frame_%02d.png", "count": 9},
		"play": {"path": "res://Sprites/noodles_wave/frame_%02d.png", "count": 9},
		"inline_play": true,
		"accessories": {
			"crown_gold": {"icon": "res://Sprites/crown_gold.png", "anchor": {"l": 0.33, "t": 0.06, "r": 0.63, "b": 0.22}},
			"crown_silver": {"icon": "res://Sprites/crown_silver.png", "anchor": {"l": 0.33, "t": 0.06, "r": 0.63, "b": 0.22}},
			"crown_tiara": {"icon": "res://Sprites/crown_tiara.png", "anchor": {"l": 0.33, "t": 0.06, "r": 0.63, "b": 0.22}},
			"crown_flower": {"icon": "res://Sprites/crown_flower.png", "anchor": {"l": 0.33, "t": 0.06, "r": 0.63, "b": 0.22}},
		},
		# One crown at a time.
		"exclusive_groups": [["crown_gold", "crown_silver", "crown_tiara", "crown_flower"]],
		"rooms": {
			"bedroom": "res://Sprites/backgrounds/noodles_bedroom.jpg",
		},
	},
	"stardust": {
		"name": "Stardust",
		"species": "cat",
		# A Bengal drawn by Gemini - one picture per pose rather than frame
		# sets, so most animations are single stills (see PetCameo).
		"cutout": "res://Sprites/bengal_cutout.png",
		"walk": {"path": "res://Sprites/stardust_walk_gem/frame_%02d.png", "count": 8},
		"jump": {"path": "res://Sprites/stardust_jump_gem/frame_%02d.png", "count": 8},
		"eat": {"path": "res://Sprites/stardust_eat/frame_%02d.png", "count": 3},
		"pet_still": "res://Sprites/pj_pets_stardust.png",
		"cuddle": {"path": "res://Sprites/pj_carry_stardust/frame_%02d.png", "count": 8},
		"sleep": {"path": "res://Sprites/stardust_sleep_gem/frame_%02d.png", "count": 8},
		"dance": {"path": "res://Sprites/stardust_dance_gem/frame_%02d.png", "count": 8},
		"swim": {"path": "res://Sprites/stardust_swim_gem/frame_%02d.png", "count": 8},
		"brush": {"path": "res://Sprites/pj_brush_stardust/frame_%02d.png", "count": 8},
		"bath_comic": {"path": "res://Sprites/stardust_bath_comic/frame_%02d.png", "count": 8},
		"play": {"path": "res://Sprites/pj_mouse_stardust/frame_%02d.png", "count": 8},
		"jump_still": "res://Sprites/bengal_poses/jump_forward.png",
		"sleep_still": "res://Sprites/bengal_poses/sleep.png",
		"dance_still": "res://Sprites/bengal_poses/dance.png",
		"play_still": "res://Sprites/bengal_poses/play.png",
		# Unicorn horns to wear in the Dress-Up room, one at a time.
		"accessories": {
			"bow": {"icon": "res://Sprites/bow.png", "anchor": {"l": 0.17, "t": 0.04, "r": 0.39, "b": 0.22}},
			"horn_gold": {"icon": "res://Sprites/stardust_horns/gold.png", "anchor": {"l": 0.52, "t": -0.10, "r": 0.63, "b": 0.16}},
			"horn_rainbow": {"icon": "res://Sprites/stardust_horns/rainbow.png", "anchor": {"l": 0.52, "t": -0.10, "r": 0.63, "b": 0.16}},
			"horn_pink": {"icon": "res://Sprites/stardust_horns/pink.png", "anchor": {"l": 0.52, "t": -0.10, "r": 0.63, "b": 0.16}},
			"horn_crystal": {"icon": "res://Sprites/stardust_horns/crystal.png", "anchor": {"l": 0.52, "t": -0.10, "r": 0.63, "b": 0.16}},
		},
		"exclusive_groups": [["horn_gold", "horn_rainbow", "horn_pink", "horn_crystal"]],
		"rooms": {
			"bedroom": "res://Sprites/backgrounds/noodles_bedroom.jpg",
		},
	},
	"pompom": {
		"name": "Pompom",
		"species": "dog",
		"cutout": "res://Sprites/pompom_cutout.png",
		"walk": {"path": "res://Sprites/pompom_walk/frame_%02d.png", "count": 11},
		"jump": {"path": "res://Sprites/pompom_jump/frame_%02d.png", "count": 7},
		"sleep": {"path": "res://Sprites/pompom_sleep/frame_%02d.png", "count": 10},
		"trick_come": {"path": "res://Sprites/pompom_come_trick/frame_%02d.png", "count": 9},
		"trick_wave": {"path": "res://Sprites/pompom_wave_trick/frame_%02d.png", "count": 6},
		"brush": {"path": "res://Sprites/pompom_brush/frame_%02d.png", "count": 10},
		"dance": {"path": "res://Sprites/pompom_dance/frame_%02d.png", "count": 12},
		"swim": {"path": "res://Sprites/pompom_swim/frame_%02d.png", "count": 16},
		"eat": {"path": "res://Sprites/pompom_eat/frame_%02d.png", "count": 4},
		"bath_comic": {"path": "res://Sprites/pompom_bath_comic/frame_%02d.png", "count": 14},
		"wave": "res://Sprites/pompom_wave.png",
		"sleep_still": "res://Sprites/pompom_sleep_pose.png",
		"come_still": "res://Sprites/pompom_come_pose.png",
		"accessories": {
			"blush": {"icon": "res://Sprites/blush.png", "anchor": {"l": 0.03, "t": 0.28, "r": 0.50, "b": 0.52}, "cost": 10},
			"mascara": {"icon": "res://Sprites/mascara.png", "anchor": {"l": 0.06, "t": 0.26, "r": 0.40, "b": 0.38}, "cost": 10},
			"lipstick": {"icon": "res://Sprites/lipstick.png", "anchor": {"l": 0.12, "t": 0.42, "r": 0.35, "b": 0.53}, "cost": 10},
		},
		"exclusive_groups": [],
		"tricks": ["sit", "come", "wave"],
		"friends": ["coco", "biscuit"],
		"rooms": {
			"bedroom": "res://Sprites/backgrounds/pompom_bedroom.jpg",
		},
	},
	"sheila": {
		"name": "Sheila",
		"species": "dog",
		"cutout": "res://Sprites/sheila_cutout.png",
		# Sheila shares Pompom's dog-themed rooms and collar wardrobe, but has
		# her own full set of frame animations (and a bath background just
		# for her - the tub art was drawn with her specifically in it).
		"walk": {"path": "res://Sprites/sheila_walk/frame_%02d.png", "count": 7},
		"jump": {"path": "res://Sprites/sheila_jump/frame_%02d.png", "count": 5},
		"sleep": {"path": "res://Sprites/sheila_sleep/frame_%02d.png", "count": 6},
		"dance": {"path": "res://Sprites/sheila_dance/frame_%02d.png", "count": 9},
		"trick_sit": {"path": "res://Sprites/sheila_sit_trick/frame_%02d.png", "count": 5},
		"trick_wave": {"path": "res://Sprites/sheila_wave_trick/frame_%02d.png", "count": 7},
		"swim": {"path": "res://Sprites/sheila_swim/frame_%02d.png", "count": 16},
		"brush": {"path": "res://Sprites/sheila_brush/frame_%02d.png", "count": 5},
		"eat": {"path": "res://Sprites/sheila_eat/frame_%02d.png", "count": 4},
		"accessories": {
			"collar_pink": {"icon": "res://Sprites/pompom_collars/pink.png", "anchor": {"l": 0.15, "t": 0.56, "r": 0.85, "b": 0.82}, "cost": 0},
			"collar_lavender": {"icon": "res://Sprites/pompom_collars/lavender.png", "anchor": {"l": 0.15, "t": 0.56, "r": 0.85, "b": 0.82}, "cost": 20},
			"collar_blue": {"icon": "res://Sprites/pompom_collars/blue.png", "anchor": {"l": 0.15, "t": 0.56, "r": 0.85, "b": 0.82}, "cost": 20},
			"collar_green": {"icon": "res://Sprites/pompom_collars/green.png", "anchor": {"l": 0.15, "t": 0.56, "r": 0.85, "b": 0.82}, "cost": 20},
		},
		"exclusive_groups": [["collar_pink", "collar_lavender", "collar_blue", "collar_green"]],
		"rooms": {
			"bedroom": "res://Sprites/backgrounds/pompom_bedroom.jpg",
			"bath": "res://Sprites/backgrounds/sheila_bath.jpg",
		},
		"tricks": ["sit", "come", "wave"],
		"friends": ["coco", "biscuit"],
	},
	"kiwi": {
		"name": "Kiwi",
		"species": "bird",
		"cutout": "res://Sprites/kiwi_cutout.png",
		# Kiwi flies in instead of walking, and has a single flying hero
		# pose she strikes for Jump for Joy (no frames needed - see
		# PetCameo._bounce_tween, which checks for "jump_still").
		"walk": {"path": "res://Sprites/kiwi_walk/frame_%02d.png", "count": 5},
		"jump_still": "res://Sprites/kiwi_jump_pose.png",
		"trick_sing": {"path": "res://Sprites/kiwi_sing_trick/frame_%02d.png", "count": 6},
		"toy_bell": {"path": "res://Sprites/kiwi_bell_toy/frame_%02d.png", "count": 6},
		"eat": {"path": "res://Sprites/kiwi_eat/frame_%02d.png", "count": 5},
		"play_still": "res://Sprites/lucy_and_kiwi.png",
		# A little illustrated comic of Lucy brushing her, shown instead of
		# the generic disembodied-hand brush animation (see room_grooming.gd).
		"brush": {"path": "res://Sprites/kiwi_brush/frame_%02d.png", "count": 8},
		"bath_comic": {"path": "res://Sprites/kiwi_bath_comic/frame_%02d.png", "count": 8},
		"accessories": {},
		"exclusive_groups": [],
		"rooms": {
			"grooming": "res://Sprites/backgrounds/bird_grooming.jpg",
			"dressup": "res://Sprites/backgrounds/bird_dressup.jpg",
			# A big cozy perch stand in place of Petal's bed - the bed/toy/
			# feeder are each optional (see perch_items/perch_combos below),
			# this is just the fallback if that lookup ever comes up empty.
			"bedroom": "res://Sprites/backgrounds/kiwi_perch_bed_feeder_toy.jpg",
		},
		# Toggleable perch decorations. Each combo was hand-painted as its own
		# flat image (not a layered overlay), so the lookup key is the sorted,
		# comma-joined list of active item ids - see perch_background_path().
		"perch_items": ["bed", "toy", "feeder"],
		"perch_combos": {
			"": "res://Sprites/backgrounds/kiwi_perch_base.jpg",
			"bed": "res://Sprites/backgrounds/kiwi_perch_bed.jpg",
			"toy": "res://Sprites/backgrounds/kiwi_perch_toy.jpg",
			"feeder": "res://Sprites/backgrounds/kiwi_perch_feeder.jpg",
			"bed,toy": "res://Sprites/backgrounds/kiwi_perch_bed_toy.jpg",
			"bed,feeder": "res://Sprites/backgrounds/kiwi_perch_bed_feeder.jpg",
			"bed,feeder,toy": "res://Sprites/backgrounds/kiwi_perch_bed_feeder_toy.jpg",
		},
		"tricks": ["sing"],
		"friends": ["raspberry", "seafoam"],
	},
	"gerbil": {
		"name": "Pumpkin",
		"species": "gerbil",
		"cutout": "res://Sprites/gerbil_cutout.png",
		"sleep_still": "res://Sprites/gerbil_sleep_pose.png",
		"dig": {"path": "res://Sprites/gerbil_dig/frame_%02d.png", "count": 6},
		"walk": {"path": "res://Sprites/gerbil_walk/frame_%02d.png", "count": 9},
		"eat": {"path": "res://Sprites/gerbil_eat/frame_%02d.png", "count": 6},
		"play": {"path": "res://Sprites/gerbil_play/frame_%02d.png", "count": 9},
		"dance": {"path": "res://Sprites/gerbil_dance/frame_%02d.png", "count": 10},
		"brush": {"path": "res://Sprites/gerbil_brush/frame_%02d.png", "count": 10},
		"bath_comic": {"path": "res://Sprites/gerbil_bath_comic/frame_%02d.png", "count": 3},
		"accessories": {},
		"exclusive_groups": [],
		"friends": ["pebble"],
		"rooms": {
			"bedroom": "res://Sprites/backgrounds/gerbil_bedroom.jpg",
			"dressup": "res://Sprites/backgrounds/gerbil_dressup.jpg",
			"party": "res://Sprites/backgrounds/gerbil_party.jpg",
		},
	},
	"ginger": {
		"name": "Honeybun 🍯",
		"species": "cat",
		"cutout": "res://Sprites/ginger_cutout.png",
		"walk": {"path": "res://Sprites/ginger_run/frame_%02d.png", "count": 4},
		"jump": {"path": "res://Sprites/ginger_run/frame_%02d.png", "count": 4},
		"sleep": {"path": "res://Sprites/ginger_sleep/frame_%02d.png", "count": 5},
		"eat": {"path": "res://Sprites/ginger_eat/frame_%02d.png", "count": 4},
		"play": {"path": "res://Sprites/ginger_play/frame_%02d.png", "count": 4},
		"inline_play": true,
		"brush": {"path": "res://Sprites/ginger_brush/frame_%02d.png", "count": 2},
		"bath_comic": {"path": "res://Sprites/ginger_bath/frame_%02d.png", "count": 2},
		"accessories": {
			"bow": {"icon": "res://Sprites/bow.png", "anchor": {"l": 0.327, "t": 0.025, "r": 0.427, "b": 0.196}, "cost": 0},
			"flower": {"icon": "res://Sprites/flower.png", "anchor": {"l": 0.573, "t": 0.025, "r": 0.673, "b": 0.196}, "cost": 0},
			"sunglasses": {"icon": "res://Sprites/sunglasses.png", "anchor": {"l": 0.373, "t": 0.294, "r": 0.633, "b": 0.491}, "cost": 15},
			"scarf": {"icon": "res://Sprites/scarf.png", "anchor": {"l": 0.333, "t": 0.515, "r": 0.667, "b": 0.699}, "cost": 15},
		},
		"exclusive_groups": [],
	},
	# Pets added from separately supplied art. Each shows up in the picker only
	# once its cutout exists in Sprites/ (see available_pet_ids).
	"marshmallow": {
		"name": "Marshmallow",
		"species": "bunny",
		"cutout": "res://Sprites/marshmallow_cutout.png",
		"walk": {"path": "res://Sprites/marshmallow_walk/frame_%02d.png", "count": 2},
		"eat": {"path": "res://Sprites/marshmallow_eat/frame_%02d.png", "count": 2},
		"sleep_still": "res://Sprites/marshmallow_sleep_pose.png",
		"accessories": {
			# Ears-and-face anchors are first guesses - nudge them once the final art is in.
			"bow": {"icon": "res://Sprites/bow.png", "anchor": {"l": 0.36, "t": 0.02, "r": 0.50, "b": 0.16}, "cost": 0},
			"flower": {"icon": "res://Sprites/flower.png", "anchor": {"l": 0.52, "t": 0.02, "r": 0.66, "b": 0.16}, "cost": 0},
			"sunglasses": {"icon": "res://Sprites/sunglasses.png", "anchor": {"l": 0.30, "t": 0.28, "r": 0.70, "b": 0.44}, "cost": 15},
			"scarf": {"icon": "res://Sprites/scarf.png", "anchor": {"l": 0.30, "t": 0.52, "r": 0.70, "b": 0.72}, "cost": 15},
		},
		"exclusive_groups": [],
		"friends": ["fluff_friend", "bunbun_friend"],
	},
	"fluff": {
		"name": "Fluff",
		"species": "bunny",
		"cutout": "res://Sprites/fluff_cutout.png",
		"jump": {"path": "res://Sprites/fluff_jump/frame_%02d.png", "count": 4},
		"eat": {"path": "res://Sprites/fluff_eat/frame_%02d.png", "count": 4},
		"sleep": {"path": "res://Sprites/fluff_sleep/frame_%02d.png", "count": 4},
		"accessories": {
			# Ears-and-face anchors are first guesses - nudge them once the final art is in.
			"bow": {"icon": "res://Sprites/bow.png", "anchor": {"l": 0.36, "t": 0.02, "r": 0.50, "b": 0.16}, "cost": 0},
			"flower": {"icon": "res://Sprites/flower.png", "anchor": {"l": 0.52, "t": 0.02, "r": 0.66, "b": 0.16}, "cost": 0},
			"sunglasses": {"icon": "res://Sprites/sunglasses.png", "anchor": {"l": 0.30, "t": 0.28, "r": 0.70, "b": 0.44}, "cost": 15},
			"scarf": {"icon": "res://Sprites/scarf.png", "anchor": {"l": 0.30, "t": 0.52, "r": 0.70, "b": 0.72}, "cost": 15},
		},
		"exclusive_groups": [],
		"friends": ["marshmallow_friend", "bunbun_friend"],
	},
	"cotton": {
		"name": "Bunbun",
		"species": "bunny",
		"cutout": "res://Sprites/cotton_cutout.png",
		"play": {"path": "res://Sprites/cotton_play/frame_%02d.png", "count": 9},
		"inline_play": true,
		"accessories": {
			# Ears-and-face anchors are first guesses - nudge them once the final art is in.
			"bow": {"icon": "res://Sprites/bow.png", "anchor": {"l": 0.36, "t": 0.02, "r": 0.50, "b": 0.16}, "cost": 0},
			"flower": {"icon": "res://Sprites/flower.png", "anchor": {"l": 0.52, "t": 0.02, "r": 0.66, "b": 0.16}, "cost": 0},
			"sunglasses": {"icon": "res://Sprites/sunglasses.png", "anchor": {"l": 0.30, "t": 0.28, "r": 0.70, "b": 0.44}, "cost": 15},
			"scarf": {"icon": "res://Sprites/scarf.png", "anchor": {"l": 0.30, "t": 0.52, "r": 0.70, "b": 0.72}, "cost": 15},
		},
		"exclusive_groups": [],
		"friends": ["marshmallow_friend", "fluff_friend"],
	},
	"puppy": {
		"name": "Puppy",
		"species": "dog",
		"cutout": "res://Sprites/puppy_cutout.png",
		"walk": {"path": "res://Sprites/puppy_idle/frame_%02d.png", "count": 9},
		"jump": {"path": "res://Sprites/puppy_happy/frame_%02d.png", "count": 9},
		"dance": {"path": "res://Sprites/puppy_cheer/frame_%02d.png", "count": 9},
		"eat": {"path": "res://Sprites/puppy_eat/frame_%02d.png", "count": 9},
		"play": {"path": "res://Sprites/puppy_happy/frame_%02d.png", "count": 9},
		"inline_play": true,
		"accessories": {
			"collar_pink": {"icon": "res://Sprites/pompom_collars/pink.png", "anchor": {"l": 0.15, "t": 0.56, "r": 0.85, "b": 0.82}, "cost": 0},
			"collar_lavender": {"icon": "res://Sprites/pompom_collars/lavender.png", "anchor": {"l": 0.15, "t": 0.56, "r": 0.85, "b": 0.82}, "cost": 20},
			"collar_blue": {"icon": "res://Sprites/pompom_collars/blue.png", "anchor": {"l": 0.15, "t": 0.56, "r": 0.85, "b": 0.82}, "cost": 20},
			"collar_green": {"icon": "res://Sprites/pompom_collars/green.png", "anchor": {"l": 0.15, "t": 0.56, "r": 0.85, "b": 0.82}, "cost": 20},
		},
		"exclusive_groups": [["collar_pink", "collar_lavender", "collar_blue", "collar_green"]],
		"rooms": {
			"bedroom": "res://Sprites/backgrounds/pompom_bedroom.jpg",
		},
		"friends": ["coco", "biscuit"],
	},
	"brownie": {
		"name": "Brownie",
		"species": "dog",
		"cutout": "res://Sprites/brownie_cutout.png",
		"walk": {"path": "res://Sprites/brownie_happy/frame_%02d.png", "count": 4},
		"jump": {"path": "res://Sprites/brownie_cheer/frame_%02d.png", "count": 4},
		"dance": {"path": "res://Sprites/brownie_cheer/frame_%02d.png", "count": 4},
		"eat": {"path": "res://Sprites/brownie_eat/frame_%02d.png", "count": 4},
		"sleep": {"path": "res://Sprites/brownie_sleep/frame_%02d.png", "count": 4},
		"swim": {"path": "res://Sprites/brownie_swim/frame_%02d.png", "count": 4},
		"play": {"path": "res://Sprites/brownie_happy/frame_%02d.png", "count": 4},
		"inline_play": true,
		"accessories": {
			"collar_pink": {"icon": "res://Sprites/pompom_collars/pink.png", "anchor": {"l": 0.15, "t": 0.56, "r": 0.85, "b": 0.82}, "cost": 0},
			"collar_lavender": {"icon": "res://Sprites/pompom_collars/lavender.png", "anchor": {"l": 0.15, "t": 0.56, "r": 0.85, "b": 0.82}, "cost": 20},
			"collar_blue": {"icon": "res://Sprites/pompom_collars/blue.png", "anchor": {"l": 0.15, "t": 0.56, "r": 0.85, "b": 0.82}, "cost": 20},
			"collar_green": {"icon": "res://Sprites/pompom_collars/green.png", "anchor": {"l": 0.15, "t": 0.56, "r": 0.85, "b": 0.82}, "cost": 20},
		},
		"exclusive_groups": [["collar_pink", "collar_lavender", "collar_blue", "collar_green"]],
		"rooms": {
			"bedroom": "res://Sprites/backgrounds/pompom_bedroom.jpg",
		},
		"friends": ["coco", "biscuit"],
	},
	"pomeranian": {
		"name": "Honey",
		"species": "dog",
		"cutout": "res://Sprites/pomeranian_cutout.png",
		"walk": {"path": "res://Sprites/pomeranian_idle/frame_%02d.png", "count": 4},
		"jump": {"path": "res://Sprites/pomeranian_happy/frame_%02d.png", "count": 4},
		"dance": {"path": "res://Sprites/pomeranian_happy/frame_%02d.png", "count": 4},
		"play": {"path": "res://Sprites/pomeranian_happy/frame_%02d.png", "count": 4},
		"inline_play": true,
		"accessories": {
			"collar_pink": {"icon": "res://Sprites/pompom_collars/pink.png", "anchor": {"l": 0.15, "t": 0.56, "r": 0.85, "b": 0.82}, "cost": 0},
			"collar_lavender": {"icon": "res://Sprites/pompom_collars/lavender.png", "anchor": {"l": 0.15, "t": 0.56, "r": 0.85, "b": 0.82}, "cost": 20},
			"collar_blue": {"icon": "res://Sprites/pompom_collars/blue.png", "anchor": {"l": 0.15, "t": 0.56, "r": 0.85, "b": 0.82}, "cost": 20},
			"collar_green": {"icon": "res://Sprites/pompom_collars/green.png", "anchor": {"l": 0.15, "t": 0.56, "r": 0.85, "b": 0.82}, "cost": 20},
		},
		"exclusive_groups": [["collar_pink", "collar_lavender", "collar_blue", "collar_green"]],
		"rooms": {
			"bedroom": "res://Sprites/backgrounds/pompom_bedroom.jpg",
		},
		"friends": ["coco", "biscuit"],
	},
}

var active_pet := "petal"

var pet_records := {}

# Pets that can be picked: every PETS entry whose cutout art is in the project.
func available_pet_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in PETS:
		if ResourceLoader.exists(String(PETS[id]["cutout"])):
			ids.append(id)
	return ids

func _init_pet_records() -> void:
	for id in PETS:
		var acc := {}
		var unlocked := {}
		for acc_id in PETS[id]["accessories"]:
			acc[acc_id] = false
			unlocked[acc_id] = int(PETS[id]["accessories"][acc_id].get("cost", 0)) <= 0
		var perch := {}
		for item_id in PETS[id].get("perch_items", []):
			perch[item_id] = true
		pet_records[id] = {
			"hunger": 80.0,
			"happiness": 80.0,
			"energy": 80.0,
			"cleanliness": 80.0,
			"accessories": acc,
			"unlocked_accessories": unlocked,
			"perch_decor": perch,
		}

# Names kids type in (with emoji from the NameEditor picker) live in the
# active save slot along with the rest of their progress - see "Save slots".
signal names_changed

var player_name := ""
var snubbing_player := false   # not saved: the pet stops talking until the game is closed
var nicknames := {}

var pet_name: String:
	get: return pet_display_name(active_pet)

func pet_display_name(id: String) -> String:
	var nick := String(nicknames.get(id, ""))
	return nick if nick != "" else String(PETS[id]["name"])

func set_player_name(value: String) -> void:
	player_name = value.strip_edges()
	save_game()
	names_changed.emit()

# An empty nickname puts the pet's default name back.
func set_nickname(id: String, value: String) -> void:
	value = value.strip_edges()
	if value == "":
		nicknames.erase(id)
	else:
		nicknames[id] = value
	save_game()
	names_changed.emit()

# --- Save slots -------------------------------------------------------------
# Each kid gets their own file (user://save_1.cfg ...). It keeps the player
# name, nicknames, active pet, every pet's stats / accessories / unlocks,
# coins and earned stickers. Photo Book photos are textures held in memory
# and are not saved yet.
const SLOT_COUNT := 3
const AUTOSAVE_SECONDS := 20.0
var current_slot := 0 # 0 = no slot chosen yet, so nothing is written

func slot_path(slot: int) -> String:
	return "user://save_%d.cfg" % slot

func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))

# What the slot picker shows on each card; empty slots give {"exists": false}.
func slot_summary(slot: int) -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(slot_path(slot)) != OK:
		return {"exists": false}
	var pet_id := String(cfg.get_value("game", "active_pet", "petal"))
	if not PETS.has(pet_id):
		pet_id = "petal"
	var nicks = cfg.get_value("names", "pets", {})
	var nick := String(nicks.get(pet_id, "")) if nicks is Dictionary else ""
	return {
		"exists": true,
		"player": String(cfg.get_value("names", "player", "")),
		"pet": nick if nick != "" else String(PETS[pet_id]["name"]),
		"coins": int(cfg.get_value("game", "coins", 0)),
	}

# Makes `slot` the active save, loading it if it exists or starting fresh.
func start_slot(slot: int) -> void:
	_reset_progress()
	current_slot = slot
	if slot_exists(slot):
		_load_slot(slot)
	else:
		save_game()
	names_changed.emit()

func delete_slot(slot: int) -> void:
	if slot_exists(slot):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(slot)))
	if current_slot == slot:
		current_slot = 0

func _reset_progress() -> void:
	active_pet = "petal"
	player_name = ""
	nicknames = {}
	coins = 0
	earned_stickers = {}
	solved_cases = []
	pet_sets = {}
	play_owned = []
	play_spaces = {}
	play_rooms = {}
	schedule = {}
	chat_log = []
	safety_alerts = []
	remembered_likes = []
	treats_found = {}
	house_wants = {}
	house_design = {}
	house_known = {}
	visiting_friend = ""
	photos.clear()
	_init_pet_records()

# ── Pet voice ────────────────────────────────────────────────────────────────
# Replies are written in cat. For any other pet this swaps the noises and the cat
# faces: a dog woofs and gets 😍 instead of 😻, a bird tweets, and so on.
const VOICES := {
	"dog": {"sound": "woof", "face": "🐶", "purr": "*tail wag*", "hiss": "Grrrr", "kitty": "puppy", "noun": "dog"},
	"bird": {"sound": "tweet", "face": "🐦", "purr": "*chirp chirp*", "hiss": "Squawk", "kitty": "birdie", "noun": "bird"},
	"gerbil": {"sound": "squeak", "face": "🐹", "purr": "*squeak*", "hiss": "Squeak", "kitty": "gerbil", "noun": "gerbil"},
	"bunny": {"sound": "nibble", "face": "🐰", "purr": "*nuzzle*", "hiss": "*thump*", "kitty": "bunny", "noun": "bunny"},
}
const CAT_EMOJI_SWAP := {"😸": "😄", "😹": "😂", "😺": "😃", "😻": "😍", "😼": "😏", "😽": "😘", "😾": "😠", "😿": "😢", "🙀": "😱"}

func pet_species() -> String:
	return String(PETS.get(active_pet, {}).get("species", "cat"))

func in_voice(text: String) -> String:
	var species := pet_species()
	if species == "cat" or not VOICES.has(species):
		return text
	var v: Dictionary = VOICES[species]
	var out := text
	for rule in [
		["(?i)\\bmeow+\\b", v["sound"]],
		["(?i)\\bpurr+\\b", v["purr"]],
		["(?i)\\bhi+s{2,}\\b", v["hiss"]],
		["(?i)\\bkitty\\b", v["kitty"]],
	]:
		var rx := RegEx.new()
		rx.compile(rule[0])
		var pieces := ""
		var last := 0
		for m in rx.search_all(out):
			pieces += out.substr(last, m.get_start() - last)
			var word := String(rule[1])
			var first := m.get_string()[0]
			pieces += word.capitalize() if first == first.to_upper() and not word.begins_with("*") else word
			last = m.get_end()
		out = pieces + out.substr(last)
	out = out.replace("I'm a cat", "I'm a " + String(v["noun"])).replace("Cats don't mind", "Pets don't mind").replace("A big cat, like me!", "A big cat!")
	out = out.replace("🐈\u200d⬛", v["face"]).replace("🐈", v["face"]).replace("🐱", v["face"])
	for cat_face in CAT_EMOJI_SWAP:
		out = out.replace(cat_face, CAT_EMOJI_SWAP[cat_face])
	return out

# A worrying message was typed in the pet chat. Only the time is kept.
func remember_like(word: String) -> void:
	if word == "" or remembered_likes.has(word):
		return
	remembered_likes.append(word)
	if remembered_likes.size() > 12:
		remembered_likes.pop_front()
	save_game()

func add_safety_alert() -> void:
	safety_alerts.append(Time.get_unix_time_from_system())
	if safety_alerts.size() > 20:
		safety_alerts.pop_front()
	save_game()

func clear_safety_alerts() -> void:
	safety_alerts = []
	save_game()

func save_game() -> void:
	if current_slot == 0:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("names", "player", player_name)
	cfg.set_value("names", "pets", nicknames)
	cfg.set_value("game", "active_pet", active_pet)
	cfg.set_value("game", "coins", coins)
	cfg.set_value("game", "stickers", earned_stickers)
	cfg.set_value("game", "schedule", schedule)
	cfg.set_value("game", "solved_cases", solved_cases)
	cfg.set_value("game", "pet_sets", pet_sets)
	cfg.set_value("game", "play_owned", play_owned)
	cfg.set_value("game", "play_spaces", play_spaces)
	cfg.set_value("game", "play_rooms", play_rooms)
	cfg.set_value("game", "house", _save_house())
	cfg.set_value("game", "treats_found", treats_found)
	cfg.set_value("game", "pet_records", pet_records)
	cfg.set_value("safety", "alerts", safety_alerts)
	cfg.set_value("memory", "likes", remembered_likes)
	cfg.save(slot_path(current_slot))
	VisitorExport.export_if_allowed(current_slot, chat_log, schedule)

func _load_slot(slot: int) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(slot_path(slot)) != OK:
		return
	player_name = String(cfg.get_value("names", "player", ""))
	var saved_likes = cfg.get_value("memory", "likes", [])
	remembered_likes = (saved_likes as Array).duplicate() if saved_likes is Array else []
	var saved_alerts = cfg.get_value("safety", "alerts", [])
	safety_alerts = (saved_alerts as Array).duplicate() if saved_alerts is Array else []
	var saved_nicks = cfg.get_value("names", "pets", {})
	if saved_nicks is Dictionary:
		for id in saved_nicks:
			if PETS.has(id):
				nicknames[id] = String(saved_nicks[id])
	coins = int(cfg.get_value("game", "coins", 0))
	var saved_stickers = cfg.get_value("game", "stickers", {})
	if saved_stickers is Dictionary:
		for id in saved_stickers:
			if STICKERS.has(id):
				earned_stickers[id] = bool(saved_stickers[id])
	var saved_cases = cfg.get_value("game", "solved_cases", [])
	if saved_cases is Array:
		for id in saved_cases:
			if not solved_cases.has(String(id)):
				solved_cases.append(String(id))
	var saved_sets = cfg.get_value("game", "pet_sets", {})
	if saved_sets is Dictionary:
		for id in saved_sets:
			if PETS.has(id) and saved_sets[id] is Dictionary:
				pet_sets[id] = pet_set_from_save(String(id), saved_sets[id])
	var saved_owned = cfg.get_value("game", "play_owned", [])
	if saved_owned is Array:
		for id in saved_owned:
			if not play_def(String(id)).is_empty() and not play_owned.has(String(id)):
				play_owned.append(String(id))
	var saved_spaces = cfg.get_value("game", "play_spaces", {})
	if saved_spaces is Dictionary:
		for id in saved_spaces:
			if PETS.has(id) and saved_spaces[id] is Dictionary:
				play_spaces[id] = play_space_from_save(saved_spaces[id])
	var saved_rooms = cfg.get_value("game", "play_rooms", {})
	if saved_rooms is Dictionary:
		for id in saved_rooms:
			if PETS.has(id) and saved_rooms[id] is Dictionary:
				play_rooms[id] = play_room_from_save(saved_rooms[id])
	_load_house(cfg.get_value("game", "house", {}))
	var saved_treats = cfg.get_value("game", "treats_found", {})
	if saved_treats is Dictionary:
		for id in saved_treats:
			if PETS.has(id) and saved_treats[id] == true:
				treats_found[id] = true
	var saved_schedule = cfg.get_value("game", "schedule", {})
	if saved_schedule is Dictionary:
		for date in saved_schedule:
			var entries: Array = []
			if saved_schedule[date] is Array:
				for entry in saved_schedule[date]:
					if entry is Dictionary and entry.has("name"):
						entries.append({"name": String(entry["name"]), "start": int(entry.get("start", -1)), "end": int(entry.get("end", -1)), "place": String(entry.get("place", "")), "emoji": String(entry.get("emoji", ""))})
			if not entries.is_empty():
				schedule[String(date)] = entries
	# Merge key by key onto the defaults so pets or accessories added after
	# the save was made still start with sensible values.
	var saved_records = cfg.get_value("game", "pet_records", {})
	if saved_records is Dictionary:
		for id in saved_records:
			if not pet_records.has(id) or not (saved_records[id] is Dictionary):
				continue
			for key in saved_records[id]:
				var value = saved_records[id][key]
				if value is Dictionary and pet_records[id].get(key) is Dictionary:
					for sub in value:
						if pet_records[id][key].has(sub):
							pet_records[id][key][sub] = value[sub]
				elif pet_records[id].has(key):
					pet_records[id][key] = value
	var pet_id := String(cfg.get_value("game", "active_pet", "petal"))
	if PETS.has(pet_id) and available_pet_ids().has(pet_id):
		active_pet = pet_id

func switch_pet(id: String) -> void:
	if not PETS.has(id) or id == active_pet:
		return
	active_pet = id
	pet_changed.emit()
	stats_changed.emit()
	accessories_changed.emit()

func has_anim(kind: String) -> bool:
	return PETS[active_pet].has(kind)

func anim_frames(kind: String) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	if not has_anim(kind):
		return frames
	var info: Dictionary = PETS[active_pet][kind]
	for i in range(int(info["count"])):
		frames.append(load(String(info["path"]) % i))
	return frames

const PET_TINT_SHADER := preload("res://shaders/pet_tint.gdshader")

# Gives a pet's TextureRect the active pet's coat colour (or clears it for
# pets that use their art as drawn).
func apply_tint(node: CanvasItem, id: String = "") -> void:
	var info: Dictionary = PETS[active_pet if id == "" else id].get("tint", {})
	if info.is_empty():
		node.material = null
		return
	var mat := ShaderMaterial.new()
	mat.shader = PET_TINT_SHADER
	for key in info:
		var uniform_name: String = {"shadow": "shadow_color", "highlight": "highlight_color"}.get(key, key)
		mat.set_shader_parameter(uniform_name, info[key])
	node.material = mat

func cutout_path() -> String:
	return String(PETS[active_pet]["cutout"])

func friend_has_anim(id: String, kind: String) -> bool:
	return FRIENDS.has(id) and FRIENDS[id].has(kind)

func friend_anim_frames(id: String, kind: String) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	if not friend_has_anim(id, kind):
		return frames
	var info: Dictionary = FRIENDS[id][kind]
	for i in range(int(info["count"])):
		frames.append(load(String(info["path"]) % i))
	return frames

# Petting reactions, by species - dogs shouldn't purr and meow like a cat.
const SPECIES_REACTIONS := {
	"cat": ["😻 purr~", "💕", "🐱 mew!"],
	"dog": ["🐕 yip!", "💕", "🐶 woof!"],
	"bird": ["🐦 tweet!", "💕", "🎶 chirp!"],
	"gerbil": ["🐹 squeak!", "💕", "🥜 nibble nibble"],
	"bunny": ["🐰 *nose wiggle*", "💕", "🥕 nom nom"],
}

func pet_reactions() -> Array:
	var species := String(PETS[active_pet].get("species", "cat"))
	return SPECIES_REACTIONS.get(species, SPECIES_REACTIONS["cat"])

func friend_reactions(id: String) -> Array:
	var species := String(FRIENDS[id].get("species", "cat"))
	return SPECIES_REACTIONS.get(species, SPECIES_REACTIONS["cat"])

# One emoji per species, so labels and popups always show the right animal.
const SPECIES_EMOJI := {
	"cat": "🐱",
	"dog": "🐶",
	"bird": "🐦",
	"gerbil": "🐹",
	"bunny": "🐰",
}

func species_emoji(species: String) -> String:
	return SPECIES_EMOJI.get(species, SPECIES_EMOJI["cat"])

# What each kind of pet actually eats - used for the Hunger label, the Feed
# button and the treat-catch game, so a cat never gets a bone.
const SPECIES_FOOD := {
	"cat": "🐟",
	"dog": "🦴",
	"bird": "🌻",
	"gerbil": "🥜",
	"bunny": "🥕",
}
const SPECIES_TREATS := {
	"cat": ["🐟", "🐠", "🍤", "🥛", "🐟"],
	"dog": ["🦴", "🍖", "🥩", "🍗", "🦴"],
	"bird": ["🌻", "🌾", "🍇", "🍎", "🫐"],
	"gerbil": ["🌻", "🥜", "🌰", "🥕", "🌽"],
	"bunny": ["🥕", "🥬", "🍎", "🍓", "🥦"],
}

# Words for each treat emoji, so typing "bone" works like sending 🦴.
const TREAT_WORDS := {
	"🐟": ["fish", "tuna"], "🐠": ["tropical"], "🍤": ["shrimp", "prawn"], "🥛": ["milk"],
	"🦴": ["bone"], "🍖": ["meat"], "🥩": ["steak"], "🍗": ["drumstick", "chicken leg"],
	"🌻": ["sunflower", "seed"], "🌾": ["wheat"], "🍇": ["grape"], "🍎": ["apple"], "🫐": ["blueberry", "blueberries"],
	"🥜": ["peanut"], "🌰": ["chestnut"], "🥕": ["carrot"], "🌽": ["corn"], "🥬": ["lettuce"],
	"🍓": ["strawberry", "strawberries"], "🥦": ["broccoli"],
}
var treats_found := {} # pet id -> true once their favourite has been shown

# Each kind of pet secretly loves its first treat most of all (cats: fish), the same
# food she names when asked her favourite.
func favorite_treat() -> String:
	return treat_emojis()[0]

# She is shown her favourite: very happy, and a reward the first time.
func favorite_treat_shown() -> void:
	happiness = minf(MAX_STAT, happiness + 25.0)
	stats_changed.emit()
	if not treats_found.get(active_pet, false):
		treats_found[active_pet] = true
		add_coins(5)
		award_sticker("treat")

# Favourite toy per species, for the Play buttons.
const SPECIES_TOY := {
	"cat": "🧶",
	"dog": "🎾",
	"bird": "🔔",
	"gerbil": "🥎",
	"bunny": "🧸",
}

func toy_emoji() -> String:
	var species := String(PETS[active_pet].get("species", "cat"))
	return SPECIES_TOY.get(species, SPECIES_TOY["cat"])

func pet_emoji() -> String:
	return species_emoji(String(PETS[active_pet].get("species", "cat")))

func food_emoji() -> String:
	var species := String(PETS[active_pet].get("species", "cat"))
	return SPECIES_FOOD.get(species, SPECIES_FOOD["cat"])

func treat_emojis() -> Array:
	var species := String(PETS[active_pet].get("species", "cat"))
	return SPECIES_TREATS.get(species, SPECIES_TREATS["cat"])

func friend_emoji(id: String) -> String:
	return species_emoji(String(FRIENDS[id].get("species", "cat")))

func idle_reactions() -> Array:
	var species := String(PETS[active_pet].get("species", "cat"))
	var animal := species_emoji(species)
	return ["%s blink" % animal, "%s stretch~" % animal, "💤 yawn~", "😊 happy sigh"]

func static_pose(key: String) -> String:
	return String(PETS[active_pet].get(key, PETS[active_pet]["cutout"]))

# Returns the active pet's background for this room if she has one
# generated, otherwise the room's own default (usually Petal's art).
func room_bg(room_id: String, default_path: String) -> String:
	var rooms: Dictionary = PETS[active_pet].get("rooms", {})
	return String(rooms.get(room_id, default_path))

const TRICK_INFO := {
	"sit": {"label": "Sit", "emoji": "🐾"},
	"come": {"label": "Come", "emoji": "👋"},
	"wave": {"label": "Wave", "emoji": "🖐️"},
	"sing": {"label": "Sing", "emoji": "🎵"},
}

func has_tricks() -> bool:
	return not tricks().is_empty()

func tricks() -> Array:
	return PETS[active_pet].get("tricks", [])

func do_trick(trick_id: String) -> void:
	if not tricks().has(trick_id):
		return
	happiness = minf(MAX_STAT, happiness + 10.0)
	stats_changed.emit()
	award_sticker("tricks")
	add_coins(3)

const FRIENDS := {
	"marigold": {"name": "Princess Marigold", "species": "cat", "cutout": "res://Sprites/friend_cutout.png"},
	"blossom": {"name": "Princess Blossom", "species": "cat", "cutout": "res://Sprites/friend_blossom.png"},
	"iris": {"name": "Princess Iris", "species": "cat", "cutout": "res://Sprites/friend_iris.png"},
	"lily": {"name": "Princess Lily", "species": "cat", "cutout": "res://Sprites/friend_lily.png"},
	"biscuit": {"name": "Biscuit", "species": "dog", "cutout": "res://Sprites/friend_biscuit.png"},
	"coco": {"name": "Coco", "species": "dog", "cutout": "res://Sprites/friend_coco.png"},
	"raspberry": {"name": "Raspberry", "species": "bird", "cutout": "res://Sprites/friend_raspberry.png"},
	"pebble": {"name": "Pebble", "species": "gerbil", "cutout": "res://Sprites/friend_gerbil.png"},
	# The playable bunnies also drop by as each other's friends.
	"marshmallow_friend": {"name": "Marshmallow", "species": "bunny", "cutout": "res://Sprites/marshmallow_cutout.png"},
	"fluff_friend": {"name": "Fluff", "species": "bunny", "cutout": "res://Sprites/fluff_cutout.png"},
	"bunbun_friend": {"name": "Bunbun", "species": "bunny", "cutout": "res://Sprites/cotton_cutout.png"},
	"seafoam": {
		"name": "Seafoam",
		"species": "bird",
		"cutout": "res://Sprites/friend_seafoam.png",
		"fly": {"path": "res://Sprites/friend_seafoam_fly/frame_%02d.png", "count": 5},
		"sleep": {"path": "res://Sprites/friend_seafoam_sleep/frame_%02d.png", "count": 7},
	},
}
const DEFAULT_FRIEND_OPTIONS: Array[String] = ["marigold", "blossom", "iris", "lily"]
var visiting_friend := ""

# The active pet's own circle of friends (dogs only know other dogs, etc.) -
# falls back to the default princess friends for pets that don't set one.
func friend_options() -> Array[String]:
	var options: Array = PETS[active_pet].get("friends", DEFAULT_FRIEND_OPTIONS)
	var typed: Array[String] = []
	for id in options:
		typed.append(String(id))
	return typed

var hunger: float:
	get: return pet_records[active_pet]["hunger"]
	set(value): pet_records[active_pet]["hunger"] = value

var happiness: float:
	get: return pet_records[active_pet]["happiness"]
	set(value): pet_records[active_pet]["happiness"] = value

var energy: float:
	get: return pet_records[active_pet]["energy"]
	set(value): pet_records[active_pet]["energy"] = value

var cleanliness: float:
	get: return pet_records[active_pet]["cleanliness"]
	set(value): pet_records[active_pet]["cleanliness"] = value

# Dress-up accessories the active pet can wear, toggled from the Dress-Up
# Room. This returns the live per-pet dictionary (Dictionaries are
# reference types in GDScript), so existing code that mutates
# PetalState.accessories[id] directly keeps working unchanged.
var accessories: Dictionary:
	get: return pet_records[active_pet]["accessories"]

# Sticker Book: id -> {emoji, label}. Earned the first time you do the
# matching activity; "earned" tracks which ids have been unlocked.
const STICKERS := {
	"feed": {"emoji": "🍽️", "label": "Snack Time"},
	"play": {"emoji": "🧶", "label": "Playtime"},
	"pet": {"emoji": "🥰", "label": "Best Friends"},
	"cuddle": {"emoji": "💞", "label": "Cozy Cuddles"},
	"bathe": {"emoji": "🛁", "label": "Bath Time"},
	"brush": {"emoji": "✨", "label": "Brushed & Fluffy"},
	"nap": {"emoji": "😴", "label": "Sweet Dreams"},
	"stroll": {"emoji": "🌷", "label": "Garden Stroll"},
	"obstacle": {"emoji": "🏆", "label": "Champion"},
	"friend": {"emoji": "🐾", "label": "Good Friends"},
	"photo": {"emoji": "📸", "label": "Say Cheese"},
	"party": {"emoji": "🎉", "label": "Party Time"},
	"fish": {"emoji": "🐟", "label": "Fisher"},
	"tricks": {"emoji": "🎾", "label": "Good Trick!"},
	"catch": {"emoji": "🍬", "label": "Treat Catcher"},
	"bell": {"emoji": "🔔", "label": "Jingle Bells"},
	"swim": {"emoji": "🏊", "label": "Splash Time"},
	"spa": {"emoji": "💆", "label": "Spa Day"},
	"week": {"emoji": "📅", "label": "Whole Week"},
	"cathouse": {"emoji": "🏡", "label": "Dream House"},
	"treat": {"emoji": "💝", "label": "Favourite Treat"},
	"detective": {"emoji": "🕵️", "label": "Super Detective"},
	"designer": {"emoji": "🛏️", "label": "Pet Designer"},
	"playspace": {"emoji": "🎪", "label": "Play Space Pro"},
	"playroom": {"emoji": "🏠", "label": "Room Decorator"},
	"homesweet": {"emoji": "🏡", "label": "Home Sweet Home"},
}
var earned_stickers := {}

# Pet Set Studio (room_petset.gd): every pet's own designed bed and bowl.
# pet id -> {"bed": piece, "bowl": piece}; a piece is {color, trim (indexes
# into SET_COLORS), pattern, stamp, shape, name}. Pets never designed get a
# cheerful default from default_pet_set(), so nothing is ever empty.
const SET_COLORS := [
	Color("ff9ec4"), Color("f25c6e"), Color("ffa95c"), Color("ffd84d"),
	Color("b6e36b"), Color("5cc98a"), Color("4fc6c9"), Color("6cb8ff"),
	Color("5b7fe8"), Color("a87be8"), Color("b07a52"), Color("ffffff"),
]
const SET_PATTERNS := ["plain", "stripes", "dots", "hearts", "stars", "checks", "paws"]
const SET_STAMPS := ["", "🐾", "⭐", "💖", "🌸", "🦴", "🐟", "🦋", "🌈", "🍓", "👑", "🌙"]
const SET_SHAPES := {
	"bed": ["round", "square", "heart", "star"],
	"bowl": ["round", "tall", "wide"],
	"toy": ["ball", "bone", "fish", "heart"],
	"pillow": ["square", "round", "heart"],
	"house": ["cottage", "tower", "tent"],
}
const SET_KINDS := ["bed", "bowl", "toy", "pillow", "house"]
# The house each kind of pet starts with (they can all change it).
const SPECIES_HOUSE := {"cat": "cottage", "dog": "cottage", "bird": "tower", "gerbil": "tent", "bunny": "tent"}
const SET_NAME_MAX := 14
var pet_sets := {}

# Each pet secretly loves one colour (an index into SET_COLORS) - the studio
# cheers when a kid finds it.
func favourite_color(id: String) -> int:
	return absi(("fav" + id).hash()) % SET_COLORS.size()

func default_pet_set(id: String) -> Dictionary:
	var species := String(PETS[id].get("species", "cat"))
	var h := absi(id.hash())
	var main := h % SET_COLORS.size()
	var trim := (main + 4 + h % 3) % SET_COLORS.size()
	return {
		"bed": {"color": main, "trim": trim, "pattern": "hearts", "stamp": "🐾", "shape": "round", "name": ""},
		"bowl": {"color": main, "trim": trim, "pattern": "dots", "stamp": "", "shape": "round", "name": ""},
		"toy": {"color": trim, "trim": main, "pattern": "stripes", "stamp": "", "shape": "ball", "name": ""},
		"pillow": {"color": trim, "trim": main, "pattern": "plain", "stamp": "💖", "shape": "heart", "name": ""},
		"house": {"color": main, "trim": trim, "pattern": "plain", "stamp": species_emoji(species), "shape": String(SPECIES_HOUSE.get(species, "cottage")), "name": ""},
	}

# The saved design for a pet, with anything missing filled from the default.
func pet_set(id: String) -> Dictionary:
	var saved = pet_sets.get(id, {})
	return pet_set_from_save(id, saved if saved is Dictionary else {})

func pet_set_from_save(id: String, saved: Dictionary) -> Dictionary:
	var base := default_pet_set(id)
	var result := {}
	for kind in SET_KINDS:
		var raw = saved.get(kind)
		result[kind] = _clean_set_piece(kind, raw, base[kind]) if raw is Dictionary else base[kind]
	return result

func _clean_set_piece(kind: String, raw: Dictionary, fallback: Dictionary) -> Dictionary:
	var piece := fallback.duplicate()
	for key in ["color", "trim"]:
		if raw.get(key) is int:
			piece[key] = clampi(int(raw[key]), 0, SET_COLORS.size() - 1)
	if SET_PATTERNS.has(raw.get("pattern")):
		piece["pattern"] = raw["pattern"]
	if SET_STAMPS.has(raw.get("stamp")):
		piece["stamp"] = raw["stamp"]
	if SET_SHAPES[kind].has(raw.get("shape")):
		piece["shape"] = raw["shape"]
	if raw.get("name") is String:
		piece["name"] = String(raw["name"]).strip_edges().left(SET_NAME_MAX)
	return piece

func save_pet_set(id: String, design: Dictionary) -> void:
	pet_sets[id] = design.duplicate(true)
	save_game()

# Tapping "I love it!" in the studio: sticker + coins the first time only.
func finish_pet_set(id: String, design: Dictionary, sticker := "designer") -> void:
	save_pet_set(id, design)
	award_sticker(sticker)


# Play Space (room_petset.gd): toys and scenery bought with Treat Coins, then
# dragged around a stage. What you've bought is kept for the whole save slot
# (use it for any pet); each pet has its own layout. A cost of 0 is free.
const PLAY_ITEMS := {
	"yarn": {"emoji": "🧶", "label": "Yarn Ball", "cost": 0},
	"ball": {"emoji": "🎾", "label": "Ball", "cost": 0},
	"flower": {"emoji": "🌷", "label": "Flower", "cost": 3},
	"teddy": {"emoji": "🧸", "label": "Teddy", "cost": 5},
	"balloon": {"emoji": "🎈", "label": "Balloon", "cost": 5},
	"tree": {"emoji": "🌳", "label": "Tree", "cost": 8},
	"tent": {"emoji": "⛺", "label": "Tent", "cost": 10},
	"easel": {"emoji": "🎨", "label": "Painting", "cost": 10},
	"drum": {"emoji": "🥁", "label": "Drum", "cost": 12},
	"piano": {"emoji": "🎹", "label": "Piano", "cost": 15},
	"car": {"emoji": "🚗", "label": "Toy Car", "cost": 15},
	"fountain": {"emoji": "⛲", "label": "Fountain", "cost": 20},
	"rainbow": {"emoji": "🌈", "label": "Rainbow", "cost": 25},
	"horse": {"emoji": "🎠", "label": "Merry-go-round", "cost": 30},
	"circus": {"emoji": "🎪", "label": "Circus Tent", "cost": 40},
	"castle": {"emoji": "🏰", "label": "Castle", "cost": 60},
	"wheel": {"emoji": "🎡", "label": "Big Wheel", "cost": 80},
	"coaster": {"emoji": "🎢", "label": "Roller Coaster", "cost": 100},
}
const PLAY_THEMES := {
	"cosy": {"emoji": "🏠", "label": "Cosy Room", "cost": 0},
	"meadow": {"emoji": "🌼", "label": "Meadow", "cost": 10},
	"beach": {"emoji": "🏖️", "label": "Beach", "cost": 20},
	"night": {"emoji": "🌙", "label": "Starry Night", "cost": 25},
	"candy": {"emoji": "🍭", "label": "Candy Land", "cost": 35},
}
# The Play Room: an indoor room with bought wallpaper, flooring and furniture.
# Ids are unique across every play catalog so one "owned" list covers them all.
const ROOM_ITEMS := {
	"basket": {"emoji": "🧺", "label": "Basket", "cost": 0},
	"present": {"emoji": "🎁", "label": "Present", "cost": 3},
	"chair": {"emoji": "🪑", "label": "Chair", "cost": 5},
	"lamp": {"emoji": "💡", "label": "Lamp", "cost": 5},
	"books": {"emoji": "📚", "label": "Books", "cost": 5},
	"picture": {"emoji": "🖼️", "label": "Picture", "cost": 6},
	"candle": {"emoji": "🕯️", "label": "Candle", "cost": 6},
	"clock": {"emoji": "🕰️", "label": "Clock", "cost": 8},
	"sofa": {"emoji": "🛋️", "label": "Sofa", "cost": 12},
	"cake": {"emoji": "🎂", "label": "Cake", "cost": 12},
	"tv": {"emoji": "📺", "label": "TV", "cost": 15},
	"bath": {"emoji": "🛁", "label": "Bath", "cost": 15},
	"xmas": {"emoji": "🎄", "label": "Tree", "cost": 18},
	"games": {"emoji": "🎮", "label": "Games", "cost": 20},
	"trophy": {"emoji": "🏆", "label": "Trophy", "cost": 25},
	"crown": {"emoji": "👑", "label": "Crown", "cost": 30},
	"globe": {"emoji": "🌍", "label": "Globe", "cost": 40},
}
const ROOM_WALLS := {
	"pinkwall": {"emoji": "🌸", "label": "Pink", "cost": 0, "color": Color("ffd6e6"), "pattern": "plain"},
	"skywall": {"emoji": "☁️", "label": "Sky", "cost": 0, "color": Color("cfe8ff"), "pattern": "plain"},
	"mintwall": {"emoji": "🌿", "label": "Mint Stripes", "cost": 5, "color": Color("c9f0dc"), "pattern": "stripes"},
	"sunwall": {"emoji": "☀️", "label": "Sunny Dots", "cost": 8, "color": Color("fff0b3"), "pattern": "dots"},
	"lilacwall": {"emoji": "💜", "label": "Lilac Hearts", "cost": 10, "color": Color("e6d6ff"), "pattern": "hearts"},
	"starwall": {"emoji": "⭐", "label": "Starry", "cost": 15, "color": Color("2b2f6b"), "pattern": "stars"},
}
const ROOM_FLOORS := {
	"wood": {"emoji": "🪵", "label": "Wood", "cost": 0, "color": Color("e8c39a"), "pattern": "planks"},
	"carpet": {"emoji": "🧶", "label": "Carpet", "cost": 6, "color": Color("ff9ec4"), "pattern": "plain"},
	"checker": {"emoji": "🏁", "label": "Checkers", "cost": 10, "color": Color("ffffff"), "pattern": "checks"},
	"grass": {"emoji": "🌱", "label": "Grass Rug", "cost": 12, "color": Color("8fd46b"), "pattern": "plain"},
	"tile": {"emoji": "🟦", "label": "Blue Tiles", "cost": 15, "color": Color("8cc4f5"), "pattern": "tiles"},
}
# Toys each kind of pet loves most - the shops show the active pet's own.
const PET_ITEMS := {
	"fishtoy": {"emoji": "🐟", "label": "Fishy", "cost": 3},
	"mousetoy": {"emoji": "🐭", "label": "Mousey", "cost": 4},
	"scratch": {"emoji": "🌴", "label": "Scratch Post", "cost": 8},
	"milk": {"emoji": "🥛", "label": "Milk", "cost": 3},
	"bonetoy": {"emoji": "🦴", "label": "Bone", "cost": 3},
	"frisbee": {"emoji": "🥏", "label": "Frisbee", "cost": 5},
	"dogtreat": {"emoji": "🥩", "label": "Treat", "cost": 4},
	"bigball": {"emoji": "🏐", "label": "Big Ball", "cost": 6},
	"sunflower": {"emoji": "🌻", "label": "Sunflower", "cost": 3},
	"cherry": {"emoji": "🍒", "label": "Cherries", "cost": 4},
	"song": {"emoji": "🎶", "label": "Song", "cost": 4},
	"egg": {"emoji": "🥚", "label": "Egg", "cost": 5},
	"peanut": {"emoji": "🥜", "label": "Peanut", "cost": 3},
	"cheese": {"emoji": "🧀", "label": "Cheese", "cost": 4},
	"hole": {"emoji": "🕳️", "label": "Tunnel", "cost": 6},
	"chestnut": {"emoji": "🌰", "label": "Chestnut", "cost": 3},
	"carrot": {"emoji": "🥕", "label": "Carrot", "cost": 3},
	"lettuce": {"emoji": "🥬", "label": "Lettuce", "cost": 3},
	"mushroom": {"emoji": "🍄", "label": "Mushroom", "cost": 4},
	"daisy": {"emoji": "🌼", "label": "Daisy", "cost": 3},
}
const SPECIES_ITEMS := {
	"cat": ["fishtoy", "mousetoy", "scratch", "milk"],
	"dog": ["bonetoy", "frisbee", "dogtreat", "bigball"],
	"bird": ["sunflower", "cherry", "song", "egg"],
	"gerbil": ["peanut", "cheese", "hole", "chestnut"],
	"bunny": ["carrot", "lettuce", "mushroom", "daisy"],
}

func pet_favourites(id: String) -> Array:
	return SPECIES_ITEMS.get(String(PETS[id].get("species", "cat")), [])

const PLAY_MAX_ITEMS := 14
var play_owned: Array = []        # ids of bought items and themes
var play_spaces := {}             # pet id -> {"theme": id, "items": [{"id", "x", "y"}]}
var play_rooms := {}              # pet id -> {"wall": id, "floor": id, "items": [...]}

# The catalog entry for any play item, theme, wall or floor ({} if unknown).
func play_def(id: String) -> Dictionary:
	for catalog in [PLAY_ITEMS, PET_ITEMS, PLAY_THEMES, ROOM_ITEMS, ROOM_WALLS, ROOM_FLOORS]:
		if catalog.has(id):
			return catalog[id]
	return {}

func play_cost(id: String) -> int:
	return int(play_def(id).get("cost", 0))

func play_unlocked(id: String) -> bool:
	return play_cost(id) == 0 or play_owned.has(id)

# Spends Treat Coins the first time; false if you can't afford it yet.
func try_buy_play(id: String) -> bool:
	if play_unlocked(id):
		return true
	var cost := play_cost(id)
	if coins < cost:
		return false
	coins -= cost
	play_owned.append(id)
	coins_changed.emit()
	save_game()
	return true

func play_space(id: String) -> Dictionary:
	var saved = play_spaces.get(id, {})
	return play_space_from_save(saved if saved is Dictionary else {})

func play_space_from_save(saved: Dictionary) -> Dictionary:
	var theme := String(saved.get("theme", "cosy"))
	if not PLAY_THEMES.has(theme):
		theme = "cosy"
	return {"theme": theme, "items": _clean_play_items(saved.get("items", []), PLAY_ITEMS.merged(PET_ITEMS))}

func play_room(id: String) -> Dictionary:
	var saved = play_rooms.get(id, {})
	return play_room_from_save(saved if saved is Dictionary else {})

func play_room_from_save(saved: Dictionary) -> Dictionary:
	var wall := String(saved.get("wall", "pinkwall"))
	var floor_id := String(saved.get("floor", "wood"))
	return {
		"wall": wall if ROOM_WALLS.has(wall) else "pinkwall",
		"floor": floor_id if ROOM_FLOORS.has(floor_id) else "wood",
		"items": _clean_play_items(saved.get("items", []), ROOM_ITEMS.merged(PET_ITEMS)),
	}

func save_play_room(id: String, room: Dictionary) -> void:
	play_rooms[id] = room.duplicate(true)
	save_game()

func finish_play_room(id: String, room: Dictionary) -> void:
	save_play_room(id, room)
	if room["items"].size() >= 3:
		award_sticker("playroom")

func _clean_play_items(raw, catalog: Dictionary) -> Array:
	var items: Array = []
	if raw is Array:
		for entry in raw:
			if items.size() >= PLAY_MAX_ITEMS:
				break
			if entry is Dictionary and catalog.has(entry.get("id")) and (entry.get("x") is float or entry.get("x") is int) and (entry.get("y") is float or entry.get("y") is int):
				items.append({"id": String(entry["id"]), "x": float(entry["x"]), "y": float(entry["y"])})
	return items

func save_play_space(id: String, space: Dictionary) -> void:
	play_spaces[id] = space.duplicate(true)
	save_game()

func finish_play_space(id: String, space: Dictionary) -> void:
	save_play_space(id, space)
	if space["items"].size() >= 3:
		award_sticker("playspace")

# Mystery room (room_mystery.gd): ids of the cases solved so far.
var solved_cases: Array = []

# The princess calendar (room_schedule.gd): "YYYY-MM-DD" -> events in time
# order, each {"name", "start" and "end" in minutes (-1 = all day), "place"}.
var schedule := {}
# Texts with the pet, newest last: {"from": "pet" or "you", "text": String}.
var chat_log: Array = []
var remembered_likes: Array = []   # harmless things she was told you like (kittens, pink...); saved per slot
var safety_alerts: Array = []   # unix times of worrying messages (never the words); saved per slot

# Photo Book: snapshots taken in the Photo Booth, newest last. Capped so
# the game doesn't hoard an unbounded number of full-screen textures. Each
# entry is {"texture": Texture2D, "caption": String, "stickers": Array[String]}
# - a light scrapbook feel without any per-pixel placement UI.
const MAX_PHOTOS := 12
var photos: Array[Dictionary] = []

const PHOTO_CAPTIONS := [
	"Say cheese! 🧀",
	"Best friends forever 💕",
	"Camera-ready! ✨",
	"What a cutie! 😍",
	"Snapshot of a happy day 🌟",
	"Picture-perfect moment 📷",
	"Smile for the camera! 😄",
	"A memory worth keeping 💖",
]

func award_sticker(id: String) -> void:
	if not STICKERS.has(id) or earned_stickers.get(id, false):
		return
	earned_stickers[id] = true
	sticker_earned.emit(id)
	add_coins(10)

# Treat Coins: a simple, gentle reward currency. Every bit of care earns a
# few, with a bigger crate every MILESTONE_STEP coins - just a fun "ding!"
# moment, never anything a 5-year-old could fail to reach.
const MILESTONE_STEP := 50
var coins := 0

func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	var before := coins
	coins += amount
	coins_changed.emit()
	if coins / MILESTONE_STEP > before / MILESTONE_STEP:
		milestone_reached.emit(coins)

# Saves whenever something worth keeping changes, plus on a timer for the
# slowly-drifting stats, and when the window closes.
func _start_autosave() -> void:
	for sig in [coins_changed, accessories_changed, perch_decor_changed, pet_changed]:
		sig.connect(save_game)
	sticker_earned.connect(save_game.unbind(1))
	var timer := Timer.new()
	timer.wait_time = AUTOSAVE_SECONDS
	timer.timeout.connect(save_game)
	add_child(timer)
	timer.start()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()

func _ready() -> void:
	_init_pet_records()
	_start_autosave()

	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_on_tick)
	add_child(timer)

	# Web export has no OS font fallback for emoji glyphs used throughout the
	# UI, so append a dedicated emoji font to the default font's fallback
	# chain rather than replacing it (replacing it broke normal text).
	var emoji_font: Font = load("res://fonts/TwemojiMozilla.ttf")
	ThemeDB.fallback_font.fallbacks = [emoji_font]

func _on_tick() -> void:
	hunger = maxf(0.0, hunger - DECAY_PER_SEC)
	happiness = maxf(0.0, happiness - DECAY_PER_SEC * 0.7)
	energy = maxf(0.0, energy - DECAY_PER_SEC * 0.5)
	cleanliness = maxf(0.0, cleanliness - DECAY_PER_SEC * 0.3)
	stats_changed.emit()

func feed() -> void:
	hunger = minf(MAX_STAT, hunger + 25.0)
	happiness = minf(MAX_STAT, happiness + 5.0)
	stats_changed.emit()
	award_sticker("feed")
	add_coins(3)

func play() -> void:
	happiness = minf(MAX_STAT, happiness + 20.0)
	energy = maxf(0.0, energy - 10.0)
	cleanliness = maxf(0.0, cleanliness - 5.0)
	stats_changed.emit()
	award_sticker("play")
	add_coins(4)

func pet_her() -> void:
	happiness = minf(MAX_STAT, happiness + 12.0)
	stats_changed.emit()
	award_sticker("pet")
	add_coins(1)

func pet_friend() -> void:
	happiness = minf(MAX_STAT, happiness + 8.0)
	stats_changed.emit()
	add_coins(1)

func cuddle() -> void:
	happiness = minf(MAX_STAT, happiness + 18.0)
	energy = minf(MAX_STAT, energy + 5.0)
	stats_changed.emit()
	award_sticker("cuddle")
	add_coins(3)

func bathe() -> void:
	cleanliness = minf(MAX_STAT, cleanliness + 30.0)
	happiness = minf(MAX_STAT, happiness + 5.0)
	stats_changed.emit()
	award_sticker("bathe")
	add_coins(5)

func brush() -> void:
	cleanliness = minf(MAX_STAT, cleanliness + 15.0)
	happiness = minf(MAX_STAT, happiness + 10.0)
	stats_changed.emit()
	award_sticker("brush")
	add_coins(4)

func nap() -> void:
	energy = minf(MAX_STAT, energy + 35.0)
	stats_changed.emit()
	award_sticker("nap")
	add_coins(3)

func stroll() -> void:
	happiness = minf(MAX_STAT, happiness + 20.0)
	energy = maxf(0.0, energy - 10.0)
	stats_changed.emit()
	award_sticker("stroll")
	add_coins(4)

func obstacle_course() -> void:
	happiness = minf(MAX_STAT, happiness + 25.0)
	energy = maxf(0.0, energy - 15.0)
	cleanliness = maxf(0.0, cleanliness - 8.0)
	stats_changed.emit()
	award_sticker("obstacle")
	add_coins(5)

func take_photo(snapshot: Texture2D) -> void:
	var stickers: Array[String] = []
	photos.append({
		"texture": snapshot,
		"caption": PHOTO_CAPTIONS.pick_random(),
		"stickers": stickers,
	})
	if photos.size() > MAX_PHOTOS:
		photos.pop_front()
	photo_taken.emit()
	happiness = minf(MAX_STAT, happiness + 10.0)
	stats_changed.emit()
	award_sticker("photo")
	add_coins(3)

# Decorates a Photo Book page with one of the player's already-earned
# stickers (toggling it back off if it's already on that page).
func toggle_photo_sticker(index: int, sticker_id: String) -> void:
	if index < 0 or index >= photos.size() or not earned_stickers.get(sticker_id, false):
		return
	var stickers: Array = photos[index]["stickers"]
	if stickers.has(sticker_id):
		stickers.erase(sticker_id)
	else:
		stickers.append(sticker_id)
	photo_taken.emit()

func celebrate_party() -> void:
	happiness = MAX_STAT
	stats_changed.emit()
	award_sticker("party")
	add_coins(6)

func catch_fish() -> void:
	happiness = minf(MAX_STAT, happiness + 10.0)
	stats_changed.emit()
	award_sticker("fish")
	add_coins(5)

func catch_treat() -> void:
	happiness = minf(MAX_STAT, happiness + 3.0)
	stats_changed.emit()
	award_sticker("catch")
	add_coins(2)

# A treat that falls on the pet instead of being tapped: a small snack.
func pet_eats_fallen_treat() -> void:
	hunger = minf(MAX_STAT, hunger + 8.0)
	happiness = minf(MAX_STAT, happiness + 2.0)
	stats_changed.emit()

func has_bell_toy() -> bool:
	return PETS[active_pet].has("toy_bell")

func go_swimming() -> void:
	happiness = minf(MAX_STAT, happiness + 20.0)
	cleanliness = maxf(0.0, cleanliness - 10.0)
	stats_changed.emit()
	award_sticker("swim")
	add_coins(5)

# One treatment at the Spa. Every treatment helps a little; finishing all of
# them in a visit (see room_spa.gd) calls spa_day_complete for the big prize.
func spa_treatment() -> void:
	happiness = minf(MAX_STAT, happiness + 8.0)
	energy = minf(MAX_STAT, energy + 8.0)
	cleanliness = minf(MAX_STAT, cleanliness + 5.0)
	stats_changed.emit()
	add_coins(1)

func spa_day_complete() -> void:
	happiness = minf(MAX_STAT, happiness + 20.0)
	stats_changed.emit()
	award_sticker("spa")
	add_coins(6)

# The Cat House (room_cathouse.gd). Every pet secretly wants one choice in each
# category; the survey uncovers them and the design is judged against them.
const HOUSE_CHOICES := {
	"color": ["pink", "blue", "purple", "yellow", "green"],
	"pattern": ["hearts", "stars", "flowers", "stripes"],
	"height": ["tall", "short"],
	"post": ["rope", "carpet", "tree"],
}
var house_wants := {}  # pet id -> {category: choice}
var house_design := {} # pet id -> {category: choice}
var house_known := {}  # pet id -> {category: true} once the survey found it

func house_wants_for_pet() -> Dictionary:
	# Existing wishes never change; only categories added later get a first pick.
	if not house_wants.has(active_pet):
		house_wants[active_pet] = {}
	for category in HOUSE_CHOICES:
		if not house_wants[active_pet].has(category):
			house_wants[active_pet][category] = HOUSE_CHOICES[category].pick_random()
	return house_wants[active_pet]

func house_design_for_pet() -> Dictionary:
	if not house_design.has(active_pet):
		house_design[active_pet] = {}
	for category in HOUSE_CHOICES:
		if not house_design[active_pet].has(category):
			house_design[active_pet][category] = HOUSE_CHOICES[category][0]
	return house_design[active_pet]

func house_known_for_pet() -> Dictionary:
	if not house_known.has(active_pet):
		house_known[active_pet] = {}
	return house_known[active_pet]

# Each match pleases her; getting all four earns the Dream House sticker.
func house_judged(matches: int) -> void:
	happiness = minf(MAX_STAT, happiness + 5.0 * matches)
	stats_changed.emit()
	add_coins(matches)
	if matches == HOUSE_CHOICES.size():
		award_sticker("cathouse")
		add_coins(6)

func _save_house() -> Dictionary:
	return {"wants": house_wants, "design": house_design, "known": house_known}

func _load_house(saved) -> void:
	if not (saved is Dictionary):
		return
	for key in ["wants", "design", "known"]:
		var by_pet = saved.get(key, {})
		if not (by_pet is Dictionary):
			continue
		var target: Dictionary = {"wants": house_wants, "design": house_design, "known": house_known}[key]
		for id in by_pet:
			if not PETS.has(id) or not (by_pet[id] is Dictionary):
				continue
			var entry := {}
			for category in HOUSE_CHOICES:
				var value = by_pet[id].get(category)
				if key == "known":
					if value == true:
						entry[category] = true
				elif HOUSE_CHOICES[category].has(value):
					entry[category] = value
			target[id] = entry

# Solving a mystery case (see room_mystery.gd); coins only the first time.
func solve_case(id: String, prize: int = 5) -> void:
	var first := not solved_cases.has(id)
	if first:
		solved_cases.append(id)
	happiness = minf(MAX_STAT, happiness + 10.0)
	stats_changed.emit()
	award_sticker("detective")
	if first:
		add_coins(prize)
	save_game()

# Finishing a whole week of the planner (see room_schedule.gd).
func week_complete() -> void:
	happiness = minf(MAX_STAT, happiness + 15.0)
	stats_changed.emit()
	award_sticker("week")
	add_coins(5)

func ring_bell_locally() -> void:
	happiness = minf(MAX_STAT, happiness + 15.0)
	stats_changed.emit()
	award_sticker("bell")
	add_coins(3)

func ring_bell() -> void:
	ring_bell_locally()
	bell_animation_requested.emit()

func invite_friend(id: String) -> void:
	visiting_friend = id
	happiness = minf(MAX_STAT, happiness + 20.0)
	award_sticker("friend")
	add_coins(4)
	stats_changed.emit()
	friend_changed.emit()

func say_bye_to_friend() -> void:
	visiting_friend = ""
	friend_changed.emit()

func accessory_cost(id: String) -> int:
	return int(PETS[active_pet]["accessories"].get(id, {}).get("cost", 0))

func is_accessory_unlocked(id: String) -> bool:
	return pet_records[active_pet]["unlocked_accessories"].get(id, true)

# Spends Treat Coins to permanently unlock an accessory for the active pet.
# Returns true if it's unlocked afterward (already-unlocked counts as
# success); false if she can't yet afford it.
func try_unlock_accessory(id: String) -> bool:
	if is_accessory_unlocked(id):
		return true
	var cost := accessory_cost(id)
	if coins < cost:
		return false
	coins -= cost
	coins_changed.emit()
	pet_records[active_pet]["unlocked_accessories"][id] = true
	return true

func toggle_accessory(id: String) -> void:
	if not accessories.has(id) or not is_accessory_unlocked(id):
		return
	var turning_on: bool = not accessories[id]
	if turning_on:
		for group in PETS[active_pet]["exclusive_groups"]:
			if group.has(id):
				for sibling in group:
					accessories[sibling] = false
	accessories[id] = turning_on
	happiness = minf(MAX_STAT, happiness + 3.0)
	accessories_changed.emit()
	stats_changed.emit()

func perch_items() -> Array:
	return PETS[active_pet].get("perch_items", [])

func perch_decor() -> Dictionary:
	return pet_records[active_pet].get("perch_decor", {})

func toggle_perch_item(id: String) -> void:
	var decor: Dictionary = perch_decor()
	if not decor.has(id):
		return
	decor[id] = not decor[id]
	perch_decor_changed.emit()

# Each bed/toy/feeder combo was hand-painted as its own flat image rather
# than transparent overlays, so this looks up the sorted, comma-joined list
# of currently-on item ids - dropping items (toy first, since that's the
# only combo never painted) until a painted combo is found.
func perch_background_path() -> String:
	var combos: Dictionary = PETS[active_pet].get("perch_combos", {})
	if combos.is_empty():
		return String(PETS[active_pet].get("rooms", {}).get("bedroom", ""))
	var decor: Dictionary = perch_decor()
	var on: Array = []
	for id in perch_items():
		if decor.get(id, false):
			on.append(id)
	for drop_priority in [[], ["toy"], ["toy", "feeder"], ["toy", "feeder", "bed"]]:
		var key := on.filter(func(id): return not drop_priority.has(id))
		key.sort()
		var key_str := ",".join(key)
		if combos.has(key_str):
			return String(combos[key_str])
	return String(combos.values()[0])

const MAKEUP_IDS := ["blush", "mascara", "lipstick"]

func remove_all_makeup() -> void:
	for id in MAKEUP_IDS:
		if accessories.has(id):
			accessories[id] = false
	accessories_changed.emit()

const MOOD_TIERS := {
	"great": {"emoji": "🤩", "color": Color(0.29, 0.62, 0.29, 1)},
	"okay": {"emoji": "🙂", "color": Color(0.42, 0.42, 0.42, 1)},
	"meh": {"emoji": "😕", "color": Color(0.78, 0.55, 0.1, 1)},
	"low": {"emoji": "🥺", "color": Color(0.8, 0.28, 0.28, 1)},
}

func mood_tier() -> String:
	var avg := (hunger + happiness + energy + cleanliness) / 4.0
	if avg >= 80.0:
		return "great"
	elif avg >= 55.0:
		return "okay"
	elif avg >= 30.0:
		return "meh"
	else:
		return "low"

func mood_emoji() -> String:
	return String(MOOD_TIERS[mood_tier()]["emoji"])

func mood_color() -> Color:
	return MOOD_TIERS[mood_tier()]["color"]

func mood() -> String:
	match mood_tier():
		"great":
			return "%s feels radiant!" % pet_name
		"okay":
			return "%s is doing okay." % pet_name
		"meh":
			return "%s could use some care." % pet_name
		_:
			return "%s really needs you!" % pet_name

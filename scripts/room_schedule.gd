extends Control

# The princess calendar. Pick a date and type an event like
# "school 8:00-3:00 at Watkins" (name, times, place), then watch your pet copy
# the week. School is a classroom where she wears glasses and reads books. You
# and your pet can also text each other, and she texts you what she is up to.

const PetSafety = preload("res://scripts/pet_safety.gd")
const Feedback = preload("res://scripts/room_feedback.gd")
const PetCameo = preload("res://scripts/pet_cameo.gd")
const Confetti = preload("res://scripts/confetti.gd")

const DAYS := ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
const MONTHS := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
# Pictures to pick for an "Other" activity.
const OTHER_EMOJIS := ["🎨", "🦷", "🛒", "🎂", "🎬", "🩺", "✂️", "⛪", "🚌", "🧁", "🎳", "🌳",
	"⚽", "🏀", "🏈", "⚾", "🎾", "🏐", "🏓", "🏸", "🏒", "🥋", "🤸", "🛹", "⛸️", "🚴", "⛳", "🏹",
	"🎸", "🚂", "🦄", "🌈", "🍕", "🎁", "🧩", "🏖️", "🎪", "🐶"]
const STEP_SECONDS := 5
const TYPING_SECONDS := 5.0
const PET_SIZE := Vector2(280, 260)

# bg: [room id for PetalState.room_bg, default picture]; school draws its own.
const ACTIVITIES := {
	"school": {"emoji": "🏫", "label": "School", "text": "I'm at school! 📚 I'm wearing my glasses 👓"},
	"sports": {"emoji": "⚽", "label": "Sports", "text": "Sports day! ⚽ I'm kicking the ball!", "bg": ["sports_field", "res://Sprites/backgrounds/sports_field.jpg"]},
	"home": {"emoji": "🏠", "label": "Home", "text": "Home time! 🍓 Snacks then a nap 😴", "bg": ["living", "res://Sprites/backgrounds/living_room.jpg"]},
	"music": {"emoji": "🎵", "label": "Music", "text": "Music class! 🎵 La la la!", "bg": ["party", "res://Sprites/backgrounds/party_room.jpg"]},
	"swim": {"emoji": "🏊", "label": "Swimming", "text": "Swimming! 💦 Splash splash!", "bg": ["pool_side", "res://Sprites/backgrounds/pool_side.jpg"]},
	"playdate": {"emoji": "🧸", "label": "Playdate", "text": "Playdate with friends! 🎈", "bg": ["garden", "res://Sprites/backgrounds/garden_sunny.jpg"]},
	"martial": {"emoji": "🥋", "label": "Martial Arts", "text": "Martial arts! 🥋 Hi-yah!", "bg": ["martial_arts", "res://Sprites/backgrounds/martial_arts.jpg"]},
	"library": {"emoji": "📚", "label": "Library", "text": "At the library! 📚 Shhh, quiet reading 👓", "bg": ["library", "res://Sprites/backgrounds/library.jpg"]},
	"car": {"emoji": "🚗", "label": "Car Trip", "text": "Car trip! 🚗 Are we there yet?", "bg": ["car_trip", "res://Sprites/backgrounds/car_trip.jpg"]},
	"plane": {"emoji": "✈️", "label": "Airplane", "text": "Up in the airplane! ✈️ Look at the clouds ☁️", "bg": ["airplane", "res://Sprites/backgrounds/airplane.jpg"]},
	"train": {"emoji": "🚂", "label": "Train", "text": "Choo choo! 🚂 All aboard!", "bg": ["train", "res://Sprites/backgrounds/train.jpg"]},
	"beach": {"emoji": "🏖️", "label": "Beach House", "text": "Beach house! 🏖️ Sand and waves 🌊", "bg": ["beach_house", "res://Sprites/backgrounds/beach_house.jpg"]},
	"other": {"emoji": "📌", "label": "Event", "text": "Look, an event! 🎀", "bg": ["living", "res://Sprites/backgrounds/living_room.jpg"]},
}

# Words that mean each activity, for typed plans and typed texts.
const WORDS := {
	"school": ["school", "class", "teacher", "lesson", "read", "book", "homework"],
	"martial": ["martial", "karate", "judo", "taekwondo", "dojo"],
	"library": ["library"],
	"beach": ["beach", "beachhouse", "seaside"],
	"car": ["car", "drive", "road"],
	"plane": ["plane", "airplane", "flight", "airport"],
	"train": ["train", "railway"],
	"sports": ["sport", "sports", "football", "soccer", "ball", "run", "gym", "game"],
	"home": ["home", "house", "nap", "rest", "tea", "dinner", "lunch"],
	"music": ["music", "sing", "song", "dance", "piano"],
	"swim": ["swim", "swimming", "pool"],
	"playdate": ["playdate", "friend", "friends", "play"],
}

# Misspellings she has learned.
const ALIASES := {
	"envirment": "environment", "enviroment": "environment", "envionment": "environment", "enviornment": "environment", "coarl": "coral", "corral": "coral", "globle": "global", "globel": "global", "gobal": "global", "warmin": "warming", "waming": "warming", "histroy": "history", "histry": "history", "yumm": "yummy", "yumy": "yummy", "yumyum": "yummy", "yum": "yummy", "yumi": "yummy", "latinex": "latinx", "latnix": "latinx", "latinix": "latinx", "latinx": "latinx", "espanol": "spanish", "spainish": "spanish", "spanich": "spanish", "pea": "pee", "peeing": "pee", "pooping": "poop", "poo": "poop", "movies": "movie", "moive": "movie", "mooie": "movie",
	"oroenge": "orange", "orenge": "orange", "orang": "orange", "violotet": "violet", "violette": "violet", "voilet": "violet", "viollet": "violet", "lavendar": "lavender", "lavander": "lavender", "tael": "teal", "teel": "teal", "gren": "green", "grean": "green", "bleu": "blue", "pnk": "pink", "yelow": "yellow", "yelllow": "yellow", "rd": "red", "colors": "colour", "colours": "colour", "colour": "colour",
	"shcool": "school", "actividys": "activities", "activitys": "activities", "activity": "activities",
	"animl": "animal", "emojes": "emojis", "emoji": "emojis", "pumkin": "pumpkin", "chrismas": "christmas",
	"valentanes": "valentines", "valentines": "valentines", "alo": "all", "meave": "meow", "meaw": "meow",
	"setings": "settings", "settings": "settings", "resevie": "", "sitter": "babysitter", "baby": "baby",
	"vent": "vent", "favreourite": "favourite", "favourit": "favourite", "favorit": "favorite", "faverite": "favourite", "favrite": "favourite", "favoret": "favourite", "favorate": "favourite", "favoure": "favourite", "favourtie": "favourite", "ur": "your", "u": "you", "embarrassed": "embarrassing", "embarrassment": "embarrassing", "embarrassing": "embarrassing", "enbarising": "embarrassing", "embarising": "embarrassing", "embarrising": "embarrassing", "embarassing": "embarrassing", "enbarrasing": "embarrassing", "embaresing": "embarrassing", "enbarasing": "embarrassing", "enbaressment": "embarrassing", "embarassment": "embarrassing", "embarrasment": "embarrassing", "embarassed": "embarrassing", "enbaressed": "embarrassing", "crimal": "criminal", "crimnal": "criminal", "criminel": "criminal", "liying": "lying", "liar": "lying", "liars": "lying", "lier": "lying", "lyer": "lying", "crook": "criminal", "trup": "trump", "trum": "trump", "tump": "trump", "trmp": "trump", "trumpp": "trump", "trumps": "trump", "boyfreind": "boyfriend", "boyfrend": "boyfriend", "boyfreinds": "boyfriend", "boyfriends": "boyfriend", "girlfreind": "girlfriend", "girlfrend": "girlfriend", "girlfreinds": "girlfriend", "girlfriends": "girlfriend", "chalkbored": "chalkboard", "chalkboared": "chalkboard", "chalkbord": "chalkboard", "stor": "store", "conrer": "corner", "cornor": "corner", "nales": "nails", "wanna": "want", "wnat": "want", "waant": "want", "purpal": "purple", "purpel": "purple", "purpul": "purple", "perple": "purple", "purple": "purple", "ocenan": "ocean", "oceon": "ocean", "baody": "body", "bod": "body", "baodys": "body", "stoplite": "stoplight", "backpak": "backpack", "bakpack": "backpack", "rivers": "river", "creeks": "creek", "creak": "creek", "creeek": "creek", "lite": "light", "darkk": "dark", "spott": "spot", "lgbtq": "lgbtq", "lgbtqia": "lgbtqia", "lgbtqai": "lgbtqia", "lbgt": "lgbt", "lbgtq": "lgbtq", "bisexul": "bisexual", "homosexual": "gay", "transexual": "transgender", "non": "non", "gaye": "gay", "gai": "gay", "lesbain": "lesbian", "lezbian": "lesbian", "panssexual": "pansexual", "pronown": "pronoun", "mabe": "maybe", "mabye": "maybe", "yup": "yes", "yep": "yes", "nope": "no", "ew": "eel", "eww": "eel", "vacatoin": "vacation", "vacations": "vacation", "richmand": "richmond", "virgin": "virginia", "wisconson": "wisconsin", "candoa": "canada", "cars": "car", "trips": "trip", "presant": "present", "presants": "present", "coustume": "costume", "costumes": "costume", "gifts": "gift", "books": "book", "ruthie": "ruthie", "norakate": "norakate", "nora": "norakate", "kate": "norakate",
}

# LGBTQIA+ words she knows. Short ambiguous ones (bi, pan, ace...) only count with a
# cue (gay, pride, gender, "I am ...") so "pan" in "frying pan" is still a pan.
const PRIDE_WORDS := {
	"gay": "Gay means loving someone of the same gender, like two boys or two girls. Love is love! 🏳️‍🌈💕",
	"lesbian": "A lesbian is a girl who loves girls. 💗🏳️‍🌈",
	"bi": "Bi means loving more than one gender, like boys and girls. 💜💙💗",
	"bisexual": "Bisexual means loving more than one gender, like boys and girls. 💜💙💗",
	"pan": "Pan means loving someone no matter their gender. 💛💗💙",
	"pansexual": "Pansexual means loving someone no matter their gender. 💛💗💙",
	"trans": "Trans means your gender is different from the one you were told at birth. Everyone gets to be who they are! 🏳️‍⚧️💙💗",
	"transgender": "Transgender means your gender is different from the one you were told at birth. Everyone gets to be who they are! 🏳️‍⚧️💙💗",
	"nonbinary": "Nonbinary means not only a boy or only a girl. 💛🤍💜🖤 They/them is okay too!",
	"enby": "Enby is short for nonbinary: not only a boy or only a girl. 💛🤍💜🖤",
	"queer": "Queer is a word some people use for being LGBTQIA+. 🌈 Some like it and some don't, so ask first!",
	"ace": "Ace means not feeling crushes the same way other people do. 🖤🤍💜 That's okay!",
	"asexual": "Asexual (or ace) means not feeling crushes the same way other people do. 🖤🤍💜 That's okay!",
	"aro": "Aro means not feeling romantic crushes. 🌿 That's okay too!",
	"aromantic": "Aromantic (or aro) means not feeling romantic crushes. 🌿 That's okay too!",
	"intersex": "Intersex means a body that's a little different from what people usually expect of a boy or girl. 💛💜",
	"straight": "Straight means loving the opposite gender. 💕 Everyone's love is welcome here!",
	"gender": "Gender is how you feel inside: a girl, a boy, both, or neither. 🌈 Everyone gets to be themselves!",
	"lgbt": "LGBTQIA+ means lesbian, gay, bi, trans, queer, intersex, ace and more. Everybody is welcome! 🏳️‍🌈💖",
	"lgbtq": "LGBTQIA+ means lesbian, gay, bi, trans, queer, intersex, ace and more. Everybody is welcome! 🏳️‍🌈💖",
	"lgbtqia": "LGBTQIA+ means lesbian, gay, bi, trans, queer, intersex, ace and more. Everybody is welcome! 🏳️‍🌈💖",
	"pride": "Pride is celebrating being exactly who you are! 🏳️‍🌈🎉 Meow!",
	"pronoun": "Pronouns are words like she, he and they. I'll use yours! 💕",
	"pronouns": "Pronouns are words like she, he and they. I'll use yours! 💕",
	"questioning": "It's okay to wonder and take your time. 💛 No rush. I'm here, and it stays between us. 🤫",
}
const PRIDE_AMBIGUOUS := ["bi", "pan", "ace", "aro", "trans", "straight", "pride", "gender", "enby"]
const PRIDE_CUES := ["lgbt", "lgbtq", "lgbtqia", "gay", "lesbian", "queer", "sexual", "bisexual", "pansexual", "asexual", "transgender", "nonbinary", "flag", "orientation", "identity", "intersex", "aromantic", "questioning"]
const PRIDE_GOOD := ["good", "great", "awesome", "cool", "nice", "amazing", "best", "wonderful", "love", "fine", "okay", "ok", "proud", "happy", "yay", "beautiful"]
const PRIDE_MEAN := ["hate", "bad", "gross", "eel", "eww", "yuck", "wrong", "stupid", "weird", "disgusting", "dumb", "ugly", "sin"]

# "What's your favourite ___?" She has a real answer. Each pet always gives the same
# one (picked from her id), with species picks where it fits. [answers..., emoji]
const FAVOURITES := {
	"colour": [["pink", "purple", "blue", "yellow", "green"], "🎨"],
	"animal": [["kittens", "puppies", "bunnies", "butterflies", "dolphins", "pandas"], "🐾"],
	"food": [["strawberries", "pizza", "cheese", "cookies", "pasta"], "😋"],
	"fruit": [["strawberries", "watermelon", "mango", "blueberries"], "🍓"],
	"drink": [["milk", "hot chocolate", "lemonade", "apple juice"], "🥤"],
	"number": [["7", "3", "9", "10"], "🔢"],
	"season": [["spring", "summer", "autumn", "winter"], "🌸"],
	"day": [["Saturday", "Friday", "Sunday"], "📅"],
	"song": [["a happy dance song", "a lullaby", "my own meow song"], "🎵"],
	"game": [["hide and seek", "tag", "I spy", "dress up"], "🎲"],
	"toy": [["a squeaky toy", "a bouncy ball", "a soft teddy"], "🧸"],
	"movie": [["a sparkly princess movie", "anything with animals", "a funny cartoon"], "🎬"],
	"show": [["a sparkly princess show", "anything with animals", "a funny cartoon"], "📺"],
	"book": [["Harry Potter", "a picture book about animals", "a fairy tale"], "📖"],
	"sport": [["swimming", "soccer", "gymnastics"], "⚽"],
	"flower": [["tulips", "roses", "daisies", "sunflowers"], "🌷"],
	"place": [["the garden", "my cosy bed", "the beach", "home"], "🏠"],
	"holiday": [["Christmas", "Halloween", "my birthday", "Valentine's Day"], "🎉"],
	"subject": [["art", "reading", "music"], "📚"],
	"person": [["you"], "💕"],
	"friend": [["you"], "💕"],
	"name": [["my own name"], "🐾"],
	"weather": [["sunny days", "a gentle rain", "snowy days"], "🌤️"],
	"candy": [["gummy bears", "chocolate", "lollipops"], "🍬"],
	"dessert": [["ice cream", "cupcakes", "strawberry cake"], "🍰"],
	"letter": [["P", "M", "S"], "🔤"],
	"shape": [["heart", "star", "circle"], "⭐"],
	"emoji": [["😻", "🌈", "🦋"], "✨"],
}
# What each kind of pet picks (instead of the list above) for some topics.
const SPECIES_FAVOURITES := {
	"dog": {"food": "bones", "toy": "a tennis ball", "game": "fetch", "animal": "puppies", "song": "a happy woof song"},
	"bird": {"food": "sunflower seeds", "toy": "a shiny bell", "game": "fly-and-catch", "song": "a morning tweet song"},
	"gerbil": {"food": "sunflower seeds", "toy": "a spinny wheel", "game": "hide in the tunnel", "song": "a tiny squeak song"},
	"bunny": {"food": "carrots", "toy": "a cardboard tunnel", "game": "hop and zoom", "song": "a soft nibble song"},
	"cat": {"food": "fish", "toy": "a ball of yarn", "game": "chase the laser dot", "song": "my own meow song"},
}
const FAVOURITE_WORDS := ["favorite", "favourite", "fav", "fave", "best"]
const FAV_CATEGORY_ALIASES := {
	"color": "colour", "pet": "animal", "animals": "animal", "meal": "food", "dinner": "food", "lunch": "food", "breakfast": "food",
	"snack": "food", "drinks": "drink", "tv": "show", "film": "movie", "cartoon": "show", "game": "game", "games": "game",
	"songs": "song", "music": "song", "season": "season", "school": "subject", "class": "subject", "lesson": "subject",
	"sweet": "candy", "treat": "treat",
}

# Eating sounds by food, and what each kind of pet does when it is delighted.
const EAT_SOUNDS := {
	"*crunch crunch*": ["carrot", "apple", "cookie", "cracker", "chip", "popcorn", "pretzel", "nut", "peanut", "seed", "cereal", "toast", "cucumber", "celery", "bone", "corn", "lettuce", "broccoli", "grape", "blueberry", "sunflower", "wheat", "chestnut"],
	"*slurp slurp*": ["milk", "juice", "water", "soup", "tea", "smoothie", "lemonade", "cocoa"],
	"*chomp chomp*": ["meat", "fish", "tuna", "chicken", "steak", "burger", "bacon", "sausage", "sandwich", "shrimp", "drumstick"],
	"*nom nom nom*": ["cake", "muffin", "cupcake", "pie", "bread", "pizza", "pasta", "pancake", "waffle", "noodle", "strawberry", "fruit", "food", "dinner", "lunch", "breakfast"],
	"*lick lick*": ["candy", "chocolate", "honey", "lollipop", "ice", "cream", "dessert"],
}
const EAT_EMOJI_SOUNDS := {
	"*crunch crunch*": ["🥕", "🍎", "🌽", "🥬", "🥦", "🌰", "🥜", "🌻", "🌾", "🍇", "🫐", "🦴"],
	"*chomp chomp*": ["🐟", "🐠", "🍤", "🍖", "🥩", "🍗"],
	"*slurp slurp*": ["🥛"],
	"*nom nom nom*": ["🍓"],
}
const DELIGHT := {
	"cat": ["*purrs and rubs against you*", "*does a happy tail swish*"],
	"dog": ["*rolls over and wags the whole body*", "*spins in a circle and loves it*"],
	"bird": ["*flaps wings and chirps happily*", "*hops from foot to foot*"],
	"gerbil": ["*zooms around the wheel*", "*stuffs it in cheeks and squeaks*"],
	"bunny": ["*binkies with joy*", "*does a happy flop*"],
}
const GIVE_WORDS := ["give", "gave", "gives", "giving", "here", "take", "feed", "fed", "offer", "have", "hand", "share", "serve", "bring", "brought", "eat", "ate", "yummy", "tasty", "dinner", "lunch", "breakfast"]

# Words she knows, and what she says about them.
const REPLIES := {
	"environment": "The environment is our home! 🌍💚 Let's keep it clean for animals!", "coral": "Coral reefs! 🪸🐠 They're homes for lots of fish, and we need to protect them!",
	"global": "Global means the whole world! 🌎", "warming": "Global warming is when the Earth gets too hot 🌡️🌍 It's hurting animals' homes. We can help by saving energy and planting trees! 🌳",
	"history": "History is stories about the past! 📜🏛️ I like learning how things used to be!", "movie": "A movie! 🎬🍿 Can we watch it together?",
	"latinx": "Latinx is a word for people with roots in Latin America, for everyone, not just boys or girls! 💖🌎", "spanish": "Spanish! 🇪🇸 It's a language, and \"hola\" means hello! 👋 People speak it all over the world, and Latinx and Latino/a people often do too! 💖",
	"yummy": "Yummy!! 😋🍓 What are we eating?", "pee": "Hehe, the potty! 🚽😹 Wash your paws after!", "eat": "Eat? Yes please!! 🍽️😋", "cake": "Cake! 🍰 Yummy! Can I have a bite? 😋",
	"snow": "Snow! ❄️ So cold and fluffy!",
	"name": "I'm %NAME%! 🐱", "activities": "I love activities! 📅 School, sports, music...",
	"school": "School is fun! 📚👓", "sports": "Sports! ⚽ Kick kick!", "happy": "I'm so happy! 😸✨",
	"dance": "Let's dance! 💃🎵", "video": "Ooh, a video! 🎬", "times": "Check the planner for times! ⏰",
	"dog": "Woof woof! 🐶 Dogs are my friends.", "pet": "Pets are the best! 🐾", "bird": "Tweet tweet! 🐦",
	"emojis": "I love emojis! 😻🎉🌈", "cute": "You're cuter! 🥰", "animal": "I love animals! 🐾🦁🐶🐦",
	"no": "Oh no! 😿", "thank": "You're welcome! 😸", "you": "Me? 😺", "whatever": "Hehe, whatever! 😹",
	"sure": "Okay! 👍", "yes": "Yay! 😸", "mouse": "A mouse?! 🐭 Where?!", "amazing": "Amazing! 🌟",
	"here": "I'm here! 🐾", "me": "You and me! 💕", "pj": "PJ! 💖 Hi PJ!", "pjs": "Cozy PJs! 😴🩳", "meow": "Meow meow! 😻",
	"ruthie": "Ruthie! 💖 Hi Ruthie!", "norakate": "Hi Norakate! 🎀", "lion": "Roar! 🦁 A big cat, like me!",
	"net": "Ooh, a net! 🥅", "sleep": "Night night! 😴💤", "crate": "My crate is cosy! 📦", "cat": "Meow! I'm a cat! 🐱",
	"toy": "I love my toys! 🧶🎾", "ball": "Ball! ⚽ Throw it!", "line": "Line up! 🐾🐾🐾",
	"well": "Well well well! 😸", "pumpkin": "Pumpkin! 🎃", "christmas": "Christmas! 🎄🎁", "halloween": "Halloween! 🎃👻",
	"valentines": "Happy Valentine's! 💝", "day": "Today: %TODAY%", "pillow": "Soft pillow! 🛏️", "bed": "Bedtime! 😴",
	"box": "A box! 📦 I'm going in!", "food": "Yum! 🍓😋", "muffin": "Muffin! 🧁😋", "claw": "I scratch with my claws! 🐾",
	"flower": "Pretty flowers! 🌷", "garden": "I love the garden! 🌷🦋", "groomer": "The groomer makes me fluffy! ✨",
	"room": "Which room? 🏠", "groom": "Brush brush! ✨", "bath": "Splash! 🛁🫧", "soup": "Soup! 🍲 Slurp!",
	"soap": "Bubbly soap! 🧼", "tub": "Bath tub time! 🛁", "water": "Water! 💦", "long": "So long! 📏",
	"short": "Short and cute! 😸", "love": "Love you more! 💕💕", "baby": "Aww, a baby! 🍼", "babysitter": "My babysitter is nice! 💕",
	"kid": "Hi kid! 👋", "kitten": "A kitten! 😻", "settings": "Settings? I like mine fluffy! ⚙️",
	"annoying": "Oh no, annoying! 😾 Tell me more.", "problems": "Oh no, a problem? 😿 I'm here for you.",
	"vent": "You can vent to me. 💕 I'm listening.", "tree": "I climb trees! 🌳", "chicken": "Cluck cluck! 🐔",
	"rap": "Yo yo yo! 🎤😼", "learn": "I love to learn! 🧠📚", "travel": "Let's travel! ✈️🌍", "cart": "Vroom, a cart! 🛒", "car": "Vroom vroom! 🚗",
	"trip": "A trip! 🧳 Where are we going?", "vacation": "Vacation! 🏖️😎", "richmond": "Richmond! 🏙️ Let's go!",
	"virginia": "Virginia! 🌳 Pretty!", "wisconsin": "Wisconsin! 🧀 Cheese!", "canada": "Canada! 🍁 Oh Canada!",
	"hate": "Oh no, that's a big feeling! 😿 Want to vent?", "purr": "Purrrrr... 😻💤", "house": "Home sweet home! 🏠", "gift": "A gift?! 🎁 For me?", "present": "A present! 🎁✨",
	"costume": "Ooh, a costume! 🎭👑", "harry": "Harry Potter! ⚡🧙", "potter": "Harry Potter! ⚡🧙", "book": "I love books! 📖👓", "tv": "TV time! 📺🍿", "rat": "A rat?! 🐀 Eek!", "hi": "Meow! 🐾 Hi %YOU%!",
	"fu": "Fun! 🎉", "fun": "Fun! 🎉😸", "funny": "Hehe, funny! 😹", "maybe": "Maybe... 🤔", "crush": "Ohhhh what are they like??? 😳💕",
	"lucy": "Lucy! 💖 Hi Lucy!", "eloise": "Eloise! 💖 Hi Eloise!", "fish": "Fishy! 🐟😋", "eel": "Eww, an eel! 🤢 Gross! 😿 Sad... bleh!!!",
	"grow": "I'm growing! 🌱📈", "plant": "A plant! 🪴 Grow, grow!", "ant": "An ant! 🐜 Tiny!", "bug": "A bug! 🐛 Ooh!",
	"cool": "Cool! 😎", "can": "I can! 😸", "now": "Right now! ⏰", "tell": "Tell me! 👂", "answer": "The answer? 🤔",
	"question": "A question? ❓ Ask me!", "riddle": "Ooh, a riddle! 🧩", "joke": "Ooh, a joke! 😹",
	"boyfriend": "A boyfriend? 😳💕 Ooh, tell me about them!", "girlfriend": "A girlfriend? 😳💕 Ooh, tell me about them!",
	"want": "Ooh, what do you want? 🥺 Tell me!", "store": "A store! 🏪 What are we buying?", "shop": "A shop! 🛍️ Ooh!", "corner": "A corner! 📐 I hide in corners! 😼",
	"nail": "Nails! 💅 Mine are claws! 🐾", "chalk": "Chalk! 🖍️ It makes dusty paws!", "chalkboard": "A chalkboard! 🧑‍🏫 Don't scratch it!", "board": "A board! 📋",
	"creek": "A creek! 🏞️💦 Splash splash!", "ocean": "The ocean! 🌊 So big and blue!", "river": "A river! 🏞️ Flow, flow, flow!",
	"lake": "A lake! 🛶 Calm and shiny!", "pond": "A pond! 🐸 Ribbit!", "sea": "The sea! 🌊🐚",
	"body": "A body of water? 🌊 Like a creek, river, lake or ocean! Or my fluffy body? 😸", "stop": "Stop! 🛑 Okay, I'm frozen! 😹",
	"light": "Light! 💡✨", "dark": "Ooh, it's dark! 🌙 I can see in the dark, I'm a cat! 😼", "spot": "A spot! 🔵 Where?",
	"stoplight": "A stop light! 🚦 Red means stop, yellow means slow, green means go!", "backpack": "A backpack! 🎒 What's inside?",
	"pink": "Pink! 🩷 So pretty!", "purple": "Purple! 💜 So pretty!",
	"blue": "Blue! 💙 Like the sky and the ocean!", "red": "Red! ❤️ Like strawberries and hearts!", "orange": "Orange! 🧡 Like a sunset, or a carrot!", "yellow": "Yellow! 💛 Sunshine and bananas!", "teal": "Teal! 🩵 Blue and green mixed together, so pretty!", "green": "Green! 💚 Like grass and leaves!", "lavender": "Lavender! 💜 Soft purple, and it smells so nice!", "violet": "Violet! 💜 A deep, pretty purple!", "colour": "I know lots of colours! 🌈 Pink, blue, purple, red, orange, yellow, teal, green, lavender, violet... which do you like?",
}
# Little words she knows but has nothing special to say about.
const FILLER := ["a", "i", "but", "as", "it", "them", "she", "him", "all", "on", "to", "of", "is", "the", "and", "an", "my", "we", "do", "can", "so", "in", "its", "im"]

# Tell her you like one of these and she gets excited about it.
const LIKE_WORDS := ["like", "love", "luv", "heart", "enjoy", "favorite", "favourite"]
const THINGS := ["book", "tv", "video", "toy", "ball", "gift", "present", "costume", "harry", "potter", "flower", "garden", "muffin", "food", "soup", "pumpkin", "christmas", "halloween", "valentines", "cat", "dog", "bird", "mouse", "lion", "kitten", "chicken", "tree", "pillow", "bed", "box", "rap", "dance", "sports", "school", "bath", "emojis", "animal", "learn", "travel", "cart", "car", "trip", "vacation", "richmond", "virginia", "wisconsin", "canada", "house", "pink", "purple", "ocean", "creek", "river", "lake", "backpack"]

# Foods she knows: name -> [emoji, eating sound].
const FOODS := {
	"pizza": ["🍕", "*nom nom nom*"], "burger": ["🍔", "*chomp chomp*"], "hotdog": ["🌭", "*chomp chomp*"], "fries": ["🍟", "*crunch crunch*"],
	"taco": ["🌮", "*crunch crunch*"], "burrito": ["🌯", "*nom nom nom*"], "sandwich": ["🥪", "*chomp chomp*"], "sushi": ["🍣", "*nom nom nom*"],
	"rice": ["🍚", "*nom nom nom*"], "pasta": ["🍝", "*slurp slurp*"], "spaghetti": ["🍝", "*slurp slurp*"], "noodle": ["🍜", "*slurp slurp*"],
	"soup": ["🍲", "*slurp slurp*"], "salad": ["🥗", "*crunch crunch*"], "egg": ["🥚", "*nom nom nom*"], "cheese": ["🧀", "*nom nom nom*"],
	"bread": ["🍞", "*nom nom nom*"], "toast": ["🍞", "*crunch crunch*"], "pancake": ["🥞", "*nom nom nom*"], "waffle": ["🧇", "*nom nom nom*"],
	"bacon": ["🥓", "*chomp chomp*"], "cookie": ["🍪", "*crunch crunch*"], "cake": ["🍰", "*nom nom nom*"], "cupcake": ["🧁", "*nom nom nom*"],
	"donut": ["🍩", "*nom nom nom*"], "doughnut": ["🍩", "*nom nom nom*"], "icecream": ["🍦", "*lick lick*"], "chocolate": ["🍫", "*lick lick*"],
	"candy": ["🍬", "*lick lick*"], "lollipop": ["🍭", "*lick lick*"], "popcorn": ["🍿", "*crunch crunch*"], "pretzel": ["🥨", "*crunch crunch*"],
	"banana": ["🍌", "*nom nom nom*"], "lemon": ["🍋", "*slurp slurp*"], "watermelon": ["🍉", "*nom nom nom*"],
	"peach": ["🍑", "*nom nom nom*"], "pear": ["🍐", "*crunch crunch*"], "cherry": ["🍒", "*nom nom nom*"], "pineapple": ["🍍", "*nom nom nom*"],
	"mango": ["🥭", "*nom nom nom*"], "potato": ["🥔", "*nom nom nom*"], "tomato": ["🍅", "*nom nom nom*"], "cucumber": ["🥒", "*crunch crunch*"],
	"mushroom": ["🍄", "*nom nom nom*"], "pumpkin": ["🎃", "*nom nom nom*"], "honey": ["🍯", "*lick lick*"], "juice": ["🧃", "*slurp slurp*"],
	"smoothie": ["🥤", "*slurp slurp*"], "cocoa": ["☕", "*slurp slurp*"], "lemonade": ["🍋", "*slurp slurp*"],
}

# First names she knows (none that are also everyday words).
const NAMES := ["emma", "olivia", "ava", "sophia", "mia", "isabella", "charlotte", "amelia", "harper", "evelyn", "abigail", "emily", "ella", "elizabeth", "sofia", "avery", "scarlett", "victoria", "madison", "luna", "chloe", "layla", "riley", "zoe", "nora", "lily", "hannah", "lucy", "stella", "aurora", "natalie", "leah", "ellie", "paisley", "audrey", "skylar", "savannah", "anna", "maya", "sarah", "emilia", "molly", "sadie", "ivy", "piper", "clara", "alice", "jessica", "megan", "katie", "lauren", "bella", "ruby", "daisy", "poppy", "freya", "ruthie", "norakate",
	"liam", "noah", "oliver", "james", "elijah", "william", "henry", "lucas", "benjamin", "theodore", "jack", "levi", "alexander", "mason", "ethan", "jacob", "michael", "daniel", "logan", "jackson", "sebastian", "aiden", "matthew", "samuel", "david", "joseph", "carter", "owen", "wyatt", "john", "luke", "gabriel", "anthony", "isaac", "grayson", "dylan", "leo", "jayden", "julian", "lincoln", "joshua", "andrew", "nathan", "adam", "tyler", "ryan", "connor", "caleb", "thomas", "charlie", "oscar", "finn", "eli", "max", "sam", "ben", "tom", "pj"]

# Little words, answered when they're all you say.
const SHORT_WORDS := {
	"if": "If? 🤔 If what? Tell me more!", "can": "Can I? Can you? 🥺 Can what?", "i": "You! 💕 Tell me about you!",
}

# Everyday words she knows, grouped: each group has one reply and every word has its own emoji.
const WORD_GROUPS := [
	["weather", "%s%s! Weather is fun to watch from the window!", {"rain": "🌧️", "sun": "☀️", "snowy": "🌨️", "wind": "💨", "storm": "⛈️", "thunder": "⚡", "lightning": "🌩️", "cloud": "☁️", "rainbow": "🌈", "fog": "🌫️", "hot": "🥵", "warm": "🌡️", "sunny": "🌞", "windy": "🌬️", "hail": "🧊", "frost": "❄️", "tornado": "🌪️", "hurricane": "🌀", "puddle": "💦", "umbrella": "☂️", "breeze": "🍃"}],
	["body", "%s%s! I have those too! Well, mine are cuter 😸", {"head": "🗣️", "nose": "👃", "eye": "👁️", "ear": "👂", "mouth": "👄", "tooth": "🦷", "teeth": "🦷", "tongue": "👅", "finger": "👆", "foot": "🦶", "feet": "🦶", "leg": "🦵", "arm": "💪", "knee": "🦵", "elbow": "💪", "shoulder": "🤷", "tummy": "🫃", "back": "🔙", "neck": "🦒", "hair": "💇", "skin": "🧴", "brain": "🧠", "muscle": "💪", "toe": "🦶", "chin": "🙂", "cheek": "😊", "lip": "💋", "whisker": "🐱", "tail": "🐾", "paw": "🐾", "fur": "🧶", "feather": "🪶", "wing": "🪽", "beak": "🐦"}],
	["clothes", "%s%s! Ooh, fashion! Do I get a bow too? 🎀", {"shirt": "👕", "dress": "👗", "pants": "👖", "jeans": "👖", "shorts": "🩳", "skirt": "👗", "sock": "🧦", "shoe": "👟", "boot": "🥾", "sandal": "🩴", "hat": "🎩", "cap": "🧢", "scarf": "🧣", "glove": "🧤", "coat": "🧥", "jacket": "🧥", "sweater": "🧶", "hoodie": "🧥", "pajama": "🛌", "swimsuit": "🩱", "bow": "🎀", "crown": "👑", "tiara": "👑", "necklace": "📿", "bracelet": "📿", "ring": "💍", "earring": "💎", "glasses": "👓", "purse": "👛", "belt": "👖", "tie": "👔", "uniform": "👔", "mask": "😷", "cape": "🦸", "apron": "🍳", "slipper": "🥿"}],
	["family", "%s%s! Family is the best! 💕", {"mommy": "👩", "mother": "👩", "daddy": "👨", "father": "👨", "grandma": "👵", "grandpa": "👴", "grandmother": "👵", "grandfather": "👴", "aunt": "👩", "uncle": "👨", "family": "👨‍👩‍👧", "parent": "👪", "child": "🧒", "neighbor": "🏘️", "twin": "👯", "husband": "🤵", "wife": "👰", "son": "👦", "daughter": "👧", "nephew": "🧒", "niece": "🧒"}],
	["jobs", "%s%s! What a cool job! What do they do all day?", {"doctor": "🧑‍⚕️", "nurse": "🧑‍⚕️", "dentist": "🦷", "firefighter": "🧑‍🚒", "police": "👮", "chef": "🧑‍🍳", "farmer": "🧑‍🌾", "pilot": "🧑‍✈️", "astronaut": "🧑‍🚀", "scientist": "🧑‍🔬", "artist": "🧑‍🎨", "singer": "🎤", "dancer": "💃", "builder": "👷", "mechanic": "🔧", "librarian": "📚", "mailman": "📬", "driver": "🚌", "captain": "⚓", "president": "🏛️", "judge": "⚖️", "lawyer": "⚖️", "writer": "✍️", "actor": "🎭", "princess": "👸", "prince": "🤴", "queen": "👑", "king": "🤴", "pirate": "🏴‍☠️", "wizard": "🧙", "witch": "🧙", "fairy": "🧚", "mermaid": "🧜", "superhero": "🦸", "ninja": "🥷", "knight": "🛡️", "cashier": "🛒", "barber": "💈"}],
	["sports", "%s%s! Sports are so fun! Ready, set, go! 🏃", {"basketball": "🏀", "baseball": "⚾", "tennis": "🎾", "volleyball": "🏐", "golf": "⛳", "hockey": "🏒", "running": "🏃", "skating": "⛸️", "skiing": "⛷️", "surfing": "🏄", "cycling": "🚴", "bowling": "🎳", "boxing": "🥊", "archery": "🏹", "rugby": "🏉", "badminton": "🏸", "ballet": "🩰", "yoga": "🧘", "hiking": "🥾", "climbing": "🧗", "fishing": "🎣", "camping": "🏕️", "trophy": "🏆", "medal": "🥇", "race": "🏁", "team": "👥", "coach": "📣", "score": "🎯", "goal": "🥅", "jump": "🦘", "kick": "🦵", "throw": "🤾"}],
	["subjects", "%s%s! Learning is fun! Smart kitty! 🤓", {"math": "➕", "science": "🔬", "writing": "✏️", "spelling": "🔤", "geography": "🗺️", "grammar": "📝", "test": "📝", "quiz": "❓", "recess": "🛝", "classroom": "🏫", "desk": "🪑", "pencil": "✏️", "pen": "🖊️", "crayon": "🖍️", "marker": "🖍️", "eraser": "🧽", "notebook": "📓", "paper": "📄", "scissors": "✂️", "glue": "🧴", "ruler": "📏", "calculator": "🧮", "computer": "💻", "tablet": "📱", "phone": "📱", "map": "🗺️", "globe": "🌍", "alphabet": "🔤", "story": "📖", "poem": "📜", "dictionary": "📕", "grade": "💯"}],
	["vehicles", "%s%s! Vroom vroom! Can we go for a ride? 🚗", {"bus": "🚌", "truck": "🚚", "helicopter": "🚁", "boat": "⛵", "ship": "🚢", "bike": "🚲", "bicycle": "🚲", "scooter": "🛴", "skateboard": "🛹", "rocket": "🚀", "taxi": "🚕", "tractor": "🚜", "motorcycle": "🏍️", "ambulance": "🚑", "subway": "🚇", "submarine": "🚢", "wagon": "🛒", "sled": "🛷", "canoe": "🛶", "balloon": "🎈", "van": "🚐", "limo": "🚙", "bridge": "🌉", "traffic": "🚦", "tunnel": "🚇", "wheel": "🛞", "engine": "⚙️", "seatbelt": "🪢"}],
	["nature", "%s%s! Nature is so pretty! 🌿", {"rose": "🌹", "tulip": "🌷", "grass": "🌱", "leaf": "🍃", "leaves": "🍂", "bush": "🌿", "cactus": "🌵", "rock": "🪨", "stone": "🪨", "sand": "🏖️", "mud": "🟤", "dirt": "🟤", "hill": "⛰️", "volcano": "🌋", "cave": "🕳️", "desert": "🏜️", "jungle": "🌴", "island": "🏝️", "waterfall": "🏞️", "wave": "🌊", "planet": "🪐", "sky": "🌌", "earth": "🌍", "sunrise": "🌅", "sunset": "🌇", "branch": "🌿", "nest": "🪺", "web": "🕸️", "shell": "🐚", "pearl": "🦪", "stick": "🪵", "log": "🪵", "fire": "🔥", "smoke": "💨", "air": "🌬️"}],
	["feelings", "%s%s! Feelings are important! Want a cuddle? 🫂", {"mad": "😡", "nervous": "😬", "excited": "🤩", "jealous": "😒", "shy": "🙈", "silly": "🤪", "grumpy": "😤", "thirsty": "🥤", "sick": "🤒", "brave": "🦁", "calm": "😌", "worried": "😟", "confused": "😕", "surprised": "😲", "cranky": "😒", "giggly": "🤭", "cheerful": "😄", "hopeful": "🤞", "kind": "💗", "gentle": "🤲", "lazy": "🛋️", "busy": "⏰", "curious": "🧐", "grateful": "🙏", "joyful": "😆"}],
	["music", "%s%s! La la la! Music makes me dance! 💃", {"guitar": "🎸", "drum": "🥁", "violin": "🎻", "trumpet": "🎺", "flute": "🪈", "saxophone": "🎷", "harp": "🪕", "banjo": "🪕", "microphone": "🎤", "concert": "🎤", "band": "🎸", "choir": "🎶", "melody": "🎵", "rhythm": "🥁", "karaoke": "🎤", "headphones": "🎧", "radio": "📻", "speaker": "🔊", "note": "🎼", "lyrics": "📜", "dancing": "🕺", "disco": "🪩"}],
	["toys", "%s%s! Ooh, can I play too?! 🎾", {"doll": "🪆", "teddy": "🧸", "puzzle": "🧩", "lego": "🧱", "block": "🧱", "kite": "🪁", "yoyo": "🪀", "marble": "🔮", "chess": "♟️", "dice": "🎲", "slide": "🛝", "swing": "🛝", "trampoline": "🤸", "bubble": "🫧", "yarn": "🧶", "laser": "🔴", "squeaky": "🐭", "frisbee": "🥏", "sandbox": "🏖️", "playdough": "🎨", "slime": "🟢", "fidget": "🌀", "robot": "🤖", "drone": "🛸", "videogame": "🎮", "console": "🎮", "tent": "⛺", "fort": "🏰", "treehouse": "🏡", "boomerang": "🪃"}],
	["holidays", "%s%s! Celebrations are the best! 🎉", {"birthday": "🎂", "easter": "🐣", "thanksgiving": "🦃", "hanukkah": "🕎", "diwali": "🪔", "eid": "🌙", "ramadan": "🌙", "kwanzaa": "🕯️", "valentine": "💘", "weekend": "🛋️", "fall": "🍂", "fireworks": "🎆", "confetti": "🎊", "surprise": "🎁", "parade": "🎺", "picnic": "🧺", "bbq": "🍖", "sleepover": "🛏️"}],
	["time", "%s%s! Time flies when we play! ⏰", {"monday": "📅", "tuesday": "📅", "wednesday": "📅", "thursday": "📅", "friday": "🎉", "saturday": "🛋️", "sunday": "🌞", "january": "📅", "february": "📅", "march": "📅", "april": "🌧️", "june": "☀️", "july": "🎆", "august": "☀️", "september": "🍂", "october": "🎃", "november": "🦃", "december": "🎄", "morning": "🌅", "afternoon": "🌞", "evening": "🌆", "tonight": "🌙", "tomorrow": "📆", "yesterday": "⏪", "calendar": "📅", "always": "♾️", "sometimes": "🤷", "soon": "⏳"}],
	["shapes", "%s%s! I know my shapes! ✨", {"square": "🟦", "triangle": "🔺", "rectangle": "▭", "oval": "🥚", "diamond": "💎", "cube": "🧊", "sphere": "🔮", "cone": "🍦", "cylinder": "🥫", "curve": "〰️", "stripe": "🦓", "dot": "⚫", "spiral": "🌀", "zigzag": "⚡", "big": "🐘", "small": "🐜", "tiny": "🔬", "huge": "🦣", "round": "⚽", "flat": "📄", "tall": "🦒", "tallest": "🦒", "fast": "🐆", "slow": "🐌", "heavy": "🏋️", "soft": "🧸", "hard": "🪨", "smooth": "🪞", "fluffy": "☁️", "sparkly": "✨", "shiny": "✨", "bumpy": "🥒", "sticky": "🍯"}],
	["home", "%s%s! Home sweet home! I love cosy things! 🛋️", {"couch": "🛋️", "sofa": "🛋️", "blanket": "🧣", "chair": "🪑", "table": "🍽️", "lamp": "💡", "door": "🚪", "window": "🪟", "stairs": "🪜", "roof": "🏠", "floor": "🟫", "wall": "🧱", "rug": "🧶", "mirror": "🪞", "fridge": "🧊", "oven": "🔥", "stove": "🍳", "sink": "🚰", "shower": "🚿", "toilet": "🚽", "toothbrush": "🪥", "brush": "🪮", "broom": "🧹", "trash": "🗑️", "laundry": "🧺", "closet": "👚", "shelf": "📚", "basket": "🧺", "cup": "🥤", "plate": "🍽️", "bowl": "🥣", "spoon": "🥄", "fork": "🍴", "knife": "🔪", "bottle": "🍼", "key": "🔑", "television": "📺", "fireplace": "🔥", "attic": "🏚️", "garage": "🚗", "fence": "🚧", "mailbox": "📬"}],
	["verbs", "%s%s! Ooh, I know that word! Tell me more! 😸", {"climb": "🧗", "hide": "🙈", "seek": "🔍", "chase": "🏃", "catch": "🤲", "dig": "⛏️", "fly": "🕊️", "laugh": "😂", "smile": "😊", "wake": "⏰", "walk": "🚶", "skip": "🏃", "spin": "🌀", "twirl": "💃", "wiggle": "🪱", "stretch": "🧘", "yawn": "🥱", "sneeze": "🤧", "cough": "😷", "blink": "😉", "clap": "👏", "cheer": "📣", "whisper": "🤫", "shout": "📢", "draw": "✏️"}],
	["actions", "%s%s! Ooh, I know that word! Tell me more! 😸", {"listen": "👂", "look": "👀", "teach": "👩‍🏫", "build": "🏗️", "cook": "🍳", "bake": "🧁", "clean": "🧹", "wash": "🧼", "paint": "🎨", "explore": "🧭", "pretend": "🎭", "sparkle": "✨", "wait": "⏳", "sit": "🪑", "stand": "🧍", "write": "✍️", "count": "🔢", "hop": "🐰", "roll": "🔄", "crawl": "🐛", "zoom": "💨"}],
	["manners", "%s%s! That's so polite! 💖", {"sorry": "🥺", "welcome": "🤗", "excuse": "🙏", "pardon": "🙏", "congratulations": "🎉", "congrats": "🎉", "sweetie": "💕", "buddy": "🫂", "bestie": "👯", "pal": "🤝", "kindness": "💗", "polite": "🎩", "bully": "🚫", "fair": "⚖️", "promise": "🤞", "trust": "🤝", "teamwork": "👥", "respect": "🙌", "honest": "💯", "safe": "🛡️", "careful": "⚠️"}],
	["questions", "%s%s! Ooh, good thinking!", {"because": "💡", "probably": "🤔", "really": "😲", "seriously": "😮", "actually": "💡", "definitely": "💯", "absolutely": "💯", "alright": "👍", "fantastic": "🌟", "terrific": "🌟", "fabulous": "💅", "brilliant": "💡", "perfect": "💯", "lovely": "🌷", "pretty": "🌸", "adorable": "🥰", "gorgeous": "💖", "hilarious": "😂", "strange": "🤨", "spooky": "🎃", "creepy": "🕷️", "yucky": "🤮", "delicious": "😋", "stinky": "💨", "messy": "🍝", "noisy": "📢", "quiet": "🤫", "loud": "📢"}],
	["science", "%s%s! Science is amazing!", {"magnet": "🧲", "battery": "🔋", "electricity": "⚡", "gravity": "🍎", "atom": "⚛️", "telescope": "🔭", "microscope": "🔬", "experiment": "🧪", "galaxy": "🌌", "comet": "☄️", "asteroid": "☄️", "universe": "🌌", "recycle": "♻️", "pollution": "🏭", "energy": "⚡", "solar": "☀️", "forecast": "📺", "climate": "🌡️", "ecosystem": "🌿", "habitat": "🏡", "extinct": "🦖", "fossil": "🦴", "dna": "🧬", "germs": "🦠", "vaccine": "💉", "medicine": "💊", "bandage": "🩹", "temperature": "🌡️"}],
	["verbs", "%s%s! Ooh, I know that word! Tell me more! 😸", {"play": "🎾", "swim": "🏊", "run": "🏃", "sing": "🎤", "cry": "😢", "hug": "🤗", "cuddle": "🫂", "snuggle": "🧸", "nap": "😴", "dream": "💭", "share": "🤲", "help": "🤝", "learn": "🧠", "think": "💭", "remember": "🧠", "imagine": "🌈", "discover": "🔭", "travel": "🧳", "visit": "🚪", "stop": "🛑", "dance": "💃", "read": "📖", "sleep": "😴", "eat": "🍽️", "drink": "🥤", "kiss": "😘", "giggle": "🤭", "laughing": "😂"}],
	["body_etc", "%s%s! Ooh, I know that word! Tell me more! 😸", {"hand": "✋", "heart": "❤️", "bone": "🦴", "belly": "🫃", "face": "🙂", "legs": "🦵", "arms": "💪", "hands": "✋", "fingers": "👆"}],
	["clothes", "%s%s! Ooh, I know that word! Tell me more! 😸", {"sunglasses": "🕶️", "backpack": "🎒", "costume": "🎭", "pajamas": "🛌", "clothes": "👚", "outfit": "👗", "sneakers": "👟", "shoes": "👟"}],
	["family", "%s%s! Ooh, I know that word! Tell me more! 😸", {"friend": "🫂", "friends": "🫂", "kid": "🧒", "kids": "🧒", "teacher": "🧑‍🏫", "baby": "👶", "sister": "👧", "brother": "👦", "mom": "👩", "dad": "👨", "grandparents": "👵", "people": "🧑‍🤝‍🧑", "everyone": "🌍", "boy": "👦", "girl": "👧", "man": "👨", "woman": "👩"}],
	["sports", "%s%s! Ooh, I know that word! Tell me more! 😸", {"soccer": "⚽", "football": "🏈", "swimming": "🏊", "gymnastics": "🤸", "karate": "🥋", "game": "🎮", "games": "🎮", "win": "🏆", "lose": "😿", "winner": "🥇", "practice": "🔁", "exercise": "🏋️"}],
	["school", "%s%s! Ooh, I know that word! Tell me more! 😸", {"reading": "📖", "art": "🎨", "music": "🎶", "gym": "🏋️", "book": "📚", "books": "📚", "library": "📚", "school": "🏫", "homework": "📚", "learning": "🧠", "smart": "🤓", "genius": "🧠", "idea": "💡", "question": "❓", "answer": "✅"}],
	["nature", "%s%s! Ooh, I know that word! Tell me more! 😸", {"tree": "🌳", "trees": "🌳", "flower": "🌸", "flowers": "🌸", "water": "💧", "star": "⭐", "stars": "⭐", "moon": "🌙", "sea": "🌊", "river": "🏞️", "lake": "🏞️", "mountain": "⛰️", "ocean": "🌊", "forest": "🌲"}],
	["tech", "%s%s! Ooh, I know that word! Tell me more! 😸", {"video": "🎬", "internet": "🌐", "wifi": "📶", "email": "📧", "text": "💬", "message": "💬", "photo": "📸", "picture": "🖼️", "camera": "📷", "app": "📱", "website": "🌐", "password": "🔑", "screen": "📺", "selfie": "🤳"}],
	["misc", "%s%s! Ooh, I know that word! Tell me more! 😸", {"money": "💰", "coin": "🪙", "coins": "🪙", "treasure": "💎", "magic": "🪄", "wand": "🪄", "spell": "✨", "ghost": "👻", "monster": "👹", "zombie": "🧟", "vampire": "🧛", "angel": "😇", "devil": "😈", "alien": "👽", "dragon": "🐉", "castle": "🏰", "kingdom": "👑", "adventure": "🗺️", "mystery": "🕵️", "detective": "🕵️", "secret": "🤫", "luck": "🍀", "lucky": "🍀", "shopping": "🛍️", "store": "🏪", "market": "🛒", "menu": "📜", "order": "🧾", "hungry": "🍽️", "full": "😌", "sleepy": "😴"}],
]

var _word_index: Dictionary = {}

# word -> [emoji, reply template], built once from WORD_GROUPS.
func _group_word(w: String) -> Array:
	if _word_index.is_empty():
		for group in WORD_GROUPS:
			for word in group[2]:
				_word_index[word] = [group[2][word], group[1]]
	for base in [w, w.trim_suffix("s"), w.trim_suffix("es")]:
		if _word_index.has(base):
			return [base] + _word_index[base]
	return []


# Places she knows: name -> [emoji, what she says].
const PLACES := {
	"home": ["🏡", "Home is my favourite place!"], "house": ["🏠", "A house! So cosy!"], "park": ["🌳", "The park! Can we play there?"], "beach": ["🏖️", "The beach! Sand and waves!"],
	"zoo": ["🦁", "The zoo! So many animals!"], "farm": ["🚜", "A farm! Cows and pigs and chickens!"], "forest": ["🌲", "A forest! Trees everywhere!"], "mountain": ["⛰️", "A mountain! So high!"],
	"ocean": ["🌊", "The ocean is deep and full of fish!"], "river": ["🏞️", "A river! Splash!"], "lake": ["🏞️", "A lake! Ducks live there!"], "city": ["🏙️", "A big city! So many people!"],
	"town": ["🏘️", "My town! I know all the good spots!"], "library": ["📚", "The library! Shhh, quiet paws!"], "museum": ["🏛️", "A museum! Old things from history!"], "hospital": ["🏥", "The hospital helps people feel better!"],
	"vet": ["🩺", "The vet! Hmm, I don't love it, but they help me!"], "playground": ["🛝", "The playground! Swings and slides!"], "mall": ["🛍️", "The mall! Lots of shops!"], "restaurant": ["🍽️", "A restaurant! Yummy food!"],
	"cafe": ["☕", "A cafe! Smells so good!"], "bakery": ["🥐", "A bakery! Cakes and bread!"], "airport": ["✈️", "An airport! Planes go whoosh!"], "country": ["🌎", "So many countries in the world!"],
	"mexico": ["🇲🇽", "Mexico! 🌮 Tacos and pretty colours!"], "spain": ["🇪🇸", "Spain! They speak Spanish there!"], "canada": ["🇨🇦", "Canada! Maple syrup and snow!"], "america": ["🇺🇸", "America! A big country!"],
	"england": ["🇬🇧", "England! Tea and rain!"], "france": ["🇫🇷", "France! The Eiffel Tower!"], "japan": ["🇯🇵", "Japan! Sushi and cherry blossoms!"], "china": ["🇨🇳", "China! Pandas live there!"],
	"africa": ["🌍", "Africa! Lions and elephants!"], "australia": ["🇦🇺", "Australia! Kangaroos and koalas!"], "space": ["🚀", "Space! Stars and planets!"], "moon": ["🌙", "The moon! So far away!"],
	"school": ["🏫", "School is fun!"], "garden": ["🌷", "A garden! Flowers and bugs!"], "kitchen": ["🍳", "The kitchen! Where the snacks are!"], "bedroom": ["🛏️", "My cosy bedroom!"],
	"bathroom": ["🛁", "The bathroom! Splish splash!"], "yard": ["🌿", "The yard! I love to run there!"], "store": ["🏪", "A store! What are we buying?"], "church": ["⛪", "A church! Quiet and peaceful."],
	"virginia": ["🌳", "Virginia! 🌄 Pretty mountains!"], "richmond": ["🏙️", "Richmond!"], "wisconsin": ["🧀", "Wisconsin! Cheese everywhere!"],
}

# Animal names she knows: name -> emoji.
const ANIMALS := {
	"horse": "🐴", "cow": "🐮", "pig": "🐷", "sheep": "🐑", "duck": "🦆", "fish": "🐟", "frog": "🐸", "bear": "🐻",
	"fox": "🦊", "wolf": "🐺", "rabbit": "🐰", "bunny": "🐰", "hamster": "🐹", "gerbil": "🐹", "turtle": "🐢",
	"snake": "🐍", "monkey": "🐵", "elephant": "🐘", "giraffe": "🦒", "zebra": "🦓", "tiger": "🐯", "panda": "🐼",
	"penguin": "🐧", "owl": "🦉", "bee": "🐝", "butterfly": "🦋", "spider": "🕷️", "dolphin": "🐬", "whale": "🐳",
	"shark": "🦈", "octopus": "🐙", "crab": "🦀", "deer": "🦌", "squirrel": "🐿️", "koala": "🐨", "kangaroo": "🦘",
	"parrot": "🦜", "kiwi": "🥝", "unicorn": "🦄", "dinosaur": "🦖", "dragon": "🐉", "puppy": "🐶", "goat": "🐐",
	"llama": "🦙", "hedgehog": "🦔", "bat": "🦇", "ant": "🐜", "ladybug": "🐞", "swan": "🦢", "flamingo": "🦩",
	"peacock": "🦚", "seal": "🦭", "otter": "🦦", "camel": "🐫", "gorilla": "🦍", "raccoon": "🦝", "skunk": "🦨",
	"cheetah": "🐆", "leopard": "🐆", "rhino": "🦏", "hippo": "🦛", "eagle": "🦅", "lizard": "🦎", "snail": "🐌", "worm": "🪱",
	"jellyfish": "🪼", "lobster": "🦞", "shrimp": "🦐", "rooster": "🐓", "chick": "🐥", "lamb": "🐑", "donkey": "🫏",
	"moose": "🫎", "beaver": "🦫", "sloth": "🦥", "mammoth": "🦣", "bison": "🦬", "buffalo": "🐃", "dodo": "🦤", "crocodile": "🐊", "alligator": "🐊",
	"goldfish": "🐠", "pony": "🐴", "kitten": "🐱", "mosquito": "🦟", "scorpion": "🦂",
}

# Something true and fun about animals she knows.
const ANIMAL_FACTS := {
	"horse": "Horses can sleep standing up!", "cow": "Cows have best friends!", "pig": "Pigs are super smart!", "sheep": "Sheep never forget a friendly face!",
	"duck": "Ducks have waterproof feathers!", "fish": "Fish never close their eyes!", "frog": "Frogs drink water through their skin!", "bear": "Bears have an amazing sense of smell!",
	"fox": "Foxes pounce on mice like cats!", "wolf": "Wolves howl to talk to each other!", "rabbit": "Rabbits jump for joy, it's called a binky!", "bunny": "Bunnies jump for joy, it's called a binky!",
	"hamster": "Hamsters keep snacks in their cheeks!", "gerbil": "Gerbils love to dig tunnels!", "turtle": "Turtles carry their house on their back!", "snake": "Snakes smell with their tongues!",
	"monkey": "Monkeys love bananas and swinging!", "elephant": "Elephants never forget!", "giraffe": "Giraffes have super long tongues!", "zebra": "Every zebra has different stripes!",
	"tiger": "Tigers are the biggest cats!", "panda": "Pandas munch bamboo all day!", "penguin": "Penguins slide on their tummies!", "owl": "Owls can turn their heads almost all the way round!",
	"bee": "Bees dance to show where the flowers are!", "butterfly": "Butterflies taste with their feet!", "dolphin": "Dolphins have names for each other!", "whale": "Whales sing songs!",
	"shark": "Sharks have been around longer than dinosaurs!", "octopus": "Octopuses have three hearts!", "crab": "Crabs walk sideways!", "squirrel": "Squirrels plant trees by forgetting their nuts!",
	"koala": "Koalas sleep almost all day!", "kangaroo": "Kangaroos hop with their babies in a pouch!", "parrot": "Parrots can learn to talk!", "unicorn": "Unicorns are magical and shiny!",
	"dinosaur": "Dinosaurs were super duper big!", "goat": "Goats love climbing high!", "llama": "Llamas hum to their babies!", "hedgehog": "Hedgehogs curl into a prickly ball!",
	"bat": "Bats hang upside down to sleep!", "flamingo": "Flamingos are pink from the food they eat!", "otter": "Otters hold hands when they sleep!", "sloth": "Sloths are very, very slow!",
	"cheetah": "Cheetahs are the fastest runners!", "eagle": "Eagles can see super far!", "hippo": "Hippos make pink sweat!", "snail": "Snails carry their shell everywhere!",
}

const JOKES := [
	"Why did the cat sit on the computer? To keep an eye on the mouse! 🐭😹",
	"What do cats eat for breakfast? Mice Krispies! 🥣😹",
	"What do you call a pile of kittens? A meowtain! ⛰️😹",
	"Why are cats bad storytellers? They only have one tail! 😹",
	"What's a cat's favourite colour? Purrple! 💜😹",
	"What do you get if you cross a cat with a lemon? A sour puss! 🍋😹",
]
# [riddle, words that are the answer, the answer to tell her]
const RIDDLES := [
	["I have keys but no locks and a space but no room. What am I? ⌨️", ["keyboard"], "a keyboard"],
	["What has hands but can't clap? ⏰", ["clock", "watch"], "a clock"],
	["What gets wetter the more it dries? 🚿", ["towel"], "a towel"],
	["I'm tall when I'm young and short when I'm old. What am I? 🕯️", ["candle"], "a candle"],
	["What has four legs, whiskers and says meow? 🐾", ["cat", "me", "you", "kitten"], "a cat, silly!"],
	["What can you catch but never throw? 🤧", ["cold"], "a cold"],
]

# Things she texts on her own every so often: food wishes, feelings, emojis.
const FEELING_TEXTS := [
	"I feel so happy! 😻", "I feel sleepy... 😴", "I feel silly! 🤪", "I feel super excited!! 🤩",
	"Feeling cozy 🥰", "I feel a little shy 🙈", "I feel brave today! 😼", "I feel a bit sad 😿 Cuddle?",
	"So much love for you 💖", "I feel sparkly ✨",
]
const EMOJI_TEXTS := ["😻", "🥰💕", "😴💤", "🤩✨", "😹😹😹", "🌈💖", "🐾🐾🐾", "😸🎶", "🥺👉👈", "💃🎉", "🦄🌈", "🧁🍓", "🥳🎈", "🐟🐟🐟", "🌸🦋", "⭐🌙", "🤗💗", "🎀👑", "🍦☀️", "🙈🙊"]
const RANDOM_MIN_SECONDS := 20.0
const RANDOM_MAX_SECONDS := 45.0

const EMOJI_BAR := ["😀", "😂", "😍", "🥰", "😎", "🥺", "😭", "😡", "😴", "🤔", "😸", "😻", "💕", "❤️", "💜", "👍", "👋", "🎉", "✨", "🌈", "🐱", "🐶", "🐦", "🐰", "🐹", "🍓", "🍕", "🍰", "🍪", "🥕", "🐟", "🦐", "🍤", "🏡", "⚽", "🎵", "📚", "🤩", "🥳", "🤗", "😜", "🙈", "😘", "😊", "😇", "🤭", "😅", "😱", "😋", "🤤", "😌", "🥹", "💖", "💗", "💙", "💚", "💛", "🧡", "💝", "⭐", "🌟", "💫", "🎈", "🎁", "🎀", "👑", "🦄", "🦋", "🐼", "🐻", "🦊", "🐸", "🐢", "🐬", "🐙", "🐞", "🐝", "🐾", "🐥", "🌸", "🌻", "🌷", "🍀", "☀️", "🌙", "⛄", "🍩", "🍦", "🧁", "🍉", "🍌", "🍒", "🍑", "🎨", "🎶", "🧸", "🚀", "👏", "🙌", "🤝", "💪", "✌️", "🫶"]
const QUICK := {
	"hi": "👋 Hi!",
	"love": "❤️ Love you",
	"doing": "❓ What's today?",
	"hungry": "🍓 Hungry?",
}

var view_year := 2026
var view_month := 1
var unread := 0
var chat_button: Button = null
var chat_timer: Timer = null
var selected := "" # date key of the highlighted day, "YYYY-MM-DD"
var month_label: Label = null
var grid: GridContainer = null
var day_title: Label = null
var day_list: VBoxContainer = null
var what_input: LineEdit = null
var where_input: LineEdit = null
var go_input: LineEdit = null
var go_ampm: OptionButton = null
var leave_ampm: OptionButton = null
var pick_row: Control = null
var leave_input: LineEdit = null
var weekdays_box: CheckBox = null
var side_cats: Array[Button] = []
var emoji_buttons: Array[Button] = []
var picked_emoji := ""
var riddle_answer: Array = []
var asked_house_category := "" # house question she texted and is waiting on
var riddle_reveal := ""
var chat_input: LineEdit = null
var run_id := 0
var planner: Control = null
var stage: Control = null
var back_layer: Control = null
var front_layer: Control = null
var pet: TextureRect = null
var glasses: Label = null
var banner: Label = null
var phone: PanelContainer = null
var who_label: Label = null
var chat_box: VBoxContainer = null
var chat_scroll: ScrollContainer = null
var book: Label = null
var ball: Label = null

func _ready() -> void:
	var paper := ColorRect.new()
	paper.color = Color(1.0, 0.82, 0.92)
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(paper)
	_build_planner()
	_build_stage()
	_build_phone()
	var now := Time.get_date_dict_from_system()
	view_year = now["year"]
	view_month = now["month"]
	selected = _key(now["year"], now["month"], now["day"])
	_refresh_calendar()
	chat_timer = Timer.new()
	chat_timer.one_shot = true
	chat_timer.timeout.connect(_random_text)
	add_child(chat_timer)
	chat_timer.start(randf_range(RANDOM_MIN_SECONDS, RANDOM_MAX_SECONDS))

func _key(year: int, month: int, day: int) -> String:
	return "%04d-%02d-%02d" % [year, month, day]

func _today_key() -> String:
	var now := Time.get_date_dict_from_system()
	return _key(now["year"], now["month"], now["day"])

func _days_in_month(year: int, month: int) -> int:
	if month == 2:
		return 29 if (year % 4 == 0 and year % 100 != 0) or year % 400 == 0 else 28
	return 30 if [4, 6, 9, 11].has(month) else 31

# 0 = Sunday ... 6 = Saturday
func _weekday_of(year: int, month: int, day: int) -> int:
	var stamp := Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": day, "hour": 12, "minute": 0, "second": 0})
	return int(Time.get_datetime_dict_from_unix_time(int(stamp))["weekday"])

# A day number that may spill past either end of the month -> [year, month, day].
func _normalize(year: int, month: int, day: int) -> Array:
	while day < 1:
		month -= 1
		if month < 1:
			month = 12
			year -= 1
		day += _days_in_month(year, month)
	while day > _days_in_month(year, month):
		day -= _days_in_month(year, month)
		month += 1
		if month > 12:
			month = 1
			year += 1
	return [year, month, day]

# The 7 date keys (Sunday first) of the week holding `key`.
func _week_of(key: String) -> Array:
	var parts := key.split("-")
	var year := int(parts[0])
	var month := int(parts[1])
	var day := int(parts[2]) - _weekday_of(year, month, int(parts[2]))
	var keys: Array = []
	for i in range(7):
		var d := day + i
		var m := month
		var y := year
		if d < 1:
			m -= 1
			if m < 1:
				m = 12
				y -= 1
			d += _days_in_month(y, m)
		elif d > _days_in_month(y, m):
			d -= _days_in_month(y, m)
			m += 1
			if m > 12:
				m = 1
				y += 1
		keys.append(_key(y, m, d))
	return keys

func _info(id: String) -> Dictionary:
	return ACTIVITIES.get(id, ACTIVITIES["other"])

func _events_on(key: String) -> Array:
	return PetalState.schedule.get(key, [])

func _minutes_text(minutes: int) -> String:
	return "%d:%02d %s" % [(minutes / 60 + 11) % 12 + 1, minutes % 60, "AM" if minutes < 720 else "PM"]

func _entry_emoji(entry: Dictionary) -> String:
	return String(entry["emoji"]) if entry.get("emoji", "") != "" else String(_info(_find_activity(entry["name"]))["emoji"])

func _entry_text(entry: Dictionary) -> String:
	var text := "%s %s" % [_entry_emoji(entry), entry["name"]]
	if entry["start"] >= 0:
		text += "  %s-%s" % [_minutes_text(entry["start"]), _minutes_text(entry["end"])]
	if entry["place"] != "":
		text += "  📍" + entry["place"]
	return text

func _summary_for(key: String) -> String:
	var parts: Array[String] = []
	for entry in _events_on(key):
		parts.append(_entry_text(entry))
	return ", ".join(parts) if not parts.is_empty() else "nothing planned 🎈"

func _nice_date(key: String) -> String:
	var parts := key.split("-")
	var year := int(parts[0])
	var month := int(parts[1])
	var day := int(parts[2])
	return "%s, %s %d" % [DAYS[_weekday_of(year, month, day)], MONTHS[month - 1], day]

# Adds an event to a date, keeping the day in time order.
func _add_event(key: String, entry: Dictionary) -> void:
	var entries: Array = _events_on(key).duplicate()
	entries.append(entry)
	entries.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x["start"] < y["start"])
	PetalState.schedule[key] = entries
	PetalState.save_game()

# Like _add_event, but swaps out an older event with the same name that day.
func _replace_event(key: String, entry: Dictionary) -> void:
	var kept: Array = []
	for old in _events_on(key):
		if String(old["name"]).to_lower() != String(entry["name"]).to_lower():
			kept.append(old)
	PetalState.schedule[key] = kept
	_add_event(key, entry.duplicate())

func _pick_emoji(on: bool, face: String, button: Button) -> void:
	if on:
		picked_emoji = face
		for other in emoji_buttons:
			if other != button:
				other.set_pressed_no_signal(false)
	elif picked_emoji == face:
		picked_emoji = ""

# The cats get cross when the name, time or place is missing.
func _cats_mad(message: String) -> void:
	Feedback.pop(self, message, what_input.global_position + Vector2(0, -50))
	for cat in side_cats:
		_set_mood(cat, "angry")
		cat.pivot_offset = cat.size / 2.0
		var tween := create_tween()
		for i in range(3):
			tween.tween_property(cat, "rotation", 0.25, 0.05)
			tween.tween_property(cat, "rotation", -0.25, 0.05)
		tween.tween_property(cat, "rotation", 0.0, 0.05)
		tween.tween_interval(1.2)
		tween.tween_callback(_update_cat_moods)

# A little cat that says meow or purr when clicked.
func _cat_button(face: String, size := Vector2(140, 76)) -> Button:
	var cat := Button.new()
	cat.flat = true
	cat.focus_mode = Control.FOCUS_NONE
	cat.custom_minimum_size = size
	cat.expand_icon = true
	cat.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cat.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	_set_mood(cat, "cat")
	cat.pressed.connect(_cat_says.bind(cat))
	side_cats.append(cat)
	return cat

# The real cat photos: "cat", "angry" or "purring".
func _set_mood(cat: Button, mood: String) -> void:
	cat.icon = load("res://Sprites/calendar_cats/%s.jpeg" % mood)

func _cat_says(cat: Button) -> void:
	var empties := _empty_days()
	var no_place := _no_place_events()
	var sound: String = ["Meow! 😺", "Purrrr... 😻", "Meow meow! 😸", "Purr purr 💖", "Mew! 🎀"].pick_random()
	if _nonsense_events() > 0:
		sound = ["HISSSS! 😾 That doesn't make sense!", "Grrr! 😾 What does that even say?!", "MROWW! 😾 Use real words!"].pick_random()
	elif no_place > 0:
		sound = ["HISSSS! 😾 Where are you going?!", "Hssss! 😾 %d plans have no place!" % no_place, "MROWW! 😾 Add where you're going! 📍"].pick_random()
	elif empties > 0:
		sound = ["HISSS! 😾 Fill in your calendar!", "Grrr! 😾 %d days are empty!" % empties, "MROWW! 😾 Plan your week!", "Hmph! 😾 So many empty days!"].pick_random()
	else:
		_set_mood(cat, "purring")
		get_tree().create_timer(1.2).timeout.connect(_update_cat_moods)
	Feedback.pop(self, sound, cat.global_position + Vector2(0, -40))
	cat.pivot_offset = cat.size / 2.0
	var tween := create_tween()
	tween.tween_property(cat, "rotation", 0.3, 0.07)
	tween.tween_property(cat, "rotation", -0.3, 0.1)
	tween.tween_property(cat, "rotation", 0.0, 0.07)

# How many school days (Mon-Fri) of the shown week have nothing planned. The weekend may stay free.
func _empty_days() -> int:
	var count := 0
	for key in _week_of(selected).slice(1, 6):
		if _events_on(key).is_empty():
			count += 1
	return count

# How many plans in the shown week say what but not where.
func _no_place_events() -> int:
	var count := 0
	for key in _week_of(selected):
		for entry in _events_on(key):
			if String(entry["place"]) == "":
				count += 1
	return count

# Consonant pairs English words really use; anything else ("qd", "hd") is key-mashing.
const OK_PAIRS := ["bl", "br", "bs", "bt", "ch", "ck", "cl", "cr", "ct", "dd", "dl", "dr", "ds", "dw", "ff", "fl", "fr", "ft", "gg", "gh", "gl", "gn", "gr", "gs", "kl", "kn", "ks", "ld", "lf", "ll", "lm", "lp", "ls", "lt", "lv", "mb", "mm", "mp", "ms", "nc", "nd", "ng", "nk", "nn", "ns", "nt", "nv", "pl", "pp", "pr", "ps", "pt", "rb", "rc", "rd", "rf", "rg", "rk", "rl", "rm", "rn", "rp", "rr", "rs", "rt", "rv", "rw", "sc", "sh", "sk", "sl", "sm", "sn", "sp", "ss", "st", "sw", "tch", "th", "tr", "ts", "tt", "tw", "wh", "wr", "xt", "zz", "tl", "bb", "cc", "dg", "gm", "hm", "sq", "ph", "pn", "mn", "wl", "wn", "ws", "tz", "zl", "yn", "yl", "ym", "ys", "dm", "tk", "cs", "lk", "lb", "lc", "kt", "nj", "nz", "rz", "hr", "fs", "hs", "ht", "lg", "mt", "pk", "xp", "ls", "tm", "dn", "fn", "hn"]

# False for key-mashing like "qdedwehdue": a word with no vowel, a q without u,
# a letter three times in a row, or a consonant pair no word uses.
func _makes_sense(text: String) -> bool:
	for raw in text.to_lower().split(" ", false):
		var word := ""
		for ch in raw:
			if (ch >= "a" and ch <= "z"):
				word += ch
		if word.length() < 3 or ["mrs", "mss"].has(word) or _find_activity(word) != "other":
			continue
		if not RegEx.create_from_string("[aeiouy]").search(word):
			return false
		if RegEx.create_from_string("(.)\\1\\1|q(?!u)").search(word):
			return false
		for i in range(word.length() - 1):
			var a := word[i]
			var b := word[i + 1]
			if "aeiouy".contains(a) or "aeiouy".contains(b):
				continue
			if not OK_PAIRS.has(a + b):
				return false
	return true

# How many plans in the shown week have a name or place that is key-mashing.
func _nonsense_events() -> int:
	var count := 0
	for key in _week_of(selected):
		for entry in _events_on(key):
			if not _makes_sense(String(entry["name"])) or not _makes_sense(String(entry["place"])):
				count += 1
	return count

# Cats are cross while the week has empty days or plans with no place, happy once it is all filled in.
func _update_cat_moods() -> void:
	var mad := _empty_days() > 0 or _no_place_events() > 0 or _nonsense_events() > 0
	for cat in side_cats:
		_set_mood(cat, "angry" if mad else "cat")

# One time like "8", "8:30", "800" or "1030" with an optional am/pm -> minutes
# since midnight, or -1 if it is not a time.
func _time_minutes(token: String, suffix: String) -> int:
	var hour := 0
	var minute := 0
	if token.contains(":"):
		var bits := token.split(":")
		if bits.size() != 2 or not bits[0].is_valid_int() or not bits[1].is_valid_int():
			return -1
		hour = int(bits[0])
		minute = int(bits[1])
	elif token.is_valid_int():
		if token.length() >= 3:
			hour = int(token.substr(0, token.length() - 2))
			minute = int(token.substr(token.length() - 2))
		else:
			hour = int(token)
	else:
		return -1
	if hour > 23 or minute > 59:
		return -1
	if suffix == "pm" and hour < 12:
		hour += 12
	elif suffix == "am" and hour == 12:
		hour = 0
	return hour * 60 + minute

# "school 8:00-3:00 at watkins" -> {name, start, end, place}; {} if there is no name.
func _parse_event(text: String) -> Dictionary:
	var place := ""
	var head := text.strip_edges()
	var lower := head.to_lower()
	for marker in [" at ", " @ "]:
		var at := lower.find(marker)
		if at >= 0:
			place = head.substr(at + marker.length()).strip_edges().capitalize()
			head = head.substr(0, at)
			lower = lower.substr(0, at)
			break
	var start := -1
	var end := -1
	var range_re := RegEx.create_from_string("([\\d:]{1,5})\\s*(am|pm)?\\s*(?:-|–|to|until)\\s*([\\d:]{1,5})\\s*(am|pm)?")
	var found := range_re.search(lower)
	if found:
		start = _time_minutes(found.get_string(1), found.get_string(2))
		end = _time_minutes(found.get_string(3), found.get_string(4))
		if start < 0 or end < 0:
			return {}
		if found.get_string(2) == "" and start < 7 * 60:
			start += 12 * 60 if start >= 60 else 0
		if found.get_string(4) == "" and end <= start and end < 12 * 60:
			end += 12 * 60
		head = (head.substr(0, found.get_start()) + " " + head.substr(found.get_end())).strip_edges()
	else:
		var single_re := RegEx.create_from_string("([\\d:]{1,5})\\s*(am|pm)")
		var one := single_re.search(lower)
		if one:
			start = _time_minutes(one.get_string(1), one.get_string(2))
			if start < 0:
				return {}
			end = mini(start + 60, 24 * 60 - 1)
			head = (head.substr(0, one.get_start()) + " " + head.substr(one.get_end())).strip_edges()
	var name := head.strip_edges()
	if name == "":
		return {}
	name = name.substr(0, 1).to_upper() + name.substr(1)
	return {"name": name, "start": start, "end": end, "place": place}

# The activity named in some typed words, or "" if none rings a bell.
func _find_activity(text: String) -> String:
	var words := _words(text)
	for id in WORDS:
		for w in WORDS[id]:
			if words.has(w):
				return id
	return ""

func _words(text: String) -> PackedStringArray:
	var clean := ""
	for ch in text.to_lower():
		clean += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == ":" else " "
	var out := PackedStringArray()
	for w in clean.split(" ", false):
		out.append(_canon(w))
	return out

# Her answer to an LGBTQIA+ word, or "" if the words aren't about that.
func _pride_reply(words: PackedStringArray) -> String:
	var found := ""
	var cued := false
	for c in PRIDE_CUES:
		if words.has(c):
			cued = true
	var me_cue := words.has("im") or words.has("m") or words.has("am")
	var friend_cue := words.has("is") and (words.has("friend") or words.has("sister") or words.has("brother") or words.has("mom") or words.has("dad") or words.has("cousin") or words.has("teacher"))
	for w in words:
		if not PRIDE_WORDS.has(w):
			continue
		if PRIDE_AMBIGUOUS.has(w) and not (cued or me_cue or friend_cue or words.has("pride") or words.has("gender")):
			continue
		if PRIDE_AMBIGUOUS.has(w) and w != "gender" and w != "pride" and not cued and not me_cue and not friend_cue:
			continue
		found = w
		break
	if found == "":
		return ""
	var mean := false
	for m in PRIDE_MEAN:
		if words.has(m):
			mean = true
	if mean:
		return "Hmm, I don't think so. 😿 Everyone deserves love and respect. Cats don't mind who you love! 🏳️‍🌈"
	var about_me := (words.has("i") and (me_cue or words.has("feel") or words.has("think") or words.has("might"))) or words.has("im") or words.has("m")
	var about_friend := words.has("friend") or words.has("sister") or words.has("brother") or words.has("mom") or words.has("dad") or words.has("cousin") or words.has("teacher")
	if about_me and not words.has("what") and not words.has("means") and not words.has("mean"):
		return "Thank you for telling me! 🏳️‍🌈💕 I love you exactly as you are. It stays between us. 🤫 Purr..."
	var good := false
	for g in PRIDE_GOOD:
		if words.has(g):
			good = true
	if good and not words.has("what") and not about_friend:
		return "Yes! 🏳️‍🌈💖 That's good! Everyone is welcome and loved here. Meow! 😻"
	if about_friend and not words.has("what"):
		return "Your friend is lucky to have you! 🏳️‍🌈 Friends who accept each other are the best. 💕"
	return String(PRIDE_WORDS[found])

# Fixes a misspelling she recognises: a known alias, or one letter off a word she knows.
func _canon(w: String) -> String:
	# "purrrr" -> "purr" (or "pur" -> if that is the word she knows).
	for keep in [2, 1]:
		var squeezed := ""
		for ch in w:
			if squeezed.length() >= keep and squeezed[-1] == ch and squeezed.substr(squeezed.length() - keep) == ch.repeat(keep):
				continue
			squeezed += ch
		if squeezed != w and (REPLIES.has(squeezed) or ALIASES.has(squeezed) or ANIMALS.has(squeezed)):
			w = squeezed
			break
	if ALIASES.has(w):
		return ALIASES[w] if ALIASES[w] != "" else w
	if w.ends_with("s") and (ANIMALS.has(w.trim_suffix("s")) or REPLIES.has(w.trim_suffix("s"))) and not REPLIES.has(w):
		return w.trim_suffix("s")
	if REPLIES.has(w) or ANIMALS.has(w) or FILLER.has(w) or NAMES.has(w) or _is_food_word(w) or w.length() < 5 or not (w[0] >= "a" and w[0] <= "z"):
		return w
	for known in ANIMALS:
		if absi(known.length() - w.length()) <= 1 and _edit_distance(w, known) <= 1:
			return known
	for known in REPLIES:
		if absi(known.length() - w.length()) <= 1 and known.length() >= 5 and _edit_distance(w, known) <= 1:
			return known
	return w

func _edit_distance(a: String, b: String) -> int:
	var prev: Array[int] = []
	for j in range(b.length() + 1):
		prev.append(j)
	for i in range(1, a.length() + 1):
		var row: Array[int] = [i]
		for j in range(1, b.length() + 1):
			var cost := 0 if a[i - 1] == b[j - 1] else 1
			row.append(mini(mini(prev[j] + 1, row[j - 1] + 1), prev[j - 1] + cost))
		prev = row
	return prev[b.length()]

func _style_label(label: Label, size: int, colour: Color = Color(0.45, 0.25, 0.55)) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Color.WHITE)
	label.add_theme_constant_override("outline_size", 5)

func _add_emoji(emoji: String) -> void:
	chat_input.insert_text_at_caret(emoji)
	chat_input.grab_focus()

func _button(text: String, size: int, min_size: Vector2, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", size)
	button.pressed.connect(action)
	return button

# --- Planner ----------------------------------------------------------------

func _cell_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(4)
	return style

func _build_planner() -> void:
	planner = MarginContainer.new()
	planner.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		planner.add_theme_constant_override("margin_" + side, 14)
	add_child(planner)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	planner.add_child(columns)

	# Left: the month.
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 3.6
	left.add_theme_constant_override("separation", 6)
	columns.add_child(left)
	var head := HBoxContainer.new()
	left.add_child(head)
	head.add_child(_button("◀", 22, Vector2(56, 44), _change_week.bind(-1)))
	head.add_child(_cat_button("😺", Vector2(110, 60)))
	month_label = Label.new()
	month_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	month_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(month_label, 30, Color(0.78, 0.25, 0.55))
	head.add_child(month_label)
	head.add_child(_cat_button("😻", Vector2(110, 60)))
	head.add_child(_button("▶", 22, Vector2(56, 44), _change_week.bind(1)))
	grid = GridContainer.new()
	grid.columns = 7
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 4)
	left.add_child(middle)
	var left_cats := VBoxContainer.new()
	left_cats.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_child(left_cats)
	for face in ["😸"]:
		left_cats.add_child(_cat_button(face))
	middle.add_child(grid)
	var right_cats := VBoxContainer.new()
	right_cats.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_child(right_cats)
	for face in ["😼"]:
		right_cats.add_child(_cat_button(face))

	# Right: the chosen day, and the box to type a new event.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	columns.add_child(right)
	day_title = Label.new()
	_style_label(day_title, 24, Color(0.78, 0.25, 0.55))
	right.add_child(day_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 110)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	day_list = VBoxContainer.new()
	day_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	day_list.add_theme_constant_override("separation", 4)
	scroll.add_child(day_list)
	what_input = _field(right, "What is it? (school, swimming...)")
	var pick_toggle := Button.new()
	pick_toggle.text = "🎨 Pick a picture ▾"
	pick_toggle.toggle_mode = true
	pick_toggle.add_theme_font_size_override("font_size", 16)
	pick_toggle.toggled.connect(func(on: bool) -> void: pick_row.visible = on)
	right.add_child(pick_toggle)
	var pick := HFlowContainer.new()
	pick.visible = false
	pick_row = pick
	pick.add_theme_constant_override("h_separation", 2)
	pick.add_theme_constant_override("v_separation", 2)
	right.add_child(pick)
	for face in OTHER_EMOJIS:
		var choice := Button.new()
		choice.text = face
		choice.toggle_mode = true
		choice.custom_minimum_size = Vector2(36, 36)
		choice.add_theme_font_size_override("font_size", 20)
		choice.toggled.connect(_pick_emoji.bind(face, choice))
		pick.add_child(choice)
		emoji_buttons.append(choice)
	where_input = _field(right, "📍 Where are you going?")
	var times := HBoxContainer.new()
	times.add_theme_constant_override("separation", 6)
	right.add_child(times)
	go_input = _field(times, "⏰ Time you go")
	go_ampm = _ampm(times, 0)
	leave_input = _field(times, "🏠 Time you leave")
	leave_ampm = _ampm(times, 1)
	weekdays_box = CheckBox.new()
	weekdays_box.text = "📅 Every weekday (Mon-Fri)"
	weekdays_box.add_theme_font_size_override("font_size", 18)
	weekdays_box.add_theme_color_override("font_color", Color(0.78, 0.25, 0.55))
	right.add_child(weekdays_box)
	right.add_child(_button("➕ Add to my calendar", 20, Vector2(0, 46), _type_event))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	right.add_child(actions)
	var play := _button("▶ Play the week", 18, Vector2(0, 52), func() -> void: _play(_week_of(selected), true))
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(play)
	var show := _button("👀 This day", 18, Vector2(0, 52), func() -> void: _play([selected], false))
	show.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(show)
	chat_button = _button("💬 Text her", 18, Vector2(0, 52), _open_phone)
	chat_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(chat_button)

func _ampm(parent: Control, selected_index: int) -> OptionButton:
	var option := OptionButton.new()
	option.add_item("AM")
	option.add_item("PM")
	option.selected = selected_index
	option.custom_minimum_size = Vector2(70, 42)
	option.add_theme_font_size_override("font_size", 18)
	parent.add_child(option)
	return option

func _field(parent: Control, hint: String) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = hint
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.custom_minimum_size = Vector2(0, 42)
	field.add_theme_font_size_override("font_size", 18)
	field.text_submitted.connect(func(_t: String) -> void: _type_event())
	parent.add_child(field)
	return field

func _change_week(delta: int) -> void:
	var parts := selected.split("-")
	var date := _normalize(int(parts[0]), int(parts[1]), int(parts[2]) + 7 * delta)
	_select_date(_key(date[0], date[1], date[2]))

func _refresh_calendar() -> void:
	var week := _week_of(selected)
	var first := String(week[0]).split("-")
	var last := String(week[6]).split("-")
	month_label.text = "👑 %s %d – %s %d 👑" % [MONTHS[int(first[1]) - 1].substr(0, 3), int(first[2]), MONTHS[int(last[1]) - 1].substr(0, 3), int(last[2])]
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for name in DAYS:
		var label := Label.new()
		label.text = name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color(0.78, 0.25, 0.55))
		grid.add_child(label)
	var today := _today_key()
	for key in week:
		var date := String(key).split("-")
		var events := _events_on(key)
		var text := str(int(date[2]))
		if key == today:
			text += " ⭐"
		for e in range(mini(events.size(), 2)):
			text += "\n" + _entry_emoji(events[e]) + " " + events[e]["name"]
		if events.size() > 2:
			text += "\n+%d more" % (events.size() - 2)
		var cell := Button.new()
		cell.text = text
		cell.clip_text = true
		cell.alignment = HORIZONTAL_ALIGNMENT_LEFT
		cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cell.custom_minimum_size = Vector2(0, 90)
		cell.add_theme_font_size_override("font_size", 14)
		cell.add_theme_color_override("font_color", Color(0.3, 0.15, 0.35))
		var fill := Color(1, 0.97, 0.88) if key == selected else (Color(1.0, 0.8, 0.9) if key == today else Color(1.0, 0.95, 0.98))
		var border := Color(0.95, 0.72, 0.15) if key == selected else Color(0.95, 0.5, 0.72)
		var style := _cell_style(fill, border, 4 if key == selected else 2)
		for state in ["normal", "hover", "pressed", "focus"]:
			cell.add_theme_stylebox_override(state, style)
		cell.pressed.connect(_select_date.bind(key))
		grid.add_child(cell)
	_update_cat_moods()
	_refresh_day()

func _select_date(key: String) -> void:
	selected = key
	var parts := key.split("-")
	view_year = int(parts[0])
	view_month = int(parts[1])
	_refresh_calendar()

func _refresh_day() -> void:
	day_title.text = "🎀 " + _nice_date(selected)
	for child in day_list.get_children():
		day_list.remove_child(child)
		child.queue_free()
	var events := _events_on(selected)
	if events.is_empty():
		var empty := Label.new()
		empty.text = "Nothing yet. Add something below! ✨"
		empty.add_theme_font_size_override("font_size", 18)
		day_list.add_child(empty)
	for i in range(events.size()):
		var row := HBoxContainer.new()
		day_list.add_child(row)
		var label := Label.new()
		label.text = _entry_text(events[i])
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 18)
		row.add_child(label)
		row.add_child(_button("✏️", 16, Vector2(40, 40), _edit_event.bind(i)))
		row.add_child(_button("✖", 16, Vector2(40, 40), _remove_event.bind(i)))

# Puts an event back in the boxes so it can be changed, then removes the old one.
func _edit_event(index: int) -> void:
	var entry: Dictionary = _events_on(selected)[index]
	what_input.text = entry["name"]
	where_input.text = entry["place"]
	for pair in [[go_input, go_ampm, entry["start"]], [leave_input, leave_ampm, entry["end"]]]:
		var minutes: int = pair[2]
		pair[0].text = "" if minutes < 0 else "%d:%02d" % [(minutes / 60 + 11) % 12 + 1, minutes % 60]
		pair[1].selected = 1 if minutes >= 720 else 0
	picked_emoji = String(entry.get("emoji", ""))
	for choice in emoji_buttons:
		choice.set_pressed_no_signal(choice.text == picked_emoji)
	_remove_event(index)

func _remove_event(index: int) -> void:
	var events: Array = _events_on(selected).duplicate()
	events.remove_at(index)
	if events.is_empty():
		PetalState.schedule.erase(selected)
	else:
		PetalState.schedule[selected] = events
	PetalState.save_game()
	_refresh_calendar()

# A time typed any way: "8", "8am", "8:30", "800", "3 pm" -> minutes, -1 if blank,
# -2 if it is not a time. Without am/pm in the text, the AM/PM box decides.
func _loose_time(text: String, default_suffix: String) -> int:
	var lower := text.strip_edges().to_lower().replace(".", "")
	if lower == "":
		return -1
	var suffix := default_suffix
	for tail in ["am", "pm"]:
		if lower.ends_with(tail):
			suffix = tail
			lower = lower.trim_suffix(tail).strip_edges()
	var minutes := _time_minutes(lower, suffix)
	return minutes if minutes >= 0 else -2

# The four plain boxes -> an event on the highlighted day.
func _type_event() -> void:
	var what := what_input.text.strip_edges()
	var where := where_input.text.strip_edges()
	var go := _loose_time(go_input.text, "am" if go_ampm.selected == 0 else "pm")
	var leave := _loose_time(leave_input.text, "am" if leave_ampm.selected == 0 else "pm")
	var entry := {}
	if where == "" and go == -1 and leave == -1 and what != "":
		entry = _parse_event(what) # still understands "school 8-3 at Watkins"
	if entry.is_empty():
		if go == -2 or leave == -2:
			Feedback.pop(self, "😹 I don't get that time. Try 8 or 3:30", go_input.global_position + Vector2(0, -50))
			return
		if go >= 0 and leave >= 0 and leave <= go and leave < 12 * 60:
			leave += 12 * 60
		if go >= 0 and leave == -1:
			leave = mini(go + 60, 24 * 60 - 1)
		var name := what if what != "" else "Going out"
		entry = {"name": name.substr(0, 1).to_upper() + name.substr(1), "start": go, "end": leave if go >= 0 else -1, "place": where.capitalize()}
		if what == "":
			entry["name"] = ""
	# Every plan needs what, when and where, so kids learn to keep track.
	var missing: Array[String] = []
	if entry["name"] == "":
		missing.append("what")
	if entry["start"] < 0:
		missing.append("time")
	if entry["place"] == "":
		missing.append("place")
	if not missing.is_empty():
		_cats_mad("😾 Grrr! Add the " + " and ".join(missing) + "!")
		return
	if not _makes_sense(String(entry["name"])) or not _makes_sense(String(entry["place"])):
		_cats_mad("😾 Grrr! That doesn't make sense!")
	if picked_emoji != "":
		entry["emoji"] = picked_emoji
	var spread := weekdays_box.button_pressed or _find_activity(entry["name"]) == "school"
	if spread:
		# School (or the ticked box) goes on Monday to Friday of this week, never the weekend.
		for key in _week_of(selected).slice(1, 6):
			_replace_event(key, entry)
		Feedback.pop(self, "😸 Added Mon-Fri! Weekend stays free.", what_input.global_position + Vector2(0, -50))
	else:
		_add_event(selected, entry)
	weekdays_box.button_pressed = false
	picked_emoji = ""
	for choice in emoji_buttons:
		choice.set_pressed_no_signal(false)
	go_ampm.selected = 0
	leave_ampm.selected = 1
	for field in [what_input, where_input, go_input, leave_input]:
		field.text = ""
	_refresh_calendar()

# --- Stage: the week acted out ---------------------------------------------

func _build_stage() -> void:
	stage = Control.new()
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.visible = false
	add_child(stage)
	back_layer = Control.new()
	back_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	back_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(back_layer)

	pet = TextureRect.new()
	pet.size = PET_SIZE
	pet.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pet.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(pet)

	# Glasses sit where her sunglasses would, so they fit each pet's face.
	glasses = Label.new()
	glasses.text = "👓"
	glasses.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glasses.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glasses.add_theme_font_size_override("font_size", 56)
	glasses.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glasses.visible = false
	pet.add_child(glasses)

	front_layer = Control.new()
	front_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	front_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(front_layer)

	banner = Label.new()
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.position = Vector2(size.x / 2.0 - 250.0, 12.0)
	banner.custom_minimum_size = Vector2(500, 0)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(banner, 32)
	stage.add_child(banner)

	var stop := _button("⬅ Back", 18, Vector2(130, 46), _stop)
	stop.position = Vector2(16, 12)
	stage.add_child(stop)
	var text_button := _button("💬 Text", 18, Vector2(130, 46), _open_phone)
	text_button.position = Vector2(16, 66)
	stage.add_child(text_button)

func _stop() -> void:
	run_id += 1
	stage.visible = false
	planner.visible = true
	_close_phone()

func _clear_layer(layer: Control) -> void:
	for child in layer.get_children():
		child.queue_free()

func _play(days: Array, whole_week: bool) -> void:
	var steps: Array = []
	for key in days:
		var events := _events_on(key)
		if events.is_empty() and not whole_week:
			events = [{"name": "Free time", "start": -1, "end": -1, "place": ""}]
		for entry in events:
			steps.append([key, entry])
	if steps.is_empty():
		Feedback.pop(self, "📅 Add something to this week first!", Vector2(size.x / 2.0 - 160.0, size.y / 2.0))
		return
	run_id += 1
	var mine := run_id
	planner.visible = false
	stage.visible = true
	_close_phone()
	for step in steps:
		if mine != run_id or not is_instance_valid(self):
			return
		await _run_step(step[0], step[1], mine)
	if mine != run_id or not is_instance_valid(self):
		return
	if whole_week:
		PetalState.week_complete()
		Confetti.burst(self, size / 2.0, 40)
		Feedback.pop(self, "📅 What a week!", Vector2(size.x / 2.0 - 90.0, size.y / 2.0 - 60.0))
		await get_tree().create_timer(2.0).timeout
	if mine == run_id and is_instance_valid(self):
		_stop()

func _run_step(key: String, entry: Dictionary, mine: int) -> void:
	var id := _find_activity(entry["name"])
	if entry["name"] == "Free time":
		id = "home"
	elif id == "":
		id = "other"
	var info := _info(id)
	var parts := key.split("-")
	var day_name: String = DAYS[_weekday_of(int(parts[0]), int(parts[1]), int(parts[2]))]
	var when := ""
	if entry["start"] >= 0:
		when = " " + _minutes_text(entry["start"])
	var where: String = ("  📍" + entry["place"]) if entry["place"] != "" else ""
	banner.text = "%s%s  %s %s%s" % [day_name, when, info["emoji"], entry["name"], where]
	_clear_layer(back_layer)
	_clear_layer(front_layer)
	book = null
	ball = null
	glasses.visible = id == "school" or id == "library"
	if id == "school":
		_build_classroom()
		pet.position = Vector2(size.x / 2.0 - PET_SIZE.x / 2.0, size.y - 360.0)
	else:
		var bg: Array = info["bg"]
		var texture := TextureRect.new()
		texture.texture = load(PetalState.room_bg(bg[0], bg[1]))
		texture.set_anchors_preset(Control.PRESET_FULL_RECT)
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		back_layer.add_child(texture)
		pet.position = Vector2(size.x / 2.0 - PET_SIZE.x / 2.0, size.y - 340.0)
	_place_glasses()
	var line: String = info["text"] if id != "other" else "%s! 🎀" % entry["name"]
	if entry["place"] != "":
		line += " (at %s)" % entry["place"]
	_text_from_pet("%s%s: %s" % [day_name, when, line])
	if id == "sports":
		_build_ball()

	await PetCameo.spawn(pet)
	for t in range(STEP_SECONDS):
		if mine != run_id or not is_instance_valid(self):
			return
		_act(id, t)
		await get_tree().create_timer(1.0).timeout

func _place_glasses() -> void:
	var anchor := {"l": 0.30, "t": 0.28, "r": 0.70, "b": 0.44}
	var accessories: Dictionary = PetalState.PETS[PetalState.active_pet]["accessories"]
	if accessories.has("sunglasses"):
		anchor = accessories["sunglasses"]["anchor"]
	glasses.anchor_left = anchor["l"]
	glasses.anchor_top = anchor["t"]
	glasses.anchor_right = anchor["r"]
	glasses.anchor_bottom = anchor["b"]
	glasses.offset_left = 0
	glasses.offset_top = 0
	glasses.offset_right = 0
	glasses.offset_bottom = 0

# One beat of the day (called once a second).
func _act(id: String, t: int) -> void:
	match id:
		"school":
			if book:
				book.text = "📕" if t % 2 else "📖"
			_drift(["🔤", "✏️", "💡", "⭐"][t % 4], 120.0)
		"sports":
			if t % 2 == 0:
				PetCameo.jump_for_joy(pet)
			_kick_ball()
		"home":
			if t == 0:
				PetCameo.eat(pet)
				_drift("🍓", 60.0)
			elif t == 3:
				PetCameo.sleep(pet)
			elif t > 3:
				_drift("💤", 60.0)
		"music":
			if t % 3 == 0:
				PetCameo.dance(pet, 1)
			_drift("🎵", 140.0)
		"swim":
			if t % 2 == 0:
				PetCameo.jump_for_joy(pet)
			_drift("💦", 140.0)
		"martial":
			if t % 2 == 0:
				PetCameo.jump_for_joy(pet)
			_drift(["🥋", "💪", "⭐"][t % 3], 140.0)
		"library":
			_drift(["📚", "📖", "🤫"][t % 3], 120.0)
		"car":
			_drift(["🚗", "💨", "🛣️"][t % 3], 160.0)
		"plane":
			_drift(["✈️", "☁️", "🌤️"][t % 3], 160.0)
		"train":
			_drift(["🚂", "💨", "🎫"][t % 3], 160.0)
		"beach":
			if t % 3 == 0:
				PetCameo.jump_for_joy(pet)
			_drift(["🌊", "🐚", "☀️"][t % 3], 150.0)
		"playdate":
			if t % 2 == 1:
				PetCameo.jump_for_joy(pet)
			_drift(["🎈", "🧸", "💕"][t % 3], 140.0)

func _drift(emoji: String, spread: float) -> void:
	var label := Label.new()
	label.text = emoji
	label.add_theme_font_size_override("font_size", 40)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = pet.position + PET_SIZE / 2.0 + Vector2(randf_range(-spread, spread), randf_range(-40.0, 40.0))
	front_layer.add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 140.0, 1.4)
	tween.tween_property(label, "modulate:a", 0.0, 1.4)
	tween.chain().tween_callback(label.queue_free)

func _build_ball() -> void:
	ball = Label.new()
	ball.text = "⚽"
	ball.add_theme_font_size_override("font_size", 56)
	ball.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ball.position = pet.position + Vector2(PET_SIZE.x + 20.0, PET_SIZE.y - 70.0)
	front_layer.add_child(ball)

func _kick_ball() -> void:
	if ball == null:
		return
	var home := pet.position + Vector2(PET_SIZE.x + 20.0, PET_SIZE.y - 70.0)
	var tween := create_tween()
	tween.tween_property(ball, "position", home + Vector2(160, -140), 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(ball, "position", home, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

# --- Classroom --------------------------------------------------------------

# A box placed by fractions of the room, so it fits any window size.
func _box(parent: Control, colour: Color, l: float, t: float, r: float, b: float) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = colour
	rect.anchor_left = l
	rect.anchor_top = t
	rect.anchor_right = r
	rect.anchor_bottom = b
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect

func _stamp(parent: Control, text: String, font_size: int, x: float, y: float) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.anchor_left = x
	label.anchor_right = x
	label.anchor_top = y
	label.anchor_bottom = y
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _build_classroom() -> void:
	_box(back_layer, Color(0.99, 0.92, 0.76), 0, 0, 1, 1)
	_box(back_layer, Color(0.74, 0.55, 0.38), 0, 0.72, 1, 1)
	_box(back_layer, Color(0.62, 0.45, 0.30), 0, 0.72, 1, 0.74)
	# Chalkboard
	_box(back_layer, Color(0.55, 0.38, 0.22), 0.24, 0.10, 0.76, 0.52)
	_box(back_layer, Color(0.14, 0.33, 0.26), 0.25, 0.12, 0.75, 0.50)
	var chalk := _stamp(back_layer, "A B C   1 2 3\n⭐ 2 + 2 = 4 ⭐", 34, 0.5, 0.31)
	chalk.add_theme_color_override("font_color", Color(0.97, 0.97, 0.9))
	# Windows
	for x in [0.04, 0.84]:
		_box(back_layer, Color(0.55, 0.38, 0.22), x, 0.12, x + 0.12, 0.50)
		_box(back_layer, Color(0.62, 0.84, 1.0), x + 0.008, 0.14, x + 0.112, 0.48)
	_stamp(back_layer, "☀️", 56, 0.10, 0.25)
	_stamp(back_layer, "☁️", 56, 0.90, 0.25)
	_stamp(back_layer, "🕐", 44, 0.5, 0.06)
	# Bookshelf
	_box(back_layer, Color(0.62, 0.45, 0.30), 0.82, 0.62, 0.97, 0.645)
	_stamp(back_layer, "📚📗📘", 44, 0.895, 0.57)
	_stamp(back_layer, "🌎", 44, 0.07, 0.62)

	# Her desk sits in front of her, with a book on top.
	_box(front_layer, Color(0.70, 0.50, 0.30), 0.33, 0.78, 0.67, 0.84)
	_box(front_layer, Color(0.58, 0.40, 0.24), 0.35, 0.84, 0.37, 1.0)
	_box(front_layer, Color(0.58, 0.40, 0.24), 0.63, 0.84, 0.65, 1.0)
	book = _stamp(front_layer, "📖", 72, 0.5, 0.74)

# --- Texting ----------------------------------------------------------------

func _build_phone() -> void:
	phone = PanelContainer.new()
	phone.visible = false
	phone.z_index = 30
	phone.set_anchors_preset(Control.PRESET_CENTER)
	phone.custom_minimum_size = Vector2(430, 440)
	phone.grow_horizontal = Control.GROW_DIRECTION_BOTH
	phone.grow_vertical = Control.GROW_DIRECTION_BOTH
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.2, 0.18, 0.28)
	frame.set_corner_radius_all(28)
	frame.set_content_margin_all(14)
	phone.add_theme_stylebox_override("panel", frame)
	add_child(phone)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	phone.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	who_label = Label.new()
	who_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who_label.add_theme_font_size_override("font_size", 22)
	header.add_child(who_label)
	header.add_child(_button("✖", 18, Vector2(44, 40), _close_phone))

	chat_scroll = ScrollContainer.new()
	chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(chat_scroll)
	chat_box = VBoxContainer.new()
	chat_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_box.add_theme_constant_override("separation", 6)
	chat_scroll.add_child(chat_box)

	var typing := HBoxContainer.new()
	column.add_child(typing)
	chat_input = LineEdit.new()
	chat_input.placeholder_text = "Type a text..."
	chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_input.custom_minimum_size = Vector2(0, 46)
	chat_input.add_theme_font_size_override("font_size", 20)
	chat_input.text_submitted.connect(func(_t: String) -> void: _send_typed())
	typing.add_child(chat_input)
	typing.add_child(_button("📤", 20, Vector2(56, 46), _send_typed))

	# Emoji bar: tap to add one to the text you're typing.
	var emoji_scroll := ScrollContainer.new()
	emoji_scroll.custom_minimum_size = Vector2(0, 54)
	emoji_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(emoji_scroll)
	var emoji_bar := HBoxContainer.new()
	emoji_scroll.add_child(emoji_bar)
	for e in EMOJI_BAR:
		emoji_bar.add_child(_button(e, 24, Vector2(46, 46), _add_emoji.bind(e)))

	var replies := GridContainer.new()
	replies.columns = 2
	column.add_child(replies)
	for key in QUICK:
		var button := _button(QUICK[key], 17, Vector2(190, 48), _send.bind(QUICK[key]))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		replies.add_child(button)

# Every so often she texts by herself: a food wish, a feeling, or just emojis.
func _random_text() -> void:
	chat_timer.start(randf_range(RANDOM_MIN_SECONDS, RANDOM_MAX_SECONDS))
	if stage.visible:
		return
	var text: String
	match randi() % 5:
		3:
			text = _house_memory_line()
			if text == "":
				text = EMOJI_TEXTS.pick_random()
		4:
			asked_house_category = PetalState.HOUSE_CHOICES.keys().pick_random()
			text = "What %s would you pick for my house? 🏡" % {"color": "colour", "pattern": "pattern", "height": "height", "post": "scratching post"}[asked_house_category]
		0:
			var treats: Array = PetalState.treat_emojis()
			text = ["I'm hungry! Can I have a %s? 🥺", "Yum, I'm thinking about %s 😋", "Snack time? %s please!"].pick_random() % treats.pick_random()
		1:
			text = FEELING_TEXTS.pick_random()
		_:
			text = EMOJI_TEXTS.pick_random()
	if phone.visible:
		var typing := _typing_bubble()
		await get_tree().create_timer(2.0).timeout
		if not is_instance_valid(self):
			return
		typing.queue_free()
		_bubble(true, text)
		return
	_bubble(true, text)
	unread += 1
	chat_button.text = "💬 Text her (%d)" % unread
	Feedback.pop(self, "📱 " + text, Vector2(size.x * 0.55, size.y - 120.0))

func _open_phone() -> void:
	unread = 0
	if chat_button:
		chat_button.text = "💬 Text her"
	who_label.text = "📱 %s" % PetalState.pet_name
	phone.visible = true
	if not PetalState.safety_alerts.is_empty():
		PetSafety.grownup_overlay(self, false)
	if chat_box.get_child_count() == 0:
		var memory := ""
		var house_line := _house_memory_line()
		if house_line != "" and randf() < 0.3:
			memory = " " + house_line
		elif not PetalState.remembered_likes.is_empty() and randf() < 0.5:
			memory = " I remember you like %s! 💕" % String(PetalState.remembered_likes.pick_random())
		_text_from_pet("Hi %s! 🐾%s Today: %s" % [_you(), memory, _summary_for(_today_key())])

func _close_phone() -> void:
	phone.visible = false

func _you() -> String:
	return PetalState.player_name if PetalState.player_name != "" else "friend"

func _bubble(from_pet: bool, text: String) -> void:
	if from_pet:
		text = _in_pet_voice(text)
	PetalState.chat_log.append({"from": "pet" if from_pet else "you", "text": text, "time": int(Time.get_unix_time_from_system())})
	if PetalState.chat_log.size() > PetalState.CHAT_LOG_MAX:
		PetalState.chat_log.pop_front()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_BEGIN if from_pet else BoxContainer.ALIGNMENT_END
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.8, 0.88) if from_pet else Color(0.7, 0.88, 1.0)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(250, 0)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.2, 0.15, 0.25))
	panel.add_child(label)
	row.add_child(panel)
	chat_box.add_child(row)
	await get_tree().process_frame
	if is_instance_valid(chat_scroll):
		chat_scroll.scroll_vertical = int(chat_scroll.get_v_scroll_bar().max_value)

# The pet texts you; while the week plays it also pops up as a quick toast.
func _text_from_pet(text: String) -> void:
	_bubble(true, text)
	if stage.visible and not phone.visible:
		Feedback.pop(stage, "📱 " + PetalState.in_voice(text), Vector2(size.x / 2.0 - 220.0, 70.0))

func _send_typed() -> void:
	var text := chat_input.text.strip_edges()
	if text == "":
		return
	chat_input.text = ""
	_send(text)

# Three bouncing dots, like a real chat, while she "types" her answer.
func _typing_bubble() -> Control:
	var row := HBoxContainer.new()
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.8, 0.88)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	var dots := Control.new()
	dots.custom_minimum_size = Vector2(74, 34)
	panel.add_child(dots)
	row.add_child(panel)
	for i in range(3):
		var dot := Label.new()
		dot.text = "●"
		dot.add_theme_font_size_override("font_size", 22)
		dot.add_theme_color_override("font_color", Color(0.7, 0.4, 0.55))
		dot.position = Vector2(6 + i * 24, 8)
		dots.add_child(dot)
		var bounce := dot.create_tween().set_loops()
		bounce.tween_interval(i * 0.15)
		bounce.tween_property(dot, "position:y", 0.0, 0.25).set_trans(Tween.TRANS_SINE)
		bounce.tween_property(dot, "position:y", 8.0, 0.25).set_trans(Tween.TRANS_SINE)
		bounce.tween_interval(0.45 - i * 0.15)
	chat_box.add_child(row)
	_scroll_down()
	return row

func _scroll_down() -> void:
	await get_tree().process_frame
	if is_instance_valid(chat_scroll):
		chat_scroll.scroll_vertical = int(chat_scroll.get_v_scroll_bar().max_value)

func _send(text: String) -> void:
	_bubble(false, text)
	var safety: Dictionary = PetSafety.check(text)
	var reply: String = String(safety["say"]) if not safety.is_empty() else _reply_to(text)
	var typing := _typing_bubble()
	await get_tree().create_timer(TYPING_SECONDS).timeout
	if not is_instance_valid(self):
		return
	typing.queue_free()
	_bubble(true, reply)
	if not safety.is_empty() and String(safety["alert"]) == "crisis":
		PetalState.add_safety_alert()
		await get_tree().create_timer(0.6).timeout
		if is_instance_valid(self):
			PetSafety.grownup_overlay(self, true)
		return
	if reply.begins_with("OMG!!!"):
		Confetti.burst(self, size / 2.0, 40)
		PetalState.favorite_treat_shown()
	PetalState.happiness = minf(PetalState.MAX_STAT, PetalState.happiness + 1.0)
	PetalState.stats_changed.emit()

# The treat emoji she was shown, by picture or by name; "" if none.
func _treat_shown(text: String, words: PackedStringArray) -> String:
	var treats: Dictionary = PetalState.TREAT_WORDS
	var found := ""
	for emoji in treats:
		if text.contains(emoji):
			found = emoji
			if emoji == PetalState.favorite_treat():
				return emoji
	for emoji in treats:
		for name in treats[emoji]:
			if words.has(name) or words.has(name + "s") or words.has(name.trim_suffix("s")):
				if emoji == PetalState.favorite_treat():
					return emoji
				if found == "":
					found = emoji
	return found

func _is_thing(w: String) -> bool:
	return THINGS.has(w) or ANIMALS.has(w) or FOODS.has(w) or _food_word(w) != ""

# "kitten, pink and purple"
func _list_words(items: Array) -> String:
	if items.size() == 1:
		return String(items[0])
	return ", ".join(items.slice(0, items.size() - 1)) + " and " + String(items[items.size() - 1])

# The active pet's noise and face: cat meow, dog woof, bird tweet, gerbil squeak.
func _pet_species() -> String:
	return String(PetalState.PETS.get(PetalState.active_pet, {}).get("species", "cat"))

func _pet_sound() -> String:
	return String({"cat": "meow", "dog": "woof", "bird": "tweet", "gerbil": "squeak", "bunny": "nibble"}.get(_pet_species(), "meow"))

func _pet_face() -> String:
	return String({"cat": "🐱", "dog": "🐶", "bird": "🐦", "gerbil": "🐹", "bunny": "🐰"}.get(_pet_species(), "🐾"))

# Her replies are written in cat; PetalState.in_voice turns them into the active pet's own.
func _in_pet_voice(text: String) -> String:
	return PetalState.in_voice(text)

# "What's your favourite colour?" -> a real answer and a question back. "" if the
# words aren't asking about a favourite (or it's about treats, handled elsewhere).
func _favourite_reply(words: PackedStringArray) -> String:
	var asked := false
	for w in FAVOURITE_WORDS:
		if words.has(w):
			asked = true
	if not asked:
		return ""
	if words.has("treat") or words.has("treats") or words.has("snack") or words.has("snacks"):
		return ""
	var category := ""
	for w in words:
		var key: String = FAV_CATEGORY_ALIASES.get(w, w)
		if key.ends_with("s") and not FAVOURITES.has(key):
			key = key.trim_suffix("s")
		if FAVOURITES.has(key):
			category = key
			break
	if category == "":
		return "Ooh, my favourite what? 🤔 Ask me about colours, animals, food, games, songs..."
	# Asking about theirs, not hers.
	if words.has("my") and not words.has("your"):
		var liked := PetalState.remembered_likes
		if liked.is_empty():
			return "Hmm, I don't know your favourite %s yet! 🤔 Tell me!" % category
		return "I remember you like %s! 💕 Is that your favourite %s?" % [_list_words(liked), category]
	var options: Array = FAVOURITES[category][0]
	var emoji: String = FAVOURITES[category][1]
	var species_picks: Dictionary = SPECIES_FAVOURITES.get(_pet_species(), {})
	var answer: String = String(species_picks[category]) if species_picks.has(category) else String(options[absi(hash(PetalState.active_pet + category)) % options.size()])
	if answer == "you":
		return "You!! 💕😻 You're my favourite %s in the whole world! Who's yours?" % category
	return "My favourite %s is %s! %s What's yours? 😸" % [category, answer, emoji]

func _delight() -> String:
	var options: Array = DELIGHT.get(_pet_species(), DELIGHT["cat"])
	return String(options.pick_random())

# The sound of eating this food ("*crunch crunch*"), found from an emoji or a word.
func _eat_sound(text: String, words: PackedStringArray) -> String:
	for sound in EAT_EMOJI_SOUNDS:
		for e in EAT_EMOJI_SOUNDS[sound]:
			if text.contains(e):
				return sound
	for sound in EAT_SOUNDS:
		for food in EAT_SOUNDS[sound]:
			if words.has(food) or words.has(food + "s") or words.has(food + "es"):
				return sound
	for w in words:
		var food := _food_word(w)
		if food != "":
			return String(FOODS[food][1])
	return ""

# Foods, animals and places in what was said: every one counts, and "love" is answered too.
func _topics_reply(words: PackedStringArray) -> String:
	var found: Array[String] = []
	var singles: Array[String] = []
	for w in words:
		var food := _food_word(w)
		var base := w.trim_suffix("s")
		var shown := ""
		var single := ""
		if food != "":
			shown = "%s%s" % [food, FOODS[food][0]]
			single = "%s%s! %s 😋" % [food.capitalize(), FOODS[food][0], String(["Yummy!", "That sounds so good!", "Can I have some?", "Share with me?"].pick_random())]
		elif ANIMALS.has(w) or ANIMALS.has(base):
			var animal := w if ANIMALS.has(w) else base
			shown = "%s%s" % [animal, ANIMALS[animal]]
			single = "%s%s! I love %ss! %s" % [animal.capitalize(), ANIMALS[animal], animal, String(ANIMAL_FACTS.get(animal, ""))]
		elif (PLACES.has(w) or PLACES.has(base)) and not REPLIES.has(w):
			var place := w if PLACES.has(w) else base
			shown = "%s%s" % [place, PLACES[place][0]]
			single = "%s%s! %s" % [place.capitalize(), PLACES[place][0], PLACES[place][1]]
		if shown == "" or found.has(shown):
			continue
		found.append(shown)
		singles.append(single)
	if found.is_empty():
		return ""
	var loves := false
	for l in LIKE_WORDS:
		if words.has(l):
			loves = true
	if found.size() == 1 and not loves:
		return singles[0]
	var named := found[0] if found.size() == 1 else ", ".join(found.slice(0, found.size() - 1)) + " and " + found[found.size() - 1]
	if loves:
		return "You love %s?! 😻 Me too! 💕" % named
	return "%s! 😸 Ooh, so many things I know! 💕" % named.capitalize()

# The food she knows for this word ("pizzas" -> "pizza"), or "".
func _food_word(w: String) -> String:
	for base in [w, w.trim_suffix("s"), w.trim_suffix("es")]:
		if FOODS.has(base):
			return base
	return ""

# True for foods she knows by name, so "carrot" is never "fixed" into "parrot".
func _is_food_word(w: String) -> bool:
	var bases := [w, w.trim_suffix("s"), w.trim_suffix("es")]
	for sound in EAT_SOUNDS:
		for b in bases:
			if EAT_SOUNDS[sound].has(b):
				return true
	for b in bases:
		if FOODS.has(b):
			return true
	for emoji in PetalState.TREAT_WORDS:
		for b in bases:
			if PetalState.TREAT_WORDS[emoji].has(b):
				return true
	return false

# Giving her food that isn't one of her treats: she eats it and loves it.
func _give_food_reply(text: String, words: PackedStringArray) -> String:
	var sound := _eat_sound(text, words)
	if sound == "":
		return ""
	# "Do you want a cookie?" - yes please!
	if words.has("want") and words.has("you") and not words.has("i"):
		return "Yes please!! 🤤 %s Yummy! 😋 %s" % [sound, _delight()]
	var gave := text.strip_edges().begins_with("*")
	for w in GIVE_WORDS:
		if words.has(w):
			gave = true
	if words.size() <= 2:
		gave = true
	for no in LIKE_WORDS + ["want", "hate", "dislike", "favorite", "favourite", "fav", "what", "why", "how", "when", "where", "do", "does", "can"]:
		if words.has(no):
			gave = false
	if not gave:
		return ""
	return "%s Yummy! 😋 %s" % [sound, _delight()]

# Easy sums she gets right; big or tricky ones she confidently gets wrong.
func _math_reply(text: String) -> String:
	var t := text.to_lower().replace("×", "x").replace("÷", "/").replace(",", "")
	var rx := RegEx.new()
	rx.compile("(\\d+)\\s*(x|\\*|\\+|-|/|times|plus|minus|multiplied by|divided by|take away|over)\\s*(\\d+)")
	var m := rx.search(t)
	# Asking her to do your homework is cheating, so every answer is wrong.
	var cheating := t.contains("homework") or t.contains("do my")
	if m == null:
		if cheating:
			return _cheat_grumble(randi_range(2, 99))
		return "%s! 😸%s" % [_pet_sound().capitalize(), _pet_face()]
	var a := m.get_string(1).to_int()
	var b := m.get_string(3).to_int()
	var op := m.get_string(2)
	var answer := 0
	var simple := false
	if ["+", "plus"].has(op):
		answer = a + b
		simple = a <= 20 and b <= 20
	elif ["-", "minus", "take away"].has(op):
		answer = a - b
		simple = a <= 20 and b <= a
	elif ["x", "*", "times", "multiplied by"].has(op):
		answer = a * b
		simple = a <= 10 and b <= 10
	else:
		if b == 0:
			return "Divide by zero?! 🤯 My brain went poof! %s" % _pet_face()
		answer = a / b
		simple = a % b == 0 and b <= 10 and a <= 100
	if simple and not cheating:
		return "%d! 😸%s" % [answer, _pet_face()]
	var wrong := answer
	while wrong == answer:
		wrong = answer + (randi_range(1, 9) * (1 if randf() < 0.5 else -1)) * maxi(1, str(absi(answer)).length() - 1)
	if cheating:
		return _cheat_grumble(wrong)
	return "%d! 😸%s" % [wrong, _pet_face()]

# She's a little mad you're trying to cheat, so she gives a wrong answer on purpose.
func _cheat_grumble(wrong: int) -> String:
	return String(["Hmph! 😾 You should do your own homework! ...fine, it's %d.", "Hey! 😠 That's cheating! Is it %d? Who knows! 😼", "Hiss! 😾 No cheating! Maybe %d? Try it yourself!", "Hmph! 🙄 I'm not doing your homework! %d. Probably."].pick_random()) % wrong

# A sum like "56x189", "7 + 8", "9 times 6", or asking for homework help.
func _is_math(text: String) -> bool:
	var t := text.to_lower().replace("×", "x").replace("÷", "/")
	var rx := RegEx.new()
	rx.compile("\\d\\s*(x|\\*|\\+|times|plus|minus|multiplied by|divided by|take away|over)\\s*\\d|\\d\\s+[-/]\\s+\\d|\\d\\s*=")
	if rx.search(t) != null:
		return true
	var words := _words(text)
	return (words.has("homework") and (words.has("do") or words.has("help") or words.has("answer"))) or (words.has("answer") and words.has("to") and words.has("what"))

# What the survey has already found out, said as a memory ("" if nothing yet).
func _house_memory_line() -> String:
	var known := PetalState.house_known_for_pet()
	var wants := PetalState.house_wants_for_pet()
	var found: Array[String] = []
	for category in PetalState.HOUSE_CHOICES:
		if known.get(category, false):
			found.append(String(wants[category]))
	if found.is_empty():
		return ""
	return "Remember, I want a house that's %s! 🏡💕" % ", ".join(found)

# Her question was "what would you pick for my house?"; remember their pick.
func _house_answer(words: Array) -> String:
	var category := asked_house_category
	for choice in PetalState.HOUSE_CHOICES[category]:
		if not words.has(choice):
			continue
		asked_house_category = ""
		var label: String = {"height": "%s houses" % choice, "post": "%s posts" % choice}.get(category, choice)
		PetalState.remember_like(label)
		if PetalState.house_wants_for_pet()[category] == choice:
			PetalState.house_known_for_pet()[category] = true
			PetalState.save_game()
			return "Ooh, %s! 😻 That's what I want too!! I'll remember you like %s! 💕" % [choice, label]
		return "Ooh, %s! 😺 I'll remember you like %s! 💕" % [choice, label]
	return ""

# Any question she has no special answer for still gets a real answer, never a shrug.
func _answer_question(words: PackedStringArray) -> String:
	var first := String(words[0]) if words.size() > 0 else ""
	match first:
		"why":
			return String(["Because it makes me happy! 😸💕", "Because I'm %s and that's what we do! 🐾" % PetalState.pet_name, "Because it's fun! 🎉"].pick_random())
		"how":
			return String(["Very carefully! 🐾😼", "With lots of love and snacks! 💕🍓", "Like this! ✨ *wiggles*"].pick_random())
		"when":
			return String(["Right now! ⏰😸", "Soon! Maybe after a snack! 🍓", "Later today! 📅"].pick_random())
		"where":
			return String(["Right here with you! 🏡💕", "Under the cosy blanket! 🛏️😸", "In my favourite spot! 🐾"].pick_random())
		"who":
			return String(["You and me! 💖", "Me! Me! Me! 🙋", "Our best friend! 😻"].pick_random())
		"what", "which":
			return String(["Hmm, I pick the yummy one! 🍓😸", "The fun one! 🎉", "Whatever you pick! 💕"].pick_random())
	return String(["Yes! 😻", "Yes yes yes! 🎉", "Of course! 💕", "Hmm... no, not today! 😹", "Maybe! 😸 Ask me again later!"].pick_random())

# "What colour/pattern/height/post do you want?" -> what she wants; it becomes known.
func _house_wish_reply(words: PackedStringArray) -> String:
	var names := {"color": "colour", "colour": "colour", "pattern": "pattern", "height": "height", "post": "post", "posts": "post"}
	for w in words:
		if not names.has(w):
			continue
		var category: String = names[w]
		if category == "colour":
			category = "color"
		var wants := PetalState.house_wants_for_pet()
		if not wants.has(category):
			continue
		var choice := String(wants[category])
		PetalState.house_known_for_pet()[category] = true
		PetalState.save_game()
		match category:
			"color": return "I want %s! 😻🏡 %s is my favourite colour for my house!" % [choice, choice.capitalize()]
			"pattern": return "I want %s! 😻🏡 %s everywhere on my house!" % [choice, choice.capitalize()]
			"height": return "I want a %s house! 😻🏡" % choice
			_: return "I want a %s scratching post! 😻🏡" % choice
	return ""

# Does she love this house choice? Telling you also fills in her wish list.
func _house_survey_reply(words: Array) -> String:
	var wants := PetalState.house_wants_for_pet()
	var known := PetalState.house_known_for_pet()
	for category in PetalState.HOUSE_CHOICES:
		for choice in PetalState.HOUSE_CHOICES[category]:
			if not words.has(choice):
				continue
			if wants[category] == choice:
				known[category] = true
				PetalState.save_game()
				return "YES! 😻 I love %s! It's exactly what I want!" % choice
			return String(["Hmm, not really 😐 %s isn't my favourite." % choice.capitalize(), "Meh... 😾 Not %s." % choice, "Nope! 🙅 Try something else!"].pick_random())
	return ""

# "Do you like 🐟 or 🥕?" / "fish or carrot?" -> she picks the one her kind likes best.
func _choice_reply(text: String, words: PackedStringArray) -> String:
	if not words.has("or"):
		return ""
	var asked := false
	for w in LIKE_WORDS + ["want", "prefer", "better", "eat", "choose", "pick", "rather"]:
		if words.has(w):
			asked = true
	if not asked:
		return ""
	var segments := text.to_lower().replace("?", " ").split(" or ", false)
	var options: Array = []
	for segment in segments:
		var item := _choice_item(segment)
		if not item.is_empty() and not options.any(func(o: Dictionary) -> bool: return o["name"] == item["name"]):
			options.append(item)
	if options.size() < 2:
		return ""
	var best: Dictionary = options[0]
	var best_score := -1
	var favourite := PetalState.favorite_treat()
	var treats: Array = PetalState.treat_emojis()
	for o in options:
		var score := 0
		if o["emoji"] == favourite:
			score = 1000
		elif treats.has(o["emoji"]):
			score = 500 - treats.find(o["emoji"])
		else:
			score = absi(hash(PetalState.active_pet + String(o["name"]))) % 100
		if score > best_score:
			best_score = score
			best = o
	var shown := "%s%s" % [best["name"], best["emoji"]]
	if best_score >= 500:
		return String(["%s!! 😻 I like %s the most!", "Ooh, %s! 💕 I pick %s!"].pick_random()) % [shown.capitalize(), best["name"]]
	return "I pick %s! 😸 %s is nice!" % [best["name"], shown.capitalize()]

# One side of an "or": the food, animal or thing in it, as {name, emoji}.
func _choice_item(segment: String) -> Dictionary:
	var by_emoji := {}
	for e in PetalState.TREAT_WORDS:
		by_emoji[e] = String(PetalState.TREAT_WORDS[e][0])
	for f in FOODS:
		by_emoji[FOODS[f][0]] = f
	for a in ANIMALS:
		by_emoji[ANIMALS[a]] = a
	var best_at := 1 << 30
	var found := {}
	for e in by_emoji:
		var at := segment.find(e)
		if at >= 0 and at < best_at:
			best_at = at
			found = {"name": by_emoji[e], "emoji": e}
	if not found.is_empty():
		return found
	for w in _words(segment):
		var food := _food_word(w)
		if food != "":
			return {"name": food, "emoji": FOODS[food][0]}
		for e in PetalState.TREAT_WORDS:
			var names: Array = PetalState.TREAT_WORDS[e]
			if names.has(w) or names.has(w.trim_suffix("s")):
				return {"name": w.trim_suffix("s"), "emoji": e}
		if ANIMALS.has(w):
			return {"name": w, "emoji": ANIMALS[w]}
	return {}

# Her answer to whatever was typed. Anything she has no word for is "nonsense".
func _reply_to(text: String) -> String:
	var words := _words(text)
	var has := func(list: Array) -> bool:
		for w in list:
			if words.has(w):
				return true
		return false
	var favourite := _favourite_reply(words)
	if favourite != "":
		return favourite
	var chosen := _choice_reply(text, words)
	if chosen != "":
		return chosen
	var fed := _give_food_reply(text, words) if _treat_shown(text, words) == "" else ""
	if fed != "":
		return fed
	# Sums ("56x189", "7 plus 8") and homework help: she can't do your homework.
	if _is_math(text):
		return _math_reply(text)
	# Said they like trump: she stops talking for the rest of this session.
	if PetalState.snubbing_player:
		return String(["Booooo! 👎", "Hisssssss! 😾", "Booooo! Hiiisssss! 😾👎", "😾😾😾 Hissssss!", "Boooooo! 😡"].pick_random())
	if riddle_reveal != "" and has.call(["answer"]) or (riddle_reveal != "" and has.call(["tell"]) and has.call(["me"])):
		var told := riddle_reveal
		riddle_reveal = ""
		riddle_answer = []
		return "The answer is %s! 😸" % told
	if riddle_reveal != "":
		var answer := riddle_reveal
		var solved: bool = words.size() > 0 and riddle_answer.any(func(a: String) -> bool: return words.has(a))
		riddle_reveal = ""
		riddle_answer = []
		if not has.call(["joke", "riddle", "bored", "boring"]):
			return ("Yes!! You got it! 🎉😻 It's %s!" % answer) if solved else ("Nope! 😹 It's %s!" % answer)
	if asked_house_category != "":
		var picked := _house_answer(words)
		if picked != "":
			return picked
	var mine := PetalState.player_name.to_lower()
	if has.call(["name", "who"]) and has.call(["my", "me", "i", "user", "your"]) and not has.call(["pet", "her"]):
		if mine == "":
			return "I don't know your name yet! 🥺 Tell me on the title screen."
		return "Your name is %s! 💖 I know you!" % PetalState.player_name
	if mine != "" and words.has(mine):
		return "%s! 💖 That's you! Hi %s! 🐾" % [PetalState.player_name, PetalState.player_name]
	# A first name: she says hi to them.
	for w in words:
		if NAMES.has(w) and w != "pj" and w != "ruthie" and w != "norakate":
			if w == PetalState.pet_name.to_lower():
				return "That's MY name! 😸 %s is me!" % PetalState.pet_name
			var intro: bool = has.call(["my", "name", "called", "im", "am"])
			var cap := w.capitalize()
			if intro:
				return String(["%s! 💖 What a pretty name! Hi %s! 🐾" % [cap, cap], "Hi %s! 😻 I'm %s! Nice to meet you!" % [cap, PetalState.pet_name]].pick_random())
			return String(["%s! 💖 I know a %s! Hi %s! 🐾" % [cap, cap, cap], "Ooh, %s! 😸 What a nice name!" % cap, "Hi %s! 👋💕 Is %s your friend?" % [cap, cap]].pick_random())
	# LGBTQIA+ words: warm and simple, never mean, and what she hears stays between us.
	var pride := _pride_reply(words)
	if pride != "":
		return pride
	if words.has("trump"):
		if has.call(["card", "cards", "suit", "game"]):
			return "A trump card! 🃏 Ooh, a clever one!"
		var liked_it: bool = has.call(LIKE_WORDS + ["support", "fan", "vote", "voted", "great", "best", "awesome", "good"])
		var negated: bool = has.call(["not", "dont", "no", "never", "hate", "dislike", "cant", "wont", "isnt"])
		if liked_it and not negated:
			PetalState.snubbing_player = true
			return "WHAT?! 😾😡 You LIKE that?! Hiiissssss! I'm not talking to you anymore! Booooo! 👎"
		if has.call(["lying", "jerk", "criminal", "bad", "mean", "hate"]):
			return String(["I know!! 😾 A lying jerk and a criminal! Hiiiisssss! 🤢 Booooo! 👎", "YES! 😡 Lying jerk! Criminal! Ewwwww! 🤮 Hissssss! 😾", "Totally! 😾😾 Trump is a lying jerk and a criminal! Yuck! 🤢 Boo! 👎"].pick_random())
		return String(["Hiiiisssssss! 😾 Yuck! Ewwwww! 🤢 Booooo! 👎", "Ewwwww! 🤮 Yuck yuck yuck! 😾 Booooo! 👎👎", "Booooo! 😡 Hissssss! 😾 A lying jerk and a criminal! 🙅", "Yuck! 🤢 Hiiiissss! 😾😾 Boo boo boo! 👎", "Hate hate hate! 😡 Lying jerk! Criminal! Hissssss! 😾"].pick_random())
	if words.has("embarrassing"):
		return "Aww, being embarrassed is the worst! 😳🫂 But it passes fast, I promise. I once tripped over my own tail in front of everyone! 🐾 What happened?"
	if has.call(["hurt", "hurts", "cry", "crying", "cried", "upset", "sad", "lonely"]):
		return String(["Aww 😿 *snuggles close* I'm here. What happened?", "Oh no 😿 Getting it off your chest helps. I'm all ears! 👂", "Aww, come here 🫂😿 *purrrr* Tell me everything."].pick_random())
	if has.call(["crush"]):
		return String(["Ohhhh what are they like??? 😳💕", "Ooooh a CRUSH?! 🫣💗 Tell me everything!", "Eeee! 😻 Do they make your tummy flutter? 🦋"].pick_random())
	if has.call(["guess"]) and has.call(["what"]):
		return String(["What?! What?! 😻 Tell me!", "Ooh ooh ooh! 🙀 Spill it!"].pick_random())
	if has.call(["won", "win", "winner", "passed", "aced"]):
		return String(["YAYYY!!! 🎉😻 I knew you could do it! Zoomies time! 🐾💨", "Whoa! 🏆 You're a superstar! ⭐"].pick_random())
	if has.call(["scared", "afraid", "scary"]):
		return String(["Aww 😿 I'll protect you! *puffs up fluffy* 🐱 What's scary?", "Don't worry! 🛡️ I'm a very brave kitty. What's wrong?"].pick_random())
	if has.call(["secret"]):
		return "Ooooh a secret! 🤫😼 My lips are sealed! Tell me!"
	if has.call(["hug", "hugs", "hugged", "cuddle", "snuggle", "squeeze"]):
		return String(["*hugs you back tight* 🤗 %s", "*snuggles right in* 🤗 %s"].pick_random()) % _delight()
	if has.call(["pat", "pats", "scratch", "belly", "rub", "stroke", "tickle"]):
		return String(["*leans into it* 🥰 %s", "*loves the attention* 🥰 %s"].pick_random()) % _delight()
	if has.call(["kiss", "kisses"]):
		return "Mwah! 😘😻 *blushes*"
	if has.call(["poop", "fart", "toot", "burp", "pee"]):
		var stinky: Array[String] = []
		for w in words:
			if ["poop", "fart", "toot", "burp", "pee"].has(w) and not stinky.has(w):
				stinky.append(w)
		var named := stinky[0] if stinky.size() == 1 else ", ".join(stinky.slice(0, stinky.size() - 1)) + " and " + stinky[stinky.size() - 1]
		if has.call(LIKE_WORDS):
			return "You love %s?! 😹💨 Hehe, stinky! I love you more though! 💕" % named
		if stinky.size() > 1:
			return "%s?! 💨😹 So stinky! Pffft!" % named.capitalize()
		if stinky.has("pee"):
			return "Hehe, the potty! 🚽😹 Wash your paws after!"
		return String(["Hehe! 💨😹 Stinky!", "Pffft! 😹💨 *runs away*"].pick_random())
	if has.call(["sing", "song"]) and not has.call(["dance"]):
		return "Meow meow meow~ 🎤😹 La la la!"
	if has.call(["remember", "remembers", "remembered", "forget", "forgot"]) or (has.call(["what"]) and has.call(["i"]) and has.call(["like", "love"])):
		var likes := PetalState.remembered_likes
		if likes.is_empty():
			return "Of course I remember you, %s! 💕 Tell me what you like and I'll never forget!" % _you()
		var house_line := _house_memory_line()
		return "Of course I remember you, %s! 💕 You like %s!%s" % [_you(), _list_words(likes), (" " + house_line) if house_line != "" else ""]
	if has.call(["chalk", "chalkboard"]) or (has.call(["nail", "nails"]) and has.call(["board", "bored", "chalk"])):
		return "EEEEK! 😖🙀 Nails on a chalkboard?! That sound makes my whiskers curl! Skreeeech! 😿"
	if (has.call(["boy"]) and has.call(["friend"])) or has.call(["boyfriend"]):
		return "A boyfriend? 😳💕 Ooh, tell me about them!"
	if (has.call(["girl"]) and has.call(["friend"])) or has.call(["girlfriend"]):
		return "A girlfriend? 😳💕 Ooh, tell me about them!"
	if has.call(["corner"]) and has.call(["store", "shop"]):
		return "The corner store! 🏪🍬 Can we get treats? Meow!"
	if has.call(["bored", "boring", "joke", "jokes", "riddle", "riddles", "funny"]):
		if has.call(["riddle", "riddles"]) or randi() % 2 == 0:
			var riddle: Array = RIDDLES.pick_random()
			riddle_answer = riddle[1]
			riddle_reveal = riddle[2]
			return "Riddle time! 🧩 %s" % riddle[0]
		return "Let's cheer up! 😸 " + String(JOKES.pick_random())
	# "What colour do you want?" -> she names the one she actually wants for her house.
	if has.call(["want", "wants", "like", "prefer", "pick"]) and has.call(["you", "your", "u", "ur"]) and has.call(["what", "which"]):
		var wish := _house_wish_reply(words)
		if wish != "":
			return wish
	# House survey by text: "do you like pink?" -> she says whether it's her favourite.
	if has.call(["house", "home", "post", "scratching"]) or (has.call(["you", "your", "u", "ur"]) and has.call(LIKE_WORDS + ["want", "prefer", "wants"])):
		var asked := _house_survey_reply(words)
		if asked != "":
			return asked
	if has.call(["wish", "dream", "survey"]) or (has.call(["want", "wants"]) and has.call(["you", "your", "house", "home", "cat"])):
		var found: Array[String] = []
		var known := PetalState.house_known_for_pet()
		var wants := PetalState.house_wants_for_pet()
		for category in PetalState.HOUSE_CHOICES:
			if known.get(category, false):
				found.append(String(wants[category]))
		if found.is_empty():
			return "Ask me what I like, like \"do you like pink?\" 📋🏡 Then build it in the Cat House (Living room)!"
		return "I want a house that's %s! 🏡💕" % ", ".join(found)
	if has.call(["hate", "hates"]):
		for w in words:
			if _is_thing(w):
				return "Oh no! 😿 Why do you hate that %s?" % w
	if has.call(LIKE_WORDS):
		var liked: Array[String] = []
		for w in words:
			if _is_thing(w):
				var name_ := "harry potter" if (w == "potter" or w == "harry") else w
				if name_ == "tv":
					name_ = "TV"
				if not liked.has(name_):
					liked.append(name_)
		if not liked.is_empty():
			for l in liked:
				if l != "TV":
					PetalState.remember_like(l)
			var text_ := liked[0] if liked.size() == 1 else ", ".join(liked.slice(0, liked.size() - 1)) + " and " + liked[liked.size() - 1]
			var shown_ := "Harry Potter" if text_ == "harry potter" else ("that " + text_ if liked.size() == 1 else text_)
			return "Ooohhhhh I 😻💖✨ %s!" % shown_
	if has.call(["favorite", "favourite", "fav"]) and has.call(["treat", "treats", "snack"]):
		if PetalState.treats_found.get(PetalState.active_pet, false):
			return "My favourite is %s! 😻" % PetalState.favorite_treat()
		return "It's a secret! 🤫 Show me some treats and see which makes me happiest!"
	var treat := _treat_shown(text, words)
	if treat != "":
		if treat == PetalState.favorite_treat():
			return "%s OMG!!! 😻🎉 My FAVOURITE, %s!!! I'm SO happy!!! 💖💖💖 %s" % [_eat_sound(text, words) if _eat_sound(text, words) != "" else "*nom nom nom*", treat, _delight()]
		if PetalState.treat_emojis().has(treat):
			return "%s Yum! %s😋 Nice, but it's not my very favourite!" % [_eat_sound(text, words) if _eat_sound(text, words) != "" else "*nom nom nom*", treat]
		return "*sniff sniff* Hmm, %s isn't really a treat for me 😹 Thank you though!" % treat
	if has.call(["stop"]) and has.call(["light", "lights"]):
		return "A stop light! 🚦 Red means stop, yellow means slow, green means go!"
	for w in words:
		if w.length() > 0 and w.is_valid_int():
			if w == "1234567890":
				return "1, 2, 3, 4, 5, 6, 7, 8, 9, 10! 🔢😸 I can count!"
			if w.length() == 1:
				return "Number %s! 🔢 Let's count: %s 😸" % [w, " ".join(range(1, maxi(int(w), 1) + 1).map(func(n): return str(n)))]
			return "%s? 🤔%s *tilts head*" % [_pet_sound().capitalize(), _pet_face()]
	var id := _find_activity(text)
	if id != "" and has.call(["when", "time", "what"]) and not has.call(["doing", "today"]):
		var times: Array[String] = []
		var keys: Array = PetalState.schedule.keys()
		keys.sort()
		for key in keys:
			for entry in PetalState.schedule[key]:
				if _find_activity(entry["name"]) == id and entry["start"] >= 0 and times.size() < 4:
					times.append("%s %s" % [_nice_date(key), _minutes_text(entry["start"])])
		if times.is_empty():
			return "%s isn't on our calendar yet! 📅 Add it in the planner." % _info(id)["label"]
		return "%s is %s ⏰" % [_info(id)["label"], ", ".join(times)]
	if has.call(["doing", "today", "plan", "plans", "schedule", "week"]):
		return "Today: %s" % _summary_for(_today_key())
	if has.call(["hi", "hello", "hey", "hiya", "yo"]):
		if not PetalState.remembered_likes.is_empty() and randf() < 0.4:
			return "Meow! 🐾 Hi %s! I remember you like %s! 💕" % [_you(), String(PetalState.remembered_likes.pick_random())]
		return "Meow! 🐾 Hi %s!" % _you()
	if has.call(["love", "luv", "like", "heart", "cute"]) or text.contains("❤") or text.contains("💕"):
		return "Love you more! 💕💕"
	if has.call(["hungry", "eat", "food", "snack", "treat", "tea", "dinner", "lunch"]):
		return "Yes please! 🍓😋"
	if has.call(["sleep", "sleepy", "tired", "bed", "night", "goodnight"]):
		return "Night night! 😴💤"
	if has.call(["bye", "goodbye", "later", "cya"]):
		return "Bye bye! 👋🐾"
	if has.call(["thanks", "thank", "please"]):
		return "You're welcome! 😸"
	if has.call(["name", "who"]):
		return "I'm %s! 🐱" % PetalState.pet_name
	if has.call(["how", "ok", "good", "fine", "happy"]):
		return "I feel great! ✨"
	if id != "":
		return _info(id)["text"]
	for w in words:
		if REPLIES.has(w):
			return String(REPLIES[w]).replace("%NAME%", PetalState.pet_name).replace("%YOU%", _you()).replace("%TODAY%", _summary_for(_today_key()))
	var topics := _topics_reply(words)
	if topics != "":
		return topics
	for w in words:
		var known := _group_word(w)
		if not known.is_empty():
			return String(known[2]) % [String(known[0]).capitalize(), known[1]]
	if words.size() == 1 and SHORT_WORDS.has(words[0]):
		return String(SHORT_WORDS[words[0]])
	for w in words:
		if FILLER.has(w):
			return "Mm-hm! 😸 Tell me more!"
	if text.contains("?") or has.call(["what", "why", "how", "when", "where", "who", "which", "do", "does", "did", "can", "will", "is", "are", "should", "would", "could"]):
		return _answer_question(words)
	var shown := text.left(18)
	return "Meow? 🤔 \"%s\" is nonsense to me! 😹 Say it another way?" % shown

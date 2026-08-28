package promptflow

// DefaultFlow is the seed Guided Prompt Engine questionnaire.
//
// Composition model: the user first picks which subjects are in the image
// (person / object / animal / scene) — multiple allowed. Each subject's
// questions appear only if selected (Condition "elements~=..."). Advanced nodes
// appear only in Detailed mode. Labels are bilingual (Burmese default);
// prompt fragments are English because the image models expect English.
//
// Content note: suggestion pills are Myanmar-themed first, with a handful of
// other cultures/styles mixed in. Text nodes let the user tap a pill OR type.
//
// Client conventions:
//   - single/multi nodes always offer an "Other — type your own" entry.
//   - text nodes render their Options as tappable suggestion pills.
//   - Quick mode shows only non-Advanced nodes; Detailed shows all.
func DefaultFlow() Flow {
	var nodes []Node
	nodes = append(nodes, elementsNode())

	// Each subject carries its OWN branch of parameters AND its own tailored
	// finishing block, so questions never bleed across subjects.
	nodes = append(nodes, personNodes()...)
	nodes = append(nodes, finishingNodes("person", "elements~=person", 180,
		finish{light: true, mood: true, color: true, camera: true, style: true, skin: true, quality: true, aspect: true, details: true})...)

	nodes = append(nodes, coupleNodes()...)
	nodes = append(nodes, finishingNodes("couple", "elements~=couple", 680,
		finish{light: true, mood: true, color: true, camera: true, style: true, skin: true, quality: true, aspect: true, details: true})...)

	nodes = append(nodes, groupNodes()...)
	nodes = append(nodes, finishingNodes("group", "elements~=group", 690,
		finish{light: true, mood: true, color: true, camera: true, style: true, skin: true, quality: true, aspect: true, details: true})...)

	nodes = append(nodes, objectNodes()...)
	nodes = append(nodes, finishingNodes("object", "elements~=object", 260,
		finish{light: true, color: true, camera: true, style: true, quality: true, aspect: true, details: true})...)

	nodes = append(nodes, productNodes()...)
	nodes = append(nodes, finishingNodes("product", "elements~=product", 900,
		finish{light: true, studio: true, color: true, style: true, quality: true, aspect: true, details: true})...)

	nodes = append(nodes, foodNodes()...)
	nodes = append(nodes, finishingNodes("food", "elements~=food", 960,
		finish{light: true, studio: true, color: true, camera: true, style: true, quality: true, aspect: true, details: true})...)

	nodes = append(nodes, animalNodes()...)
	nodes = append(nodes, finishingNodes("animal", "elements~=animal", 360,
		finish{light: true, mood: true, color: true, camera: true, style: true, quality: true, aspect: true, details: true})...)

	nodes = append(nodes, vehicleNodes()...)
	nodes = append(nodes, finishingNodes("vehicle", "elements~=vehicle", 990,
		finish{light: true, color: true, style: true, quality: true, aspect: true, details: true})...)

	nodes = append(nodes, architectureNodes()...)
	nodes = append(nodes, finishingNodes("arch", "elements~=architecture", 1010,
		finish{light: true, color: true, style: true, quality: true, aspect: true, details: true})...)

	nodes = append(nodes, sceneNodes()...)
	nodes = append(nodes, finishingNodes("scene", "elements~=scene", 460,
		finish{light: true, mood: true, color: true, style: true, quality: true, aspect: true, details: true})...)

	nodes = append(nodes, characterNodes()...)
	nodes = append(nodes, finishingNodes("char", "elements~=character", 1030,
		finish{light: true, mood: true, color: true, camera: true, style: true, quality: true, aspect: true, details: true})...)

	nodes = append(nodes, logoNodes()...)
	nodes = append(nodes, finishingNodes("logo", "elements~=logo", 1050,
		finish{quality: true, aspect: true})...)

	return Flow{Version: 3, Start: "elements", Nodes: nodes}
}

// o builds a suggestion Option: id, Burmese label, English label, prompt value.
func o(id, my, en, val string) Option {
	return Option{ID: id, Value: val, Label: L10n{My: my, En: en}}
}

// textNode is a free-text question that also offers tappable suggestion pills.
func textNode(id string, order int, adv bool, cond, qMy, qEn, frag string, opts ...Option) Node {
	return Node{
		ID: id, Order: order, Type: TypeText, Advanced: adv,
		Condition: cond, Fragment: frag,
		Question: L10n{My: qMy, En: qEn},
		Options:  opts,
	}
}

func elementsNode() Node {
	return Node{
		ID: "elements", Order: 0, Type: TypeMulti,
		Question: L10n{My: "ပုံထဲတွင် မည်သည့်အရာများ ပါဝင်စေလိုပါသလဲ? (တစ်ခုထက်ပို၍ ရွေးချယ်နိုင်ပါသည်)", En: "What's in your image? (choose any)"},
		Help:     L10n{My: "ဥပမာ - လူ နှင့် အရာဝတ္ထု ကို တွဲဖက်ရွေးချယ်နိုင်ပါသည်", En: "e.g. person + object together"},
		Options: []Option{
			o("person", "လူ", "Person", "person"),
			o("couple", "စုံတွဲ (၂ ဦး)", "Couple (2 people)", "couple"),
			o("group", "လူအုပ်စု (၃ ဦးနှင့်အထက်)", "Group (3+ people)", "group"),
			o("object", "အရာဝတ္ထု / ပစ္စည်း", "Object", "object"),
			o("product", "ထုတ်ကုန်ပစ္စည်း (ကြော်ငြာ)", "Product", "product"),
			o("food", "အစားအသောက်", "Food", "food"),
			o("animal", "တိရစ္ဆာန်", "Animal", "animal"),
			o("vehicle", "ယာဉ် / မော်တော်ကား", "Vehicle", "vehicle"),
			o("architecture", "ဗိသုကာ / အတွင်းခန်း အလှဆင်မှု", "Architecture / interior", "architecture"),
			o("scene", "ရှုခင်း / သဘာဝမြင်ကွင်း", "Scene / setting", "scene"),
			o("character", "ဇာတ်ကောင် / ဖန်တစီ", "Character / fantasy", "character"),
			o("logo", "လိုဂို / စာသားဒီဇိုင်း (Logo)", "Logo / typography", "logo"),
		},
	}
}

// ---------------------------------------------------------------------------
// PERSON (Subject: Human) — the richest Detailed path.
// ---------------------------------------------------------------------------

func personNodes() []Node {
	const cPerson = "elements~=person"
	const cNew = "elements~=person AND person_hasphoto=no"   // no reference photo
	const cRef = "elements~=person AND person_hasphoto=yes"  // has reference photo

	return []Node{
		{
			ID: "person_hasphoto", Order: 100, Type: TypeSingle,
			Condition: cPerson,
			Question:  L10n{My: "ရည်ညွှန်းလိုသော လူ၏ နမူနာဓာတ်ပုံ ရှိပါသလား?", En: "Reference photo for the person?"},
			Options: []Option{
				o("yes", "ရှိပါသည် (ဓာတ်ပုံတင်မည်)", "Yes, upload", "yes"),
				o("no", "မရှိပါ", "No", "no"),
			},
		},
		{
			ID: "person_upload", Order: 101, Type: TypeImage,
			Condition: cRef,
			Question:  L10n{My: "ရည်ညွှန်းလိုသော လူ၏ ဓာတ်ပုံကို တင်ပါ", En: "Upload the person's reference photo"},
			Fragment:  "resembling the reference person",
		},

		// Identity preservation (only when a reference photo is provided).
		textNode("identity_preservation", 102, true, cRef,
			"မူရင်း ရုပ်သွင်ပြင်နှင့် မျက်နှာ ထိန်းသိမ်းမှု",
			"Identity preservation",
			"{value}",
			o("exact", "မူရင်း မျက်နှာသွင်ပြင် အတိအကျ ထိန်းသိမ်းရန်", "Keep exact face", "preserving the subject's exact facial identity"),
			o("face_outfit", "မျက်နှာသွင်ပြင် ထိန်းသိမ်းပြီး ဝတ်စုံပြောင်းရန်", "Keep face, change outfit", "keeping the exact face while changing the outfit"),
			o("face_hair", "မျက်နှာနှင့် ဆံပင်ပုံစံ အတိအကျ ထိန်းသိမ်းရန်", "Keep face & hair", "preserving the exact face and hairstyle"),
			o("younger", "မူရင်းရုပ်ကို ပိုမိုနုပျိုစေရန်", "Look younger", "preserving identity but looking younger"),
			o("older", "မူရင်းရုပ်ကို ပိုမိုရင့်ကျက်စေရန်", "Look older", "preserving identity but looking older"),
			o("light_stylize", "အနုပညာဆန်ဆန် အနည်းငယ် ပုံဖော်ရန်", "Lightly stylized", "preserving likeness with a light artistic stylization"),
			o("passport", "လက်တွေ့ဆန်ဆန် ရုပ်သွင်အတိအကျ ပုံဖော်ရန်", "True likeness", "an accurate, true-to-life likeness of the reference person"),
			o("expression_only", "မျက်နှာသွင်ပြင်မပြောင်းဘဲ အမူအရာသာ ပြောင်းရန်", "Change expression only", "keeping the identity, changing only the expression"),
		),

		{
			ID: "person_gender", Order: 104, Type: TypeSingle,
			Condition: cNew,
			Question:  L10n{My: "အမျိုးသား / အမျိုးသမီး?", En: "Male or female?"},
			Fragment:  "a {value}",
			Options: []Option{
				o("male", "အမျိုးသား", "Male", "man"),
				o("female", "အမျိုးသမီး", "Female", "woman"),
			},
		},

		// Demeanor & gesture — Myanmar-first poses/gestures.
		textNode("person_demeanor", 110, true, cPerson,
			"ဟန်ပန်နှင့် ကိုယ်အမူအရာ?", "Demeanor & gesture?",
			"{value}",
			o("respect", "လက်အုပ်ချီ ရှိခိုးဟန်", "Paying respect", "in a respectful gesture with palms together"),
			o("clasped", "ယဉ်ကျေးစွာ လက်အုပ်ချီ ရပ်နေဟန်", "Hands clasped", "standing with hands clasped politely"),
			o("offering", "လက်နှစ်ဖက်ဖြင့် ယဉ်ကျေးစွာ ကမ်းပေးနေဟန်", "Offering with both hands", "offering something with both hands"),
			o("graceful", "ယဉ်ကျေးကျက်သရေရှိစွာ ရပ်နေဟန်", "Standing gracefully", "standing gracefully and poised"),
			o("floor_sit", "ကြမ်းပြင်ပေါ်တွင် တင်ပျဉ်ခွေထိုင်နေဟန်", "Sitting on the floor", "sitting cross-legged on the floor"),
			o("umbrella", "ရိုးရာထီး ဆောင်း/ကိုင်ထားဟန်", "Holding an umbrella", "holding a traditional umbrella"),
			o("praying", "ဘုရားစေတီတွင် ဒူးထောက် ဆုတောင်းနေဟန်", "Praying at a pagoda", "kneeling in prayer at a pagoda"),
			o("dancing", "မြန်မာ့ရိုးရာ အက ကပြနေဟန်", "Traditional dance", "performing a graceful traditional dance"),
			o("carrying", "ခြင်းတောင်း ခေါင်းရွက်ထားဟန်", "Carrying on head", "carrying a basket balanced on the head"),
			o("waving", "နွေးထွေးစွာ လက်ပြနှုတ်ဆက်ဟန်", "Waving", "waving warmly"),
			o("thinking", "လေးနက်စွာ စဉ်းစားတွေးတောဟန်", "Thinking", "in a thoughtful, contemplative pose"),
			o("laughing", "ရွှင်လန်းစွာ ရယ်မောနေဟန်", "Laughing", "laughing joyfully"),
			o("confident", "ယုံကြည်မှုအပြည့်ဖြင့် ရပ်နေဟန်", "Confident", "standing in a confident pose"),
			o("candid", "သဘာဝကျကျ သက်သောင့်သက်သာ ဟန်ပန်", "Candid", "in a natural, candid moment"),
			o("arms_crossed", "လက်ပိုက်ရပ်နေဟန်", "Arms crossed", "standing with arms crossed"),
			o("looking_away", "အဝေးသို့ ငေးကြည့်နေဟန်", "Looking away", "gazing thoughtfully into the distance"),
			o("hand_on_hip", "ခါးထောက်ရပ်နေဟန်", "Hand on hip", "with a hand resting on the hip"),
			o("meditating", "ငြိမ်သက်စွာ တရားထိုင်နေဟန်", "Meditating", "sitting in serene meditation"),
			o("working", "အာရုံစိုက်၍ အလုပ်လုပ်နေဟန်", "Working", "focused while working"),
			o("dynamic", "တက်ကြွသော လှုပ်ရှားမှုဟန်", "Dynamic action", "in a dynamic action pose"),
		),

		// Facial expression.
		textNode("person_expression", 112, true, cPerson,
			"မျက်နှာ အမူအရာ?", "Facial expression?",
			"with a {value} expression",
			o("gentle_smile", "ယဉ်ကျေးညင်သာစွာ ပြုံးနေသော", "Gentle smile", "gentle, warm smile"),
			o("big_smile", "တောက်ပစွာ ပြုံးရွှင်နေသော", "Big smile", "bright, beaming"),
			o("serious", "တည်ငြိမ်အေးဆေးသော", "Serious", "calm and serious"),
			o("shy", "ရှက်ပြုံး ပြုံးနေသော", "Shy", "shy, bashful"),
			o("sad", "ဝမ်းနည်းနေသော", "Sad", "sad"),
			o("angry", "ဒေါသထွက်နေသော", "Angry", "angry"),
			o("surprised", "အံ့အားသင့်နေသော", "Surprised", "surprised"),
			o("proud", "ဂုဏ်ယူဝင့်ကြွားသော", "Proud", "proud"),
			o("dreamy", "စိတ်ကူးယဉ်ဆန်သော", "Dreamy", "dreamy"),
			o("determined", "စိတ်ပိုင်းဖြတ်မှု ပြတ်သားသော", "Determined", "determined"),
			o("laughing", "ပျော်ရွှင်စွာ ရယ်မောနေသော", "Laughing", "laughing"),
			o("neutral", "သာမန် သက်သောင့်သက်သာရှိသော", "Neutral", "neutral, relaxed"),
			o("crying", "မျက်ရည်ဝိုင်း ငိုကြွေးနေသော", "Tearful", "tearful"),
			o("mischief", "နောက်ပြောင် ချစ်စနိုး အမူအရာ", "Playful", "playful, mischievous"),
			o("serene", "အေးချမ်းကြည်လင်သော", "Serene", "serene"),
		),

		// Age.
		textNode("person_age", 120, true, cNew,
			"အသက်အရွယ်?", "Age?",
			"{value}",
			o("baby", "မွေးကင်းစ / ကလေးငယ်", "Baby", "a baby"),
			o("toddler", "လမ်းလျှောက်စ ကလေးငယ်", "Toddler", "a toddler"),
			o("child", "ကလေးအရွယ် (၅ - ၁၀ နှစ်)", "Child", "a young child around 8"),
			o("preteen", "ဆယ်ကျော်သက် အကြို (၁၀ - ၁၂ နှစ်)", "Preteen", "a preteen"),
			o("teen", "ဆယ်ကျော်သက်အရွယ်", "Teenager", "a teenager"),
			o("young20", "လူငယ်အရွယ် (အသက် ၂၀ ဝန်းကျင်)", "Early 20s", "a young adult in their early 20s"),
			o("late20", "လူရွယ်အရွယ် (အသက် ၂၅ - ၂၉ နှစ်)", "Late 20s", "an adult in their late 20s"),
			o("thirties", "လူလတ်ပိုင်း (အသက် ၃၀ ကျော်)", "30s", "an adult in their 30s"),
			o("forties", "လူလတ်ပိုင်း (အသက် ၄၀ ကျော်)", "40s", "a middle-aged person in their 40s"),
			o("fifties", "သက်ကြီးပိုင်း (အသက် ၅၀ ကျော်)", "50s", "a person in their 50s"),
			o("sixties", "ဘိုးဘွားအရွယ် (အသက် ၆၀ ကျော်)", "60s", "an older person in their 60s"),
			o("elderly", "သက်ကြီးရွယ်အို", "Elderly", "an elderly person"),
			o("veryold", "အလွန်သက်ကြီး (အသက် ၈၀ ကျော်)", "Very old", "a very old person in their 80s"),
		),

		// Height.
		textNode("person_height", 122, true, cNew,
			"အရပ်အမြင့်?", "Height?",
			"{value}",
			o("petite", "အရပ်ပုပု သေးသေး (~150cm)", "Petite", "of petite height"),
			o("short", "အရပ်အနည်းငယ်ပု (~155cm)", "Short", "of short height"),
			o("average", "အရပ်အလတ်စား (~165cm)", "Average", "of average height"),
			o("tallish", "အရပ်အသင့်အတင့်မြင့် (~175cm)", "Above average", "of above-average height"),
			o("tall", "အရပ်ရှည် (~185cm)", "Tall", "tall"),
			o("verytall", "အရပ်အလွန်ရှည် (~195cm)", "Very tall", "very tall"),
		),

		// Build / weight.
		textNode("person_build", 124, true, cNew,
			"ကိုယ်လုံးကိုယ်ပေါက် အချိုးအစား?", "Body build?",
			"with a {value} build",
			o("slim", "ပိန်သွယ်", "Slim", "slim"),
			o("slender", "သွယ်လျ", "Slender", "slender"),
			o("average", "ပုံမှန် အလတ်စား", "Average", "average"),
			o("athletic", "အားကစားသမား ခန္ဓာကိုယ်", "Athletic", "athletic"),
			o("toned", "အချိုးကျ ကြွက်သားရှိသော", "Toned", "toned"),
			o("muscular", "ကြွက်သားထွားကျိုင်းသော", "Muscular", "muscular"),
			o("curvy", "ကိုယ်လုံးကိုယ်ပေါက် ပြည့်ဖြိုးသော", "Curvy", "curvy"),
			o("plump", "ခန္ဓာကိုယ် ဝဝပြည့်ပြည့်", "Plump", "plump"),
			o("heavyset", "ခန္ဓာကိုယ် ထွားကျိုင်းသော", "Heavy-set", "heavy-set"),
			o("petite", "ခန္ဓာကိုယ် သေးသေးသွယ်သွယ်", "Petite", "petite"),
		),

		// Ethnicity & culture — Myanmar peoples first, then global.
		textNode("person_ethnicity", 126, true, cNew,
			"လူမျိုး နှင့် ယဉ်ကျေးမှု?", "Ethnicity & culture?",
			"a {value} person",
			o("bamar", "ဗမာလူမျိုး", "Bamar", "Bamar Burmese"),
			o("shan", "ရှမ်းလူမျိုး", "Shan", "Shan"),
			o("kachin", "ကချင်လူမျိုး", "Kachin", "Kachin"),
			o("kayin", "ကရင်လူမျိုး", "Kayin (Karen)", "Kayin Karen"),
			o("chin", "ချင်းလူမျိုး", "Chin", "Chin"),
			o("mon", "မွန်လူမျိုး", "Mon", "Mon"),
			o("rakhine", "ရခိုင်လူမျိုး", "Rakhine", "Rakhine"),
			o("kayah", "ကယားလူမျိုး", "Kayah", "Kayah"),
			o("pao", "ပအိုဝ်းလူမျိုး", "Pa-O", "Pa-O"),
			o("danu", "ဓနုလူမျိုး", "Danu", "Danu"),
			o("intha", "အင်းသားလူမျိုး", "Intha", "Intha"),
			o("wa", "ဝလူမျိုး", "Wa", "Wa"),
			o("naga", "နာဂလူမျိုး", "Naga", "Naga"),
			o("lisu", "လီဆူလူမျိုး", "Lisu", "Lisu"),
			o("eastasian", "အရှေ့အာရှတိုက်သား", "East Asian", "East Asian"),
			o("southasian", "တောင်အာရှတိုက်သား", "South Asian", "South Asian"),
			o("seasian", "အရှေ့တောင်အာရှတိုက်သား", "Southeast Asian", "Southeast Asian"),
			o("european", "ဥရောပတိုက်သား", "European", "European"),
			o("african", "အာဖရိကတိုက်သား", "African", "African"),
			o("middleeast", "အရှေ့အလယ်ပိုင်းသား", "Middle Eastern", "Middle Eastern"),
			o("latino", "လက်တင်အမေရိကတိုက်သား", "Latino", "Latino"),
			o("mixed", "သွေးနှော/ကပြား", "Mixed", "of mixed heritage"),
		),

		// Hair.
		textNode("person_hair", 128, true, cNew,
			"ဆံပင် ပုံစံနှင့် အရောင်?", "Hair (style / color)?",
			"with {value} hair",
			o("long_black", "ဆံပင်ရှည် နက်မှောင်", "Long black", "long black"),
			o("long_straight", "ဆံပင်ရှည် အဖြောင့်", "Long straight", "long straight"),
			o("short_black", "ဆံပင်တို အနက်ရောင်", "Short black", "short black"),
			o("bun", "ဆံထုံး ထုံးထားသော", "Hair in a bun", "tied in a bun"),
			o("trad_bun", "မြန်မာ့ရိုးရာဆံထုံး (ပန်းပန်ထားသော)", "Traditional bun", "in a traditional bun with flowers"),
			o("braided", "ကျစ်ဆံမြီး ကျစ်ထားသော", "Braided", "braided"),
			o("twin_braids", "ကျစ်ဆံမြီး နှစ်ဖက်ကျစ်ထားသော", "Twin braids", "in twin braids"),
			o("curly", "ဆံပင်ကောက်", "Curly", "curly"),
			o("wavy", "ဆံပင် လှိုင်းတွန့်", "Wavy", "wavy"),
			o("loose_curls", "ဆံပင် အကောက်ပြေပြေ", "Loose curls", "in loose curls"),
			o("ponytail", "ဆံပင် မြင်းမြီးစည်းထားသော", "Ponytail", "in a ponytail"),
			o("bob", "ဆံပင်တို ကုပ်ဝဲ (Bob)", "Short bob", "in a short bob"),
			o("bangs", "ဆံပင် ရှေ့ဆံချထားသော (Bangs)", "With bangs", "with bangs"),
			o("undercut", "ဘေးရိတ် ဆံပင်ပုံစံ (Undercut)", "Undercut", "in an undercut"),
			o("slicked", "ဆံပင် နောက်လှန်ဖီးထားသော", "Slicked back", "slicked back"),
			o("messy", "ဆံပင် အနည်းငယ် ဖရိုဖရဲဟန်", "Messy", "messy and tousled"),
			o("wet", "ဆံပင် ရေစိုဟန် (Wet look)", "Wet look", "in a wet-look style"),
			o("shaved", "ခေါင်းတုံး ရိတ်ထားသော", "Shaved head", "shaved"),
			o("monk", "ရဟန်း/သံဃာတော် ခေါင်းရိတ်ဟန်", "Monk's shaved head", "a clean-shaven monastic head"),
			o("grey", "ဆံပင်ဖြူ", "Grey", "grey"),
			o("silver", "ငွေရောင်ဆံပင်", "Silver", "silver"),
			o("brown", "ဆံပင် အညိုရောင်", "Brown", "brown"),
			o("blonde", "ဆံပင် ရွှေဝါရောင်", "Blonde", "blonde"),
			o("dyed", "ကာလာဆိုးထားသော ဆံပင်", "Dyed bright color", "brightly dyed"),
		),

		// Clothing — Myanmar traditional first.
		textNode("person_clothing", 130, true, cNew,
			"ဝတ်စုံနှင့် အဝတ်အစား?", "Clothing?",
			"wearing {value}",
			o("htamein", "မြန်မာရိုးရာ ထမီနှင့် အင်္ကျီ", "Htamein & blouse", "a traditional Burmese htamein and blouse"),
			o("longyi_shirt", "လုံချည်နှင့် ရှပ်အင်္ကျီ", "Longyi & shirt", "a longyi with a collared shirt"),
			o("acheik", "အချိတ်လုံချည် / ထမီ", "Acheik silk", "an acheik-patterned silk htamein"),
			o("taikpon", "တိုက်ပုံနှင့် ပုဆိုး", "Taikpon jacket", "a formal taikpon jacket over a longyi"),
			o("gaungbaung_set", "ခေါင်းပေါင်း အပါအဝင် မြန်မာဝတ်စုံအပြည့်", "Full ceremonial dress", "full Burmese ceremonial dress with a gaung baung"),
			o("shan", "ရှမ်း ရိုးရာဝတ်စုံ", "Shan dress", "a Shan traditional outfit"),
			o("kachin", "ကချင် ရိုးရာဝတ်စုံ", "Kachin dress", "a Kachin traditional costume"),
			o("chin", "ချင်း ရိုးရာဝတ်စုံ", "Chin dress", "a Chin traditional woven outfit"),
			o("kayin", "ကရင် ရိုးရာဝတ်စုံ", "Karen dress", "a Karen traditional dress"),
			o("rakhine", "ရခိုင် ရိုးရာဝတ်စုံ", "Rakhine dress", "a Rakhine traditional outfit"),
			o("wedding", "မြန်မာ့ရိုးရာ မင်္ဂလာဆောင်ဝတ်စုံ", "Wedding attire", "traditional Burmese wedding attire"),
			o("monk_robe", "ရဟန်း သင်္ကန်း", "Monk's robes", "saffron monastic robes"),
			o("nun_robe", "သီလရှင် ဝတ်စုံ", "Nun's robes", "pink Buddhist nun robes"),
			o("student", "အစိမ်း/အဖြူ ကျောင်းဝတ်စုံ", "School uniform", "a green-and-white school uniform"),
			o("shirt", "ရှပ်အင်္ကျီ အဖြူ", "White shirt", "a white shirt"),
			o("suit", "ခေတ်မီ ကုတ်အင်္ကျီဝတ်စုံ (Suit)", "Modern suit", "a modern suit"),
			o("dress", "အနောက်တိုင်း ဂါဝန်ရှည်", "Western dress", "an elegant dress"),
			o("casual", "တီရှပ်နှင့် ဂျင်းဘောင်းဘီ", "T-shirt & jeans", "a t-shirt and jeans"),
			o("hoodie", "ဟူးဒီ အင်္ကျီ (Hoodie)", "Hoodie", "a casual hoodie"),
			o("farmer", "လယ်သမား လုပ်ငန်းခွင်ဝတ်စုံ", "Farmer's clothes", "simple farmer's work clothes"),
			o("raincoat", "ခမောက်နှင့် မိုးကာဝတ်စုံ", "Rain gear", "a bamboo hat and rain cape"),
		),

		// Fabric detail.
		textNode("person_fabric", 132, true, cNew,
			"အထည်အလိပ်နှင့် ချည်သား အမျိုးအစား?", "Fabric detail?",
			"made of {value}",
			o("acheik", "အချိတ် ပိုးထည်", "Acheik silk", "acheik-patterned silk"),
			o("mandalay_silk", "မန္တလေး ပိုးထည်", "Mandalay silk", "fine Mandalay silk"),
			o("lotus_silk", "ကြာချည် ပိုးထည်", "Lotus silk", "rare lotus-stem silk"),
			o("cotton", "ရက်ကန်း ချည်ထည်", "Cotton", "handwoven cotton"),
			o("chin_weave", "ချင်း ရက်ကန်းထည်", "Chin woven cloth", "intricate Chin woven cloth"),
			o("kachin_weave", "ကချင် ရက်ကန်းထည်", "Kachin weave", "Kachin woven wool"),
			o("longyi_check", "ကွက်စိပ် ပုဆိုး/လုံချည်သား", "Checked longyi cloth", "checked longyi cloth"),
			o("velvet", "ကတ္တီပါသား", "Velvet", "soft velvet"),
			o("linen", "လင်နင် ချည်သားကြမ်း (Linen)", "Linen", "natural linen"),
			o("brocade", "ရွှေချည်ထိုး ပိုးထည်", "Gold brocade", "gold-threaded brocade"),
			o("embroidered", "လက်မှု ပန်းထိုးထည်", "Embroidered", "richly embroidered fabric"),
			o("denim", "ဂျင်းသား (Denim)", "Denim", "denim"),
			o("satin", "ဆာတင် ပိုးသားချော (Satin)", "Satin", "smooth satin"),
			o("wool", "သိုးမွှေးထည်", "Wool", "warm wool"),
		),

		// Accessories.
		textNode("person_accessories", 134, true, cPerson,
			"အသုံးအဆောင် ပစ္စည်းများ?", "Accessories?",
			"adorned with {value}",
			o("gaungbaung", "ခေါင်းပေါင်း", "Gaung baung", "a traditional gaung baung headdress"),
			o("thanaka", "သနပ်ခါး ပါးကွက်", "Thanaka", "thanaka paste on the cheeks"),
			o("gold_necklace", "ရွှေဆွဲကြိုး", "Gold necklace", "a gold necklace"),
			o("jade_bangle", "ကျောက်စိမ်း လက်ကောက်", "Jade bangle", "jade bangles"),
			o("ruby_earrings", "ပတ္တမြား နားဆွဲ", "Ruby earrings", "ruby earrings"),
			o("pearl", "ပုလဲသွယ် ဆွဲကြိုး", "Pearls", "a pearl string"),
			o("flower_hair", "ဆံပင်တွင် ပန်ထားသော ပန်း", "Flower in hair", "a flower tucked in the hair"),
			o("betel_box", "ရှေးရိုးရာ ယွန်းကွမ်းအစ်", "Betel box", "holding a lacquer betel box"),
			o("umbrella", "ပုသိမ်ထီး / ရိုးရာစက္ကူထီး", "Traditional umbrella", "a traditional paper umbrella"),
			o("basket", "ရက်လုပ်ထားသော ခြင်းတောင်း", "Basket", "a woven basket"),
			o("glasses", "မျက်မှန်", "Glasses", "eyeglasses"),
			o("sunglasses", "နေကာမျက်မှန်", "Sunglasses", "sunglasses"),
			o("watch", "လက်ပတ်နာရီ", "Watch", "a wristwatch"),
			o("hat", "ဦးထုပ်", "Hat", "a hat"),
			o("conical_hat", "မြန်မာ့ရိုးရာ ခမောက်", "Conical hat", "a bamboo conical hat"),
			o("scarf", "လည်စည်းပဝါ", "Scarf", "a scarf"),
			o("shoulder_bag", "ရှမ်းလွယ်အိတ် / ရိုးရာလွယ်အိတ်", "Shoulder bag", "a woven shoulder bag"),
			o("headphones", "နားကြပ်", "Headphones", "headphones"),
			o("prayer_beads", "စိတ်ပုတီး", "Prayer beads", "prayer beads"),
			o("crown", "ရွှေရောင် မကိုဋ်သရဖူ", "Crown", "an ornate crown"),
		),

		// Makeup.
		textNode("person_makeup", 136, true, cNew,
			"မိတ်ကပ် ပြင်ဆင်မှုပုံစံ?", "Makeup style?",
			"with {value} makeup",
			o("natural", "သဘာဝဆန်ဆန် မိတ်ကပ် (Natural)", "Natural", "natural"),
			o("thanaka", "သနပ်ခါး သီးသန့်", "Thanaka only", "traditional thanaka-only"),
			o("bridal", "မင်္ဂလာဆောင် သတို့သမီး မိတ်ကပ်", "Bridal", "elegant bridal"),
			o("glam", "ခမ်းနားတောက်ပသော မိတ်ကပ် (Glam)", "Glamorous", "glamorous"),
			o("bold_lips", "နှုတ်ခမ်းနီ ရင့်ရင့်ဆိုးထားသော", "Bold red lips", "with bold red lips"),
			o("smoky", "မျက်လုံးအလှ smoky စတိုင်", "Smoky eyes", "smoky-eyed"),
			o("dewy", "စိုပြေဝင်းပသော မိတ်ကပ် (Dewy glow)", "Dewy", "dewy, glowing"),
			o("matte", "မပြောင်လက်သော မိတ်ကပ် (Matte)", "Matte", "soft matte"),
			o("stage", "ဇာတ်သဘင် မိတ်ကပ်", "Stage makeup", "dramatic traditional stage"),
			o("festival", "ရောင်စုံ ပွဲတော်မိတ်ကပ်", "Festival", "colorful festival"),
			o("nomakeup", "မိတ်ကပ် မလိမ်းထားသော ရုပ်သွင်", "No makeup", "bare, no-makeup"),
			o("gothic", "Gothic စတိုင် မိတ်ကပ်", "Gothic", "dark gothic"),
		),

		// Festivals & ceremonies.
		textNode("person_festival", 140, true, cPerson,
			"ပွဲလမ်းသဘင်နှင့် အခမ်းအနား?", "Festival or ceremony?",
			"during {value}",
			o("thingyan", "မြန်မာ့နှစ်သစ်ကူး မဟာသင်္ကြန်ပွဲတော်", "Thingyan water festival", "the Thingyan water festival"),
			o("thadingyut", "သီတင်းကျွတ် မီးထွန်းပွဲတော်", "Thadingyut festival of lights", "the Thadingyut festival of lights"),
			o("tazaungdaing", "တန်ဆောင်တိုင် မီးထွန်းပွဲတော်", "Tazaungdaing", "the Tazaungdaing lights festival"),
			o("shinbyu", "ရှင်ပြု အလှူတော်မင်္ဂလာ", "Novitiation (Shinbyu)", "a Shinbyu novitiation ceremony"),
			o("wedding", "မင်္ဂလာဆောင် အခမ်းအနား", "Wedding", "a traditional wedding"),
			o("pagoda_festival", "ဘုရားပွဲတော်", "Pagoda festival", "a pagoda festival"),
			o("harvest", "ကောက်သစ်စားပွဲ / ကောက်သိမ်းပွဲ", "Harvest festival", "a harvest festival"),
			o("manaw", "ကချင် မနောပွဲတော်", "Kachin Manaw", "the Kachin Manaw festival"),
			o("karen_ny", "ကရင် နှစ်သစ်ကူးပွဲတော်", "Karen New Year", "the Karen New Year"),
			o("boat_race", "အင်းလေး ဖောင်တော်ဦး လှေပြိုင်ပွဲ", "Boat race", "the Inle boat-racing festival"),
			o("balloon", "တောင်ကြီး တန်ဆောင်တိုင် မီးပုံးပျံပွဲ", "Balloon festival", "the Taunggyi balloon festival"),
			o("alms", "နံနက်ခင်း ဆွမ်းလောင်းလှူပွဲ", "Alms-giving", "a morning alms-giving"),
			o("nat_pwe", "ရိုးရာ နတ်ပွဲတော်", "Nat pwe", "a nat spirit festival"),
			o("new_year", "နှစ်သစ်ကူး ပွဲတော်", "New Year", "a New Year celebration"),
			o("birthday", "မွေးနေ့ပွဲ အခမ်းအနား", "Birthday", "a birthday celebration"),
		),
	}
}

// ---------------------------------------------------------------------------
// OBJECT (Subject: Object)
// ---------------------------------------------------------------------------

func objectNodes() []Node {
	const cObj = "elements~=object"
	const cObjNew = "elements~=object AND object_hasphoto=no"

	return []Node{
		{
			ID: "object_hasphoto", Order: 200, Type: TypeSingle,
			Condition: cObj,
			Question:  L10n{My: "ရည်ညွှန်းလိုသော ပစ္စည်း၏ နမူနာဓာတ်ပုံ ရှိပါသလား?", En: "Reference photo for the object?"},
			Options: []Option{
				o("yes", "ရှိပါသည် (ဓာတ်ပုံတင်မည်)", "Yes, upload", "yes"),
				o("no", "မရှိပါ", "No", "no"),
			},
		},
		{
			ID: "object_upload", Order: 201, Type: TypeImage,
			Condition: "elements~=object AND object_hasphoto=yes",
			Question:  L10n{My: "ရည်ညွှန်းလိုသော ပစ္စည်း၏ ဓာတ်ပုံကို တင်ပါ", En: "Upload the object's reference photo"},
			Fragment:  "resembling the reference object",
		},

		textNode("object_what", 210, false, cObjNew,
			"မည်သည့် ပစ္စည်း/အရာဝတ္ထုလဲ?", "What object is it?",
			"{value}",
			o("teapot", "ရှေးဟောင်း ရေနွေးအိုး", "Vintage teapot", "a vintage teapot"),
			o("lacquerware", "မြန်မာ့ရိုးရာ ယွန်းထည်", "Lacquerware", "a piece of Burmese lacquerware"),
			o("bowl", "သံဃာတော် သပိတ်", "Alms bowl", "a monk's alms bowl"),
			o("umbrella", "မြန်မာ့ရိုးရာ စက္ကူထီး", "Paper umbrella", "a traditional paper umbrella"),
			o("harp", "မြန်မာ့ရိုးရာ စောင်းကောက်", "Burmese harp", "a Burmese saung harp"),
			o("drum", "မြန်မာ့ရိုးရာ ဗုံ", "Drum", "a traditional drum"),
			o("puppet", "မြန်မာ့ရိုးရာ ရုပ်သေးရုပ်", "Marionette", "a Burmese marionette puppet"),
			o("gong", "ကြေးမောင်း", "Gong", "a bronze gong"),
			o("betel_box", "ယွန်းကွမ်းအစ်", "Betel box", "a lacquer betel box"),
			o("bell", "ဘုရား ခေါင်းလောင်း", "Temple bell", "a temple bell"),
			o("phone", "စမတ်ဖုန်း", "Smartphone", "a smartphone"),
			o("coffee", "ကော်ဖီခွက်", "Cup of coffee", "a cup of coffee"),
			o("vase", "ပန်းအိုး", "Flower vase", "a flower vase"),
			o("book", "ရှေးဟောင်း စာအုပ်", "Old book", "an old book"),
			o("chair", "သစ်သား ကုလားထိုင်", "Wooden chair", "a wooden chair"),
			o("bicycle", "စက်ဘီး", "Bicycle", "a bicycle"),
			o("guitar", "ဂစ်တာ", "Guitar", "a guitar"),
			o("car", "မော်တော်ကား", "Car", "a car"),
			o("watch", "လက်ပတ်နာရီ", "Watch", "a wristwatch"),
			o("lamp", "ဆီမီးအိမ်", "Oil lamp", "an oil lamp"),
		),

		textNode("object_material", 212, true, cObj,
			"ကုန်ကြမ်း ပစ္စည်းအမျိုးအစား?", "Material / texture?",
			"made of {value}",
			o("teak", "ကျွန်းသစ်", "Teak wood", "teak wood"),
			o("bamboo", "ဝါးသား", "Bamboo", "bamboo"),
			o("lacquer", "ယွန်းထည်", "Lacquer", "lacquer"),
			o("bronze", "ကြေးဝါ / ကြေးညို", "Bronze", "bronze"),
			o("gold", "ရွှေသား", "Gold", "gold"),
			o("silver", "ငွေသား", "Silver", "silver"),
			o("jade", "ကျောက်စိမ်း", "Jade", "jade"),
			o("ceramic", "ကြွေထည်", "Ceramic", "ceramic"),
			o("clay", "ရွှံ့စေး / မြေထည်", "Clay", "terracotta clay"),
			o("glass", "ဖန်သား", "Glass", "glass"),
			o("metal", "သတ္တုသား", "Metal", "brushed metal"),
			o("leather", "သားရေထည်", "Leather", "leather"),
			o("cotton", "ရက်ကန်း ချည်ထည်", "Woven cloth", "woven cloth"),
			o("stone", "ကျောက်ဆစ်ထည်", "Stone", "carved stone"),
			o("plastic", "ပလတ်စတစ်", "Plastic", "plastic"),
		),

		textNode("object_color", 214, true, cObj,
			"ပစ္စည်း၏ အရောင်?", "Color?",
			"in {value}",
			o("red", "အနီရောင်", "Red", "deep red"),
			o("gold", "ရွှေရောင်", "Gold", "gold"),
			o("black", "အနက်ရောင်", "Black", "black"),
			o("white", "အဖြူရောင်", "White", "white"),
			o("green", "အစိမ်းရောင်", "Green", "green"),
			o("blue", "အပြာရောင်", "Blue", "blue"),
			o("brown", "အညိုရောင်", "Brown", "brown"),
			o("teal", "စိမ်းပြာရောင်", "Teal", "teal"),
			o("orange", "လိမ္မော်ရောင်", "Orange", "orange"),
			o("pink", "ပန်းရောင်", "Pink", "pink"),
			o("purple", "ခရမ်းရောင်", "Purple", "purple"),
			o("silver", "ငွေရောင်", "Silver", "silver"),
			o("multicolor", "ရောင်စုံ", "Multicolor", "vibrant multicolor"),
		),

		textNode("object_condition", 216, true, cObj,
			"ပစ္စည်း၏ အခြေအနေနှင့် သွင်ပြင်?", "Condition / era?",
			"that looks {value}",
			o("antique", "ရှေးဟောင်း လက်ရာ", "Antique", "antique and aged"),
			o("brandnew", "အသစ်စက်စက်", "Brand new", "brand new"),
			o("worn", "အိုဟောင်း နွမ်းနယ်သော", "Worn", "worn and weathered"),
			o("polished", "အရောင်တင် တောက်ပြောင်သော", "Polished", "freshly polished"),
			o("rustic", "ရိုးရိုးရှင်းရှင်း လက်မှုလက်ရာ", "Rustic", "rustic and handmade"),
			o("ornate", "ခမ်းနားစွာ အလှဆင်ထားသော", "Ornate", "ornately decorated"),
			o("broken", "ကျိုးပဲ့ အက်ကွဲနေသော", "Broken", "cracked and broken"),
			o("futuristic", "ခေတ်လွန် အနာဂတ်ဆန်သော", "Futuristic", "sleek and futuristic"),
		),
	}
}

// ---------------------------------------------------------------------------
// ANIMAL (Subject: Animal) — new subject.
// ---------------------------------------------------------------------------

func animalNodes() []Node {
	const cAni = "elements~=animal"

	return []Node{
		textNode("animal_what", 300, false, cAni,
			"မည်သည့် တိရစ္ဆာန်လဲ?", "What animal is it?",
			"{value}",
			o("elephant", "ဆင်", "Elephant", "an elephant"),
			o("white_elephant", "ဆင်ဖြူတော်", "White elephant", "a sacred white elephant"),
			o("buffalo", "ကျွဲ", "Water buffalo", "a water buffalo"),
			o("cow", "နွား", "Cow", "a cow"),
			o("tiger", "ကျား", "Tiger", "a tiger"),
			o("peacock", "ဥဒေါင်း", "Peacock", "a dancing peacock"),
			o("hintha", "ဟင်္သာငှက်", "Hintha bird", "a hintha (hamsa) bird"),
			o("cat", "ကြောင်", "Cat", "a cat"),
			o("dog", "ခွေး", "Dog", "a dog"),
			o("python", "စပါးအုံးမြွေ", "Python", "a Burmese python"),
			o("monkey", "မျောက်", "Monkey", "a monkey"),
			o("rooster", "ကြက်ဖ", "Rooster", "a rooster"),
			o("parrot", "ကြက်တူရွေး", "Parrot", "a parrot"),
			o("fish", "ငါး", "Fish", "a fish"),
			o("horse", "မြင်း", "Horse", "a horse"),
			o("goat", "ဆိတ်", "Goat", "a goat"),
			o("deer", "သမင်", "Deer", "a deer"),
			o("owl", "ဇီးကွက်", "Owl", "an owl"),
			o("butterfly", "လိပ်ပြာ", "Butterfly", "a butterfly"),
			o("dragon", "တန်ခိုးရှင် နဂါး", "Dragon (naga)", "a mythical naga dragon"),
		),

		textNode("animal_appearance", 310, true, cAni,
			"တိရစ္ဆာန်၏ အရောင်နှင့် သွင်ပြင်?", "Color / breed?",
			"that is {value}",
			o("black", "အနက်ရောင်", "Black", "black"),
			o("white", "အဖြူရောင်", "White", "white"),
			o("brown", "အညိုရောင်", "Brown", "brown"),
			o("golden", "ရွှေရောင်", "Golden", "golden"),
			o("grey", "မီးခိုးရောင်", "Grey", "grey"),
			o("spotted", "အစက်အပြောက် ပါသော", "Spotted", "spotted"),
			o("striped", "ကျားသစ်စင်း/အစင်းကြောင်း ပါသော", "Striped", "striped"),
			o("colorful", "ရောင်စုံ တောက်ပသော", "Colorful", "brightly colored"),
			o("fluffy", "အမွှေးဖွဖွ ထူထူ", "Fluffy", "fluffy"),
			o("majestic", "ခမ်းနားထည်ဝါသော", "Majestic", "large and majestic"),
			o("baby", "တိရစ္ဆာန် သားပေါက်လေး", "Baby", "a baby animal"),
		),

		textNode("animal_action", 312, true, cAni,
			"တိရစ္ဆာန် ဘာလုပ်နေသလဲ?", "What is it doing?",
			"{value}",
			o("standing", "ငြိမ်သက်စွာ ရပ်နေသော", "Standing", "standing calmly"),
			o("running", "အရှိန်ဖြင့် ပြေးလွှားနေသော", "Running", "running"),
			o("resting", "အေးချမ်းစွာ အနားယူနေသော", "Resting", "resting"),
			o("eating", "အစာစားနေသော", "Eating", "grazing"),
			o("drinking", "ရေသောက်နေသော", "Drinking", "drinking water"),
			o("flying", "ပျံသန်းနေသော", "Flying", "flying"),
			o("swimming", "ရေကူးနေသော", "Swimming", "swimming"),
			o("playing", "ဆော့ကစားနေသော", "Playing", "playing"),
			o("bathing", "မြစ်ထဲ ရေချိုးနေသော", "Bathing", "bathing in a river"),
			o("working", "သစ်ဆွဲ/အလုပ်လုပ်နေသော", "Working", "hauling logs"),
			o("sleeping", "အိပ်ပျော်နေသော", "Sleeping", "sleeping"),
			o("roaring", "ဟိန်းဟောက်နေသော", "Roaring", "roaring"),
		),
	}
}

// ---------------------------------------------------------------------------
// SCENE (Subject: Scene) + background-when-no-scene.
// ---------------------------------------------------------------------------

func sceneNodes() []Node {
	const cScene = "elements~=scene"

	locationPills := []Option{
		o("shwedagon", "ရွှေတိဂုံ စေတီတော်ကြီး", "Shwedagon Pagoda", "at the Shwedagon Pagoda"),
		o("bagan", "ပုဂံ ရှေးဟောင်းဘုရားများ", "Bagan temples", "among the temples of Bagan"),
		o("inle", "အင်းလေးကန်", "Inle Lake", "on Inle Lake"),
		o("ubein", "ဦးပိန် တံတား", "U Bein Bridge", "on the U Bein teak bridge"),
		o("mandalay_palace", "မန္တလေး နန်းတွင်းမြို့ရိုး", "Mandalay Palace", "at the Mandalay royal palace"),
		o("monastery", "ကျေးရွာ ဘုန်းတော်ကြီးကျောင်း", "Monastery", "in a village monastery"),
		o("teashop", "မြန်မာ့ရိုးရာ လက်ဖက်ရည်ဆိုင်", "Tea shop", "in a cozy tea shop"),
		o("market", "စည်ကားသော ဈေးမြင်ကွင်း", "Market", "in a bustling market"),
		o("village", "အေးချမ်းသော ကျေးလက်ရွာ", "Village", "in a small village"),
		o("paddy", "စိမ်းလန်းသော စပါးခင်းကြီး", "Rice paddy", "in green rice paddies"),
		o("bamboo_house", "ကျေးလက် ဝါးတဲအိမ်", "Bamboo house", "in a bamboo stilt house"),
		o("mountain", "မြူဆိုင်းနေသော တောင်တန်းများ", "Mountains", "in misty mountains"),
		o("beach", "ငပလီ ပင်လယ်ကမ်းခြေ", "Beach", "on a quiet beach"),
		o("river", "ဧရာဝတီ မြစ်ကမ်းဘေး", "Riverside", "beside the Irrawaddy river"),
		o("city", "စည်ကားသော မြို့ပြလမ်းမ", "City street", "on a busy city street"),
		o("studio", "ဓာတ်ပုံ စတူဒီယို", "Studio", "in a photo studio"),
		o("garden", "သာယာသော ပန်းဥယျာဉ်", "Garden", "in a lush garden"),
		o("forest", "စိမ်းလန်းသော သစ်တောနက်", "Forest", "in a dense forest"),
		o("waterfall", "သဘာဝ ရေတံခွန်", "Waterfall", "by a waterfall"),
		o("cafe", "ခေတ်မီ ကဖေးဆိုင်", "Modern cafe", "in a modern cafe"),
	}

	return []Node{
		textNode("scene_location", 400, false, cScene,
			"နေရာနှင့် နောက်ခံ ရှုခင်း?", "Location and background?",
			"{value}", locationPills...),

		// Background when the user did NOT pick a scene element.
		textNode("background", 410, false, "elements!~=scene",
			"မည်သို့သော နောက်ခံမျိုး လိုချင်ပါသလဲ?", "What background?",
			"in {value}",
			o("room", "နွေးထွေးသော အခန်းငယ်", "Cozy room", "a cozy little room"),
			o("studio", "ရိုးရှင်းသော စတူဒီယို နောက်ခံ", "Studio backdrop", "a plain studio backdrop"),
			o("garden", "ဝါးတားတား ပန်းဥယျာဉ် နောက်ခံ", "Blurred garden", "a blurred garden"),
			o("dark", "အမှောင်ရိပ် နောက်ခံ", "Dark", "a dark background"),
			o("white", "အဖြူရောင် သန့်သန့် နောက်ခံ", "White", "a clean white background"),
			o("bokeh", "ဝေဝါး အလင်းပွင့်များ (Bokeh lights)", "Bokeh lights", "soft bokeh lights"),
			o("pagoda", "ရွှေရောင် စေတီပုထိုး နောက်ခံ", "Pagoda backdrop", "a golden pagoda backdrop"),
			o("paddy", "စိမ်းလန်းသော စပါးခင်း နောက်ခံ", "Rice field", "a green rice field"),
			o("market", "စည်ကားသော ဈေးမြင်ကွင်း နောက်ခံ", "Market", "a lively market backdrop"),
			o("sunset", "ဆည်းဆာ နေဝင်ချိန် ကောင်းကင်ယံ", "Sunset sky", "a warm sunset sky"),
			o("gradient", "အရောင်ပြေး နောက်ခံ (Gradient)", "Gradient", "a smooth color gradient"),
			o("texture", "အစင်းအကြောပါ နံရံနောက်ခံ (Textured wall)", "Textured wall", "a textured wall"),
		),

		{
			ID: "scene_weather", Order: 420, Type: TypeSingle, Advanced: true,
			Condition: cScene,
			Question:  L10n{My: "ရာသီဥတု အခြေအနေ?", En: "Weather?"},
			Fragment:  "{value} weather",
			Options: []Option{
				o("clear", "သာယာကြည်လင်သော နေ့", "Clear", "clear"),
				o("cloudy", "တိမ်ထူထပ်သော နေ့", "Cloudy", "cloudy"),
				o("rain", "မိုးသည်းထန်စွာ ရွာသွန်းနေသော", "Rainy", "rainy monsoon"),
				o("fog", "မြူဆိုင်းနေသော", "Foggy", "foggy"),
				o("storm", "မုန်တိုင်းထန်သော", "Stormy", "stormy"),
			},
		},
	}
}

// ---------------------------------------------------------------------------
// SHARED TAIL: time & light, mood, then "Camera and Retouch" + quality.
// These appear for every subject in Detailed mode.
// ---------------------------------------------------------------------------

// finish selects which finishing questions a subject receives. Each subject
// gets its OWN finishing nodes (gated by its condition), so no question ever
// appears for a subject it doesn't suit — Architecture is never asked for a
// "mood", and a Logo only gets aspect + quality. (Option B: independent tails.)
type finish struct {
	light, mood, color, studio, camera, style, skin, quality, aspect, details bool
}

// finishingNodes builds a subject's tailored finishing block, all gated by
// [cond] and namespaced by [prefix] so ids never collide across subjects.
func finishingNodes(prefix, cond string, base int, f finish) []Node {
	id := func(s string) string { return prefix + "_fin_" + s }
	var out []Node
	ord := base
	add := func(name, qMy, qEn, frag string, opts []Option) {
		out = append(out, textNode(id(name), ord, true, cond, qMy, qEn, frag, opts...))
		ord += 2
	}
	if f.light {
		add("light", "အလင်းရောင်နှင့် အချိန်?", "Lighting / time?", "{value}", finLight())
	}
	if f.mood {
		add("mood", "ရုပ်ပုံ ခံစားမှုရသ (Mood)?", "Mood?", "with a {value} mood", finMood())
	}
	if f.color {
		add("color", "ကာလာ တိုနင် (Color Grading)?", "Color grading?", "{value} color grading", finColor())
	}
	if f.studio {
		add("studio", "စတူဒီယို အလင်းပေးစနစ်?", "Studio lighting?", "shot with {value}", finStudio())
	}
	if f.camera {
		add("camera", "ကင်မရာ ရိုက်ကွက်ထောင့်?", "Camera angle?", "{value}", finCamera())
	}
	if f.style {
		add("style", "ရုပ်ပုံ အနုပညာစတိုင် (Style)?", "Visual style?", "{value}", finStyle())
	}
	if f.skin {
		add("skin", "အသားအရေ ပြင်ဆင်မှု (Skin retouch)?", "Skin retouch?", "with {value} skin", finSkin())
	}
	if f.quality {
		add("quality", "ရုပ်ပုံ အရည်အသွေး?", "Quality?", "{value}", finQuality())
	}
	if f.aspect {
		out = append(out, Node{
			ID: id("aspect"), Order: ord, Type: TypeSingle, Advanced: true, Condition: cond,
			Question: L10n{My: "ရုပ်ပုံ အချိုးအစား (Aspect Ratio)?", En: "Aspect ratio?"},
			Fragment: "{value} aspect ratio",
			Options:  finAspect(),
		})
		ord += 2
	}
	if f.details {
		add("details", "အပိုထပ်ဆောင်း ဖြည့်စွက်ချက် (မဖြစ်မနေ မလိုပါ)?", "Extra details? (optional)", "{value}", finDetails())
	}
	return out
}

func finLight() []Option {
	return []Option{
		o("golden", "နေဝင်ရီတရော ရွှေရောင်အလင်း (Golden hour)", "Golden hour", "in warm golden-hour light"),
		o("dawn", "အရုဏ်ဦး မြူခိုးအလင်း", "Misty dawn", "in a misty dawn"),
		o("morning", "နံနက်ခင်း အလင်းနု", "Morning", "in soft morning light"),
		o("midday", "နေ့လယ်ခင်း နေရောင်ခြည်", "Midday sun", "under bright midday sun"),
		o("bluehour", "နေဝင်ရီ ညနေမှောင်ရီအလင်း (Blue hour)", "Blue hour", "in cool blue-hour light"),
		o("sunset", "ဆည်းဆာ နေဝင်ချိန်အလင်း", "Sunset", "at a colorful sunset"),
		o("night", "ညဘက် အမှောင်ရိပ်", "Night", "at night"),
		o("candle", "ဖယောင်းတိုင် မီးရောင်", "Candlelight", "by warm candlelight"),
		o("oil_lamp", "ရိုးရာ ဆီမီးရောင်", "Oil-lamp glow", "in the glow of oil lamps"),
		o("festival", "ရောင်စုံ ပွဲတော်မီးရောင်များ", "Festival lights", "amid colorful festival lights"),
		o("neon", "နီယွန် မီးရောင်", "Neon", "in neon light"),
		o("studio", "စတူဒီယို အလင်းရောင်", "Studio light", "with clean studio lighting"),
		o("soft", "နူးညံ့ပျံ့နှံ့သော အလင်း", "Soft light", "in soft diffused light"),
		o("dramatic", "အလင်းအမှောင် ကွဲပြားထင်ရှားသော", "Dramatic", "in dramatic contrasty light"),
		o("backlit", "အနောက်ဘက်မှ ထိုးသောအလင်း (Backlit)", "Backlit", "backlit with a rim glow"),
		o("overcast", "မိုးအုံ့မှိုင်းသော အလင်း", "Overcast", "under soft overcast light"),
	}
}

func finMood() []Option {
	return []Option{
		o("calm", "ငြိမ်သက်အေးဆေးသော", "Calm", "calm"),
		o("joyful", "ရွှင်လန်းတက်ကြွသော", "Joyful", "joyful"),
		o("nostalgic", "အတိတ်ကို သတိရလွမ်းဆွတ်ဖွယ်", "Nostalgic", "nostalgic"),
		o("peaceful", "အေးချမ်းသာယာသော", "Peaceful", "peaceful"),
		o("dramatic", "ဒရာမာဆန်သော ခံစားမှု", "Dramatic", "dramatic"),
		o("mysterious", "လျှို့ဝှက်ဆန်းကြယ်သော", "Mysterious", "mysterious"),
		o("romantic", "ချစ်စဖွယ် ကြည်နူးဖွယ်ရာ", "Romantic", "romantic"),
		o("energetic", "တက်ကြွလန်းဆန်းသော", "Energetic", "energetic"),
		o("melancholic", "ဝမ်းနည်းဆွေးမြေ့ဖွယ်", "Melancholic", "melancholic"),
		o("spiritual", "ကြည်ညိုသဒ္ဓါပွားဖွယ် ဘာသာရေးဆန်သော", "Spiritual", "spiritual"),
		o("festive", "ပွဲတော်ဆန်ဆန် ပျော်ရွှင်ဖွယ်", "Festive", "festive"),
		o("epic", "ခမ်းနားထည်ဝါသော", "Epic", "epic and grand"),
		o("cozy", "နွေးထွေးသက်သောင့်သက်သာရှိသော", "Cozy", "cozy"),
		o("moody", "မှိုင်းညို့ဆန်းကြယ်သော", "Moody", "moody"),
	}
}

func finColor() []Option {
	return []Option{
		o("warm_film", "နွေးထွေးသော ဖလင်ကာလာ (Warm film)", "Warm film", "warm film"),
		o("teal_orange", "ရုပ်ရှင်ဆန်သော အပြာနှင့် လိမ္မော်ရောင်ပြေး (Teal & Orange)", "Teal & orange", "cinematic teal-and-orange"),
		o("vintage", "ခေတ်ဟောင်း ဖလင်ကာလာ (Vintage Kodak)", "Vintage", "vintage Kodak film"),
		o("moody", "အရောင်မှိန်မှိုင်းသော (Muted moody)", "Muted moody", "muted, moody desaturated"),
		o("vibrant", "တောက်ပစိုပြည်သော အရောင် (Vibrant)", "Vibrant", "punchy vibrant"),
		o("bw", "ဂန္ထဝင် အဖြူအမည်း (Black & White)", "Black & white", "classic black-and-white"),
		o("sepia", "ခေတ်ဟောင်း အညိုရောင် (Sepia)", "Sepia", "warm sepia"),
		o("pastel", "နုညံ့သော အရောင်များ (Pastel)", "Pastel", "soft pastel"),
		o("golden", "နွေးထွေးသော ရွှေရောင်လွှမ်း (Golden warm)", "Golden warm", "golden warm"),
		o("cool", "အေးမြသော အပြာရောင်လွှမ်း (Cool blue)", "Cool blue", "cool blue"),
		o("filmic", "ရုပ်ရှင်ဆန်သော ကာလာ (Filmic)", "Filmic", "rich filmic"),
	}
}

func finStudio() []Option {
	return []Option{
		o("softbox", "Softbox ပျံ့နှံ့အလင်း", "Softbox", "a large softbox"),
		o("threepoint", "သုံးမျက်နှာ အလင်းပေးစနစ် (Three-point)", "Three-point", "a three-point lighting setup"),
		o("ring", "Ring Light စက်ဝိုင်းမီး", "Ring light", "a ring light"),
		o("window", "ပြတင်းပေါက်မှ သဘာဝအလင်း", "Window light", "natural window light"),
		o("rim", "အနားသတ် ရောင်ပြေးအလင်း (Rim light)", "Rim light", "strong rim lighting"),
		o("highkey", "လင်းလက်တောက်ပသော အလင်း (High-key)", "High-key", "bright high-key lighting"),
		o("lowkey", "အမှောင်ရိပ်ဆန်သော အလင်း (Low-key)", "Low-key", "moody low-key lighting"),
		o("reflector", "ရွှေရောင် ရောင်ပြန်အလင်း (Reflector fill)", "Reflector fill", "a golden reflector fill"),
	}
}

func finCamera() []Option {
	return []Option{
		o("eye", "မျက်လုံးတစ်ဆုံး အမြင့်ရိုက်ချက် (Eye-level)", "Eye-level", "shot at eye level"),
		o("low", "အောက်ခြေအနိမ့်မှ မော့ရိုက်ချက် (Low angle)", "Low angle", "from a low angle"),
		o("high", "အထက်အမြင့်မှ စောင်းရိုက်ချက် (High angle)", "High angle", "from a high angle"),
		o("birdseye", "အပေါ်စီး ငှက်မြင်ကွင်း (Bird's-eye)", "Bird's-eye", "from a bird's-eye view"),
		o("wormseye", "မြေပြင်ကပ် အောက်တည့်တည့်မှ မော့ရိုက်ချက် (Worm's-eye)", "Worm's-eye", "from a worm's-eye view"),
		o("overhead", "အပေါ်တည့်တည့်မှ အောက်သို့ရိုက်ချက် (Overhead)", "Overhead", "directly overhead"),
		o("closeup", "အနီးကပ် ရိုက်ချက် (Close-up)", "Close-up", "in a tight close-up"),
		o("portrait", "လူပုံတူ ဓာတ်ပုံရိုက်ချက် (Portrait)", "Portrait", "a portrait framing"),
		o("wide", "ရှုခင်း မြင်ကွင်းကျယ် ရိုက်ချက် (Wide shot)", "Wide shot", "a wide establishing shot"),
		o("overshoulder", "ပခုံးကျော် ရိုက်ချက် (Over-the-shoulder)", "Over-the-shoulder", "an over-the-shoulder shot"),
	}
}

func finStyle() []Option {
	return []Option{
		o("photoreal", "လက်တွေ့ ဓာတ်ပုံအစစ်ဆန်သော (Photorealistic)", "Photorealistic", "photorealistic"),
		o("cinematic", "ရုပ်ရှင်ဆန်ဆန် ပုံဖော်မှု (Cinematic)", "Cinematic", "cinematic"),
		o("documentary", "မှတ်တမ်းတင် ဓာတ်ပုံစတိုင် (Documentary)", "Documentary", "documentary photography"),
		o("portrait", "စတူဒီယို ပုံတူဓာတ်ပုံ (Studio portrait)", "Studio portrait", "a studio portrait"),
		o("filmphoto", "၃၅ မမ ဖလင်ဓာတ်ပုံ (35mm Film)", "Film photo", "35mm film photography"),
		o("anime", "အန်နီမေး စတိုင် (Anime)", "Anime", "anime style"),
		o("watercolor", "ရေဆေးပန်းချီ လက်ရာ (Watercolor)", "Watercolor", "watercolor painting"),
		o("oil", "ဆီဆေးပန်းချီ လက်ရာ (Oil painting)", "Oil painting", "oil painting"),
		o("3d", "3D ပုံဖော်မှု (3D Render)", "3D render", "a 3D render"),
		o("illustration", "ဒီဂျစ်တယ် ရုပ်ပြပုံ (Digital Illustration)", "Illustration", "a digital illustration"),
		o("linework", "မျဉ်းသား ရုပ်ပုံ (Line art)", "Line art", "clean line art"),
		o("vintage", "ခေတ်ဟောင်း ဓာတ်ပုံစတိုင် (Vintage photo)", "Vintage", "a vintage photograph"),
	}
}

func finSkin() []Option {
	return []Option{
		o("natural", "သဘာဝကျသော အသားအရေ (Natural)", "Natural texture", "natural, real-textured"),
		o("soft", "နူးညံ့ချောမွေ့အောင် ပြင်ဆင်ထားသော", "Softly retouched", "softly retouched, smooth"),
		o("flawless", "အပြစ်အနာအဆာကင်း ချောမွေ့သော (Flawless)", "Flawless", "flawless, magazine-retouched"),
		o("dewy", "စိုပြေဝင်းပသော အသားအရေ (Dewy glow)", "Dewy glow", "dewy, glowing"),
		o("matte", "အဆီမပြန်သော အသားအရေ (Matte)", "Matte", "matte, shine-free"),
		o("freckles", "မှဲ့/တင်းတိပ်လေးများ အပါအဝင် သဘာဝအတိုင်း", "Keep freckles", "with freckles and real detail kept"),
		o("tanned", "နေလောင်ညို အသားအရေ (Sun-tanned)", "Sun-tanned", "warmly sun-tanned"),
		o("porcelain", "ကြွေပန်းကန်လို ဖြူဖွေးချောမွေ့သော", "Porcelain", "smooth porcelain"),
	}
}

func finQuality() []Option {
	return []Option{
		o("8k", "အလွန်ကြည်လင်ပြတ်သားသော (8K Resolution)", "8K", "8k resolution"),
		o("detailed", "အသေးစိတ်လက်ရာ အထူးပြည့်စုံသော", "Highly detailed", "highly detailed"),
		o("sharp", "ကြည်လင်ပြတ်သားသော (Sharp focus)", "Sharp focus", "sharp focus"),
		o("intricate", "အနုစိတ်လက်ရာ ပြည့်စုံသော", "Intricate", "intricate details"),
		o("dslr", "ပရော်ဖက်ရှင်နယ် DSLR ဓာတ်ပုံအဆင့်", "DSLR photo", "a professional DSLR photo"),
		o("realistic", "လက်တွေ့အစစ်အမှန်အတိုင်း ကြည်လင်သော", "Ultra-real", "ultra-realistic"),
		o("masterpiece", "အကောင်းဆုံး လက်ရာမွန်အဆင့် (Masterpiece)", "Masterpiece", "a masterpiece"),
		o("pro", "ပရော်ဖက်ရှင်နယ် အဆင့် (Professional)", "Professional", "professional photography"),
		o("award", "ဆုရဓာတ်ပုံအဆင့် လက်ရာ (Award-winning)", "Award-winning", "award-winning"),
	}
}

func finAspect() []Option {
	return []Option{
		o("square", "1:1 (စတုရန်း)", "1:1 square", "1:1"),
		o("portrait", "4:5 (ထောင်လိုက်)", "4:5 portrait", "4:5"),
		o("photo", "3:2 (ဓာတ်ပုံ)", "3:2", "3:2"),
		o("wide", "16:9 (အလျားလိုက်)", "16:9 wide", "16:9"),
		o("story", "9:16 (ဖုန်း ဒေါင်လိုက်)", "9:16 tall", "9:16"),
	}
}

func finDetails() []Option {
	return []Option{
		o("detailed", "အသေးစိတ် အချက်အလက်များ အပြည့်ပါဝင်သော", "Highly detailed", "highly detailed"),
		o("bokeh", "နောက်ခံ ဝေဝါးထားသော (Bokeh effect)", "Blurred background", "with a blurred background"),
		o("reflection", "သိမ်မွေ့သော အရောင်ပြန် ရောင်ဟပ်မှုများ", "Reflections", "with subtle reflections"),
		o("dust", "လေထဲတွင် လွင့်နေသော အလင်းမှုန်များ", "Light particles", "with floating light particles"),
		o("symmetry", "ဘယ်ညာ ညီညာအချိုးကျသော (Symmetry)", "Symmetry", "with balanced symmetry"),
	}
}

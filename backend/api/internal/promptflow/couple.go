package promptflow

// coupleNodes builds the "couple" subject: TWO fully, independently
// parameterised people (Person A + Person B) plus their relationship and
// arrangement. Every node is namespaced (couple_a_* / couple_b_*) so each
// person is customised down to gender, age, hair, build, clothing, expression
// and pose — "pixel-level". Person A's gender fragment reads "a {value}" and
// Person B's "and a {value}", so the compiled prompt flows naturally:
//   "a romantic couple, holding hands, a man ... and a woman ..."
func coupleNodes() []Node {
	const c = "elements~=couple"

	nodes := []Node{
		textNode("couple_relationship", 600, false, c,
			"စုံတွဲ ဆက်ဆံရေး အမျိုးအစား?", "Their relationship?",
			"{value}",
			o("lovers", "ချစ်သူ စုံတွဲ", "Lovers", "a romantic couple"),
			o("married", "ဇနီးမောင်နှံ", "Married", "a married couple"),
			o("engaged", "စေ့စပ်ထားသော စုံတွဲ", "Engaged", "an engaged couple"),
			o("friends", "ခင်မင်ရင်းနှီးသော သူငယ်ချင်း နှစ်ဦး", "Friends", "two close friends"),
			o("siblings", "မောင်နှမ နှစ်ဦး", "Siblings", "two siblings"),
			o("parent_child", "မိဘနှင့် သားသမီး", "Parent & child", "a parent and child"),
			o("colleagues", "လုပ်ဖော်ကိုင်ဖက် နှစ်ဦး", "Colleagues", "two colleagues"),
			o("newlyweds", "မင်္ဂလာဦး ဇနီးမောင်နှံ", "Newlyweds", "newlyweds in wedding attire"),
		),
		textNode("couple_arrangement", 602, false, c,
			"အနေအထားနှင့် အပြန်အလှန် ဟန်ပန်?", "Arrangement / interaction?",
			"{value}",
			o("holding_hands", "လက်ချင်း တွဲထားသော", "Holding hands", "holding hands"),
			o("embracing", "နွေးထွေးစွာ ဖက်ထားသော", "Embracing", "embracing warmly"),
			o("facing", "မျက်နှာချင်းဆိုင် ရပ်နေသော", "Facing", "facing each other"),
			o("side", "ဘေးချင်းယှဉ် ရပ်နေသော", "Side by side", "standing side by side"),
			o("back", "ကျောချင်းကပ် ရပ်နေသော", "Back to back", "standing back to back"),
			o("gazing", "တစ်ဦးကိုတစ်ဦး ကြင်နာစွာ ကြည့်နေသော", "Gazing", "gazing at each other"),
			o("walking", "အတူတကွ လမ်းလျှောက်နေသော", "Walking together", "walking together"),
			o("shoulder", "ပခုံးဖက်ထားသော", "Arm around", "with an arm around each other"),
			o("dancing", "အတူတကွ ကခုန်နေသော", "Dancing", "dancing together"),
		),
	}

	nodes = append(nodes, personSubBlock("a", "ပထမလူ", "Person A", 610, c, "a {value}")...)
	nodes = append(nodes, personSubBlock("b", "ဒုတိယလူ", "Person B", 640, c, "and a {value}")...)
	return nodes
}

// personSubBlock is one person's full parameter set inside the couple, with all
// ids namespaced by [prefix] and every question prefixed by [myTitle]/[enTitle]
// so the wizard clearly shows which person is being edited.
func personSubBlock(prefix, myTitle, enTitle string, base int, cond, genderFrag string) []Node {
	id := func(s string) string { return "couple_" + prefix + "_" + s }
	qMy := func(s string) string { return myTitle + " — " + s }
	qEn := func(s string) string { return enTitle + " — " + s }

	return []Node{
		{
			ID: id("gender"), Order: base, Type: TypeSingle, Condition: cond,
			Question: L10n{My: qMy("အမျိုးသား / အမျိုးသမီး?"), En: qEn("Male or female?")},
			Fragment: genderFrag,
			Options: []Option{
				o("male", "အမျိုးသား", "Male", "man"),
				o("female", "အမျိုးသမီး", "Female", "woman"),
			},
		},
		textNode(id("age"), base+1, true, cond,
			qMy("အသက်အရွယ်?"), qEn("Age?"), "{value}", cpAge()...),
		textNode(id("hair"), base+2, false, cond,
			qMy("ဆံပင်ပုံစံနှင့် အရောင်?"), qEn("Hair?"), "with {value} hair", cpHair()...),
		textNode(id("build"), base+3, true, cond,
			qMy("ကိုယ်လုံးကိုယ်ပေါက် အချိုးအစား?"), qEn("Build?"), "with a {value} build", cpBuild()...),
		textNode(id("clothing"), base+4, false, cond,
			qMy("ဝတ်စုံနှင့် အဝတ်အစား?"), qEn("Clothing?"), "wearing {value}", cpClothing()...),
		textNode(id("expression"), base+5, true, cond,
			qMy("မျက်နှာ အမူအရာ?"), qEn("Expression?"), "with a {value} expression", cpExpr()...),
		textNode(id("pose"), base+6, false, cond,
			qMy("ကိုယ်ဟန် အနေအထား?"), qEn("Pose?"), "{value}", cpPose()...),
	}
}

// --- Shared per-person pill sets (used for both people in the couple) --------

func cpAge() []Option {
	return []Option{
		o("teens", "ဆယ်ကျော်သက် အရွယ်", "Teens", "in their teens"),
		o("20s", "အသက် ၂၀ ဝန်းကျင်", "20s", "in their 20s"),
		o("30s", "အသက် ၃၀ ကျော်", "30s", "in their 30s"),
		o("40s", "အသက် ၄၀ ကျော်", "40s", "in their 40s"),
		o("50s", "အသက် ၅၀ ကျော်", "50s", "in their 50s"),
		o("senior", "သက်ကြီးရွယ်အို", "Senior", "elderly"),
	}
}

func cpHair() []Option {
	return []Option{
		o("long_black", "ဆံပင်ရှည် နက်မှောင်", "Long black", "long black"),
		o("short_black", "ဆံပင်တို အနက်ရောင်", "Short black", "short black"),
		o("bun", "ဆံထုံး ထုံးထားသော", "Bun", "tied in a bun"),
		o("braided", "ကျစ်ဆံမြီး ကျစ်ထားသော", "Braided", "braided"),
		o("curly", "ဆံပင် ကောက်", "Curly", "curly"),
		o("wavy", "ဆံပင် လှိုင်းတွန့်", "Wavy", "wavy"),
		o("straight", "ဆံပင်ရှည် အဖြောင့်", "Long straight", "long straight"),
		o("ponytail", "ဆံပင် မြင်းမြီးစည်း", "Ponytail", "in a ponytail"),
		o("undercut", "ဘေးရိတ် ဆံပင်ပုံစံ (Undercut)", "Undercut", "a modern undercut"),
		o("grey", "ဆံပင်ဖြူ", "Grey", "grey"),
		o("shaved", "ခေါင်းတုံး ရိတ်ထားသော", "Shaved", "shaved"),
	}
}

func cpBuild() []Option {
	return []Option{
		o("slim", "ပိန်သွယ်", "Slim", "slim"),
		o("slender", "သွယ်လျ", "Slender", "slender"),
		o("average", "ပုံမှန် အလတ်စား", "Average", "average"),
		o("athletic", "အားကစားသမား ခန္ဓာကိုယ်", "Athletic", "athletic"),
		o("curvy", "ကိုယ်လုံးကိုယ်ပေါက် ပြည့်ဖြိုးသော", "Curvy", "curvy"),
		o("muscular", "ကြွက်သားထွားကျိုင်းသော", "Muscular", "muscular"),
		o("plump", "ခန္ဓာကိုယ် ဝဝပြည့်ပြည့်", "Plump", "plump"),
		o("petite", "ခန္ဓာကိုယ် သေးသေးသွယ်သွယ်", "Petite", "petite"),
	}
}

func cpClothing() []Option {
	return []Option{
		o("htamein", "မြန်မာရိုးရာ ထမီနှင့် အင်္ကျီ", "Htamein & blouse", "a traditional htamein and blouse"),
		o("longyi", "လုံချည်နှင့် ရှပ်အင်္ကျီ", "Longyi & shirt", "a longyi with a collared shirt"),
		o("acheik", "အချိတ်လုံချည် / ထမီ", "Acheik silk", "an acheik-patterned silk htamein"),
		o("taikpon", "တိုက်ပုံနှင့် ပုဆိုး", "Taikpon", "a taikpon jacket over a longyi"),
		o("shan", "ရှမ်း ရိုးရာဝတ်စုံ", "Shan dress", "a Shan traditional outfit"),
		o("kachin", "ကချင် ရိုးရာဝတ်စုံ", "Kachin dress", "a Kachin traditional costume"),
		o("wedding", "မြန်မာ့ရိုးရာ မင်္ဂလာဆောင်ဝတ်စုံ", "Wedding attire", "traditional wedding attire"),
		o("suit", "ခေတ်မီ ကုတ်အင်္ကျီဝတ်စုံ (Suit)", "Modern suit", "a modern suit"),
		o("dress", "အနောက်တိုင်း ဂါဝန်ရှည်", "Western dress", "an elegant dress"),
		o("casual", "တီရှပ်နှင့် ဂျင်းဘောင်းဘီ", "T-shirt & jeans", "a t-shirt and jeans"),
		o("monk", "ရဟန်း သင်္ကန်း", "Monk's robes", "saffron monastic robes"),
	}
}

func cpExpr() []Option {
	return []Option{
		o("gentle", "ယဉ်ကျေးညင်သာစွာ ပြုံးနေသော", "Gentle smile", "gentle"),
		o("big_smile", "တောက်ပစွာ ပြုံးရွှင်နေသော", "Big smile", "beaming"),
		o("romantic", "ကြင်နာယုယစွာ ကြည့်နေသော", "Romantic gaze", "loving"),
		o("serious", "တည်ငြိမ်အေးဆေးသော", "Serious", "calm and serious"),
		o("shy", "ရှက်ပြုံးလေး ပြုံးနေသော", "Shy", "shy"),
		o("laughing", "ပျော်ရွှင်စွာ ရယ်မောနေသော", "Laughing", "laughing"),
		o("proud", "ဂုဏ်ယူဝင့်ကြွားသော", "Proud", "proud"),
		o("serene", "အေးချမ်းကြည်လင်သော", "Serene", "serene"),
	}
}

func cpPose() []Option {
	return []Option{
		o("standing", "မတ်တပ်ရပ်နေသော", "Standing", "standing"),
		o("sitting", "ထိုင်နေသော", "Sitting", "sitting"),
		o("walking", "လမ်းလျှောက်နေသော", "Walking", "walking"),
		o("leaning", "မှီရပ်နေသော", "Leaning", "leaning casually"),
		o("kneeling", "ဒူးထောက်နေသော", "Kneeling", "kneeling"),
		o("arms_crossed", "လက်ပိုက်ထားသော", "Arms crossed", "with arms crossed"),
		o("hand_on_hip", "ခါးထောက်ထားသော", "Hand on hip", "with a hand on the hip"),
		o("looking_back", "နောက်သို့ လှည့်ကြည့်နေသော", "Looking back", "glancing over the shoulder"),
	}
}

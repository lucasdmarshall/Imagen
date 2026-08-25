package promptflow

// DefaultFlow is the seed Guided Prompt Engine questionnaire. It is served to
// the client and (later) editable from the Admin app. Labels are bilingual
// (Burmese default); prompt fragments are English for the image models.
//
// Convention: the client renderer always offers an "Other — type your own"
// entry on single/multi nodes, so any choice question also accepts free text.
func DefaultFlow() Flow {
	return Flow{
		Version: 1,
		Start:   "subject",
		Nodes: []Node{
			// --- Root -------------------------------------------------------
			{
				ID:       "subject",
				Order:    0,
				Type:     TypeSingle,
				Question: L10n{My: "ဘာပုံမျိုး ထုတ်ချင်တာလဲ?", En: "What do you want to create?"},
				Options: []Option{
					{ID: "person", Value: "person", Label: L10n{My: "လူ", En: "A person"},
						Fragment: "a portrait photo", Next: "person_hasphoto"},
					{ID: "object", Value: "object", Label: L10n{My: "အရာဝတ္ထု", En: "An object"},
						Fragment: "a product photo", Next: "object_hasphoto"},
					{ID: "scene", Value: "scene", Label: L10n{My: "မြင်ကွင်း", En: "A scene"},
						Fragment: "a scenic photo", Next: "scene_location"},
				},
			},

			// --- Person branch ---------------------------------------------
			{
				ID:       "person_hasphoto",
				Order:    5,
				Type:     TypeSingle,
				Question: L10n{My: "Reference photo ရှိလား?", En: "Do you have a reference photo?"},
				Options: []Option{
					{ID: "yes", Value: "yes", Label: L10n{My: "ရှိတယ် — တင်မယ်", En: "Yes, upload"}, Next: "person_upload"},
					{ID: "no", Value: "no", Label: L10n{My: "မရှိဘူး", En: "No"}, Next: "person_gender"},
				},
			},
			{
				ID:       "person_upload",
				Order:    6,
				Type:     TypeImage,
				Condition: "person_hasphoto=yes",
				Question: L10n{My: "Reference photo တင်ပါ", En: "Upload the reference photo"},
				Fragment: "resembling the reference subject",
				Next:     "person_expression",
			},
			{
				ID:       "person_expression",
				Order:    7,
				Type:     TypeSingle,
				Condition: "person_hasphoto=yes",
				Question: L10n{My: "မျက်နှာအမူအရာ ဘယ်လိုလိုချင်လဲ?", En: "What facial expression?"},
				Fragment: "with a {value} facial expression",
				Next:     "background",
				Options: []Option{
					{ID: "happy", Value: "happy", Label: L10n{My: "ပျော်ရွှင်", En: "Happy"}},
					{ID: "sad", Value: "sad", Label: L10n{My: "ဝမ်းနည်း", En: "Sad"}},
					{ID: "annoyed", Value: "annoyed", Label: L10n{My: "စိတ်ညစ်", En: "Annoyed"}},
					{ID: "angry", Value: "angry", Label: L10n{My: "ဒေါသ", En: "Angry"}},
					{ID: "mad", Value: "furious", Label: L10n{My: "အလွန်ဒေါသ", En: "Mad"}},
					{ID: "provocative", Value: "provocative", Label: L10n{My: "ဆွပေးသော", En: "Provocative"}},
					{ID: "pout", Value: "pouting", Label: L10n{My: "နှုတ်ခမ်းစူ", En: "Pout"}},
				},
			},
			{
				ID:       "person_gender",
				Order:    8,
				Type:     TypeSingle,
				Condition: "person_hasphoto=no",
				Question: L10n{My: "ကျား / မ ရွေးပါ", En: "Male or female?"},
				Fragment: "of a {value}",
				Next:     "person_age",
				Options: []Option{
					{ID: "male", Value: "man", Label: L10n{My: "ကျား", En: "Male"}},
					{ID: "female", Value: "woman", Label: L10n{My: "မ", En: "Female"}},
				},
			},
			{
				ID:       "person_age",
				Order:    9,
				Type:     TypeSingle,
				Condition: "person_hasphoto=no",
				Question: L10n{My: "အသက်အရွယ်?", En: "Age range?"},
				Fragment: "{value}",
				Next:     "person_clothing",
				Options: []Option{
					{ID: "child", Value: "a child", Label: L10n{My: "ကလေး", En: "Child"}},
					{ID: "teen", Value: "a teenager", Label: L10n{My: "ဆယ်ကျော်သက်", En: "Teen"}},
					{ID: "young", Value: "a young adult", Label: L10n{My: "လူငယ်", En: "Young adult"}},
					{ID: "adult", Value: "an adult", Label: L10n{My: "အရွယ်ရောက်", En: "Adult"}},
					{ID: "senior", Value: "an elderly person", Label: L10n{My: "သက်ကြီး", En: "Senior"}},
				},
			},
			{
				ID:       "person_clothing",
				Order:    10,
				Type:     TypeText,
				Condition: "person_hasphoto=no",
				Question: L10n{My: "ဘာဝတ်ထားစေချင်လဲ?", En: "What are they wearing?"},
				Help:     L10n{My: "ဥပမာ- အပြာရောင် ရိုးရာဝတ်စုံ", En: "e.g. a blue traditional outfit"},
				Fragment: "wearing {value}",
				Next:     "background",
			},

			// --- Object branch ---------------------------------------------
			{
				ID:       "object_hasphoto",
				Order:    5,
				Type:     TypeSingle,
				Question: L10n{My: "Reference photo ရှိလား?", En: "Do you have a reference photo?"},
				Options: []Option{
					{ID: "yes", Value: "yes", Label: L10n{My: "ရှိတယ် — တင်မယ်", En: "Yes, upload"}, Next: "object_upload"},
					{ID: "no", Value: "no", Label: L10n{My: "မရှိဘူး", En: "No"}, Next: "object_what"},
				},
			},
			{
				ID:       "object_upload",
				Order:    6,
				Type:     TypeImage,
				Condition: "object_hasphoto=yes",
				Question: L10n{My: "Reference photo တင်ပါ", En: "Upload the reference photo"},
				Fragment: "resembling the reference object",
				Next:     "object_material",
			},
			{
				ID:       "object_what",
				Order:    7,
				Type:     TypeText,
				Condition: "object_hasphoto=no",
				Question: L10n{My: "ဘာအရာဝတ္ထုလဲ?", En: "What object is it?"},
				Help:     L10n{My: "ဥပမာ- ရှေးဟောင်း လက်ဝတ်ရတနာ", En: "e.g. a vintage piece of jewelry"},
				Fragment: "of {value}",
				Next:     "object_material",
			},
			{
				ID:       "object_material",
				Order:    8,
				Type:     TypeText,
				Question: L10n{My: "ပစ္စည်း/အသားအရေ (မဖြည့်လဲရ)", En: "Material / texture (optional)"},
				Fragment: "made of {value}",
				Next:     "background",
			},

			// --- Scene branch ----------------------------------------------
			{
				ID:       "scene_location",
				Order:    3,
				Type:     TypeText,
				Question: L10n{My: "ဘယ်နေရာလဲ?", En: "Where is it?"},
				Help:     L10n{My: "ဥပမာ- တောင်ပေါ်ရွာလေး", En: "e.g. a small mountain village"},
				Fragment: "of {value}",
				Next:     "scene_time",
			},
			{
				ID:       "scene_time",
				Order:    4,
				Type:     TypeSingle,
				Question: L10n{My: "အချိန်?", En: "Time of day?"},
				Fragment: "at {value}",
				Next:     "scene_weather",
				Options: []Option{
					{ID: "dawn", Value: "dawn", Label: L10n{My: "အရုဏ်တက်", En: "Dawn"}},
					{ID: "day", Value: "daytime", Label: L10n{My: "နေ့ခင်း", En: "Day"}},
					{ID: "golden", Value: "golden hour", Label: L10n{My: "ရွှေရောင်အချိန်", En: "Golden hour"}},
					{ID: "night", Value: "night", Label: L10n{My: "ည", En: "Night"}},
				},
			},
			{
				ID:       "scene_weather",
				Order:    5,
				Type:     TypeSingle,
				Question: L10n{My: "ရာသီဥတု?", En: "Weather?"},
				Fragment: "{value} weather",
				Next:     "lighting",
				Options: []Option{
					{ID: "clear", Value: "clear", Label: L10n{My: "သာယာ", En: "Clear"}},
					{ID: "cloudy", Value: "cloudy", Label: L10n{My: "တိမ်ထူ", En: "Cloudy"}},
					{ID: "rain", Value: "rainy", Label: L10n{My: "မိုးရွာ", En: "Rainy"}},
					{ID: "fog", Value: "foggy", Label: L10n{My: "မြူဆိုင်း", En: "Foggy"}},
					{ID: "snow", Value: "snowy", Label: L10n{My: "နှင်းကျ", En: "Snowy"}},
				},
			},

			// --- Shared tail ------------------------------------------------
			{
				ID:       "background",
				Order:    20,
				Type:     TypeText,
				Condition: "subject!=scene",
				Question: L10n{My: "နောက်ခံ ဘယ်လိုလိုချင်လဲ?", En: "What background do you want?"},
				Help:     L10n{My: "ဥပမာ- ချစ်စရာအခန်းလေးထဲမှာ", En: "e.g. in a cozy little room"},
				Fragment: "in {value}",
				Next:     "lighting",
			},
			{
				ID:       "lighting",
				Order:    30,
				Type:     TypeSingle,
				Question: L10n{My: "အလင်းရောင်?", En: "Lighting?"},
				Fragment: "{value} lighting",
				Next:     "camera_shot",
				Options: []Option{
					{ID: "soft", Value: "soft", Label: L10n{My: "နူးညံ့", En: "Soft"}},
					{ID: "natural", Value: "natural", Label: L10n{My: "သဘာဝ", En: "Natural"}},
					{ID: "studio", Value: "studio", Label: L10n{My: "စတူဒီယို", En: "Studio"}},
					{ID: "dramatic", Value: "dramatic", Label: L10n{My: "ထင်ရှား", En: "Dramatic"}},
					{ID: "backlit", Value: "backlit", Label: L10n{My: "နောက်ခံအလင်း", En: "Backlit"}},
				},
			},
			{
				ID:       "camera_shot",
				Order:    40,
				Type:     TypeSingle,
				Question: L10n{My: "ရိုက်ကွက် အကွာအဝေး?", En: "Shot framing?"},
				Fragment: "{value}",
				Next:     "style",
				Options: []Option{
					{ID: "closeup", Value: "close-up shot", Label: L10n{My: "အနီးကပ်", En: "Close-up"}},
					{ID: "portrait", Value: "portrait shot", Label: L10n{My: "ပုံတူ", En: "Portrait"}},
					{ID: "medium", Value: "medium shot", Label: L10n{My: "အလယ်အလတ်", En: "Medium"}},
					{ID: "full", Value: "full-body shot", Label: L10n{My: "တစ်ကိုယ်လုံး", En: "Full body"}},
					{ID: "wide", Value: "wide shot", Label: L10n{My: "ကျယ်ပြန့်", En: "Wide"}},
				},
			},
			{
				ID:       "style",
				Order:    50,
				Type:     TypeSingle,
				Question: L10n{My: "ပုံစံ (style)?", En: "Visual style?"},
				Fragment: "{value}",
				Next:     "mood",
				Options: []Option{
					{ID: "photo", Value: "photorealistic", Label: L10n{My: "ဓာတ်ပုံဆန်", En: "Photorealistic"}},
					{ID: "cinematic", Value: "cinematic", Label: L10n{My: "ရုပ်ရှင်ဆန်", En: "Cinematic"}},
					{ID: "anime", Value: "anime style", Label: L10n{My: "အန်နီမေး", En: "Anime"}},
					{ID: "oil", Value: "oil painting", Label: L10n{My: "ဆီဆေးပန်းချီ", En: "Oil painting"}},
					{ID: "3d", Value: "3D render", Label: L10n{My: "3D", En: "3D render"}},
					{ID: "water", Value: "watercolor", Label: L10n{My: "ရေဆေး", En: "Watercolor"}},
				},
			},
			{
				ID:       "mood",
				Order:    60,
				Type:     TypeSingle,
				Question: L10n{My: "ခံစားမှု (mood)?", En: "Mood?"},
				Fragment: "{value} mood",
				Next:     "aspect",
				Options: []Option{
					{ID: "calm", Value: "calm", Label: L10n{My: "ငြိမ်သက်", En: "Calm"}},
					{ID: "joyful", Value: "joyful", Label: L10n{My: "ရွှင်လန်း", En: "Joyful"}},
					{ID: "moody", Value: "moody", Label: L10n{My: "ဆိုးဝါး", En: "Moody"}},
					{ID: "mysterious", Value: "mysterious", Label: L10n{My: "လျှို့ဝှက်", En: "Mysterious"}},
					{ID: "energetic", Value: "energetic", Label: L10n{My: "တက်ကြွ", En: "Energetic"}},
				},
			},
			{
				ID:       "aspect",
				Order:    70,
				Type:     TypeSingle,
				Question: L10n{My: "အချိုးအစား (aspect ratio)?", En: "Aspect ratio?"},
				Fragment: "{value} aspect ratio",
				Next:     "details",
				Options: []Option{
					{ID: "square", Value: "1:1", Label: L10n{My: "1:1 (စတုရန်း)", En: "1:1 square"}},
					{ID: "portrait", Value: "4:5", Label: L10n{My: "4:5 (ထောင်)", En: "4:5 portrait"}},
					{ID: "photo", Value: "3:2", Label: L10n{My: "3:2", En: "3:2"}},
					{ID: "wide", Value: "16:9", Label: L10n{My: "16:9 (အလျား)", En: "16:9 wide"}},
					{ID: "story", Value: "9:16", Label: L10n{My: "9:16 (ဒေါင်လိုက်)", En: "9:16 tall"}},
				},
			},
			{
				ID:       "details",
				Order:    80,
				Type:     TypeText,
				Question: L10n{My: "ထပ်ဖြည့်ချင်တာ ရှိလား? (မဖြည့်လဲရ)", En: "Any extra details? (optional)"},
				Fragment: "{value}",
				// No Next => end of flow.
			},
		},
	}
}

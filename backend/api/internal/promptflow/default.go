package promptflow

// DefaultFlow is the seed Guided Prompt Engine questionnaire.
//
// Composition model: the user first picks which elements are in the image
// (person / object / scene) — multiple allowed. Each element's questions appear
// only if selected (Condition "elements~=..."). Advanced nodes appear only in
// Detailed mode. Labels are bilingual (Burmese default); fragments are English.
//
// Client conventions:
//   - single/multi nodes always offer an "Other — type your own" entry.
//   - Quick mode shows only non-Advanced nodes; Detailed shows all.
func DefaultFlow() Flow {
	return Flow{
		Version: 2,
		Start:   "elements",
		Nodes: []Node{
			// --- What's in the image (composition) --------------------------
			{
				ID:       "elements",
				Order:    0,
				Type:     TypeMulti,
				Question: L10n{My: "ပုံထဲမှာ ဘာတွေ ပါမလဲ? (တစ်ခုထက်ပို ရွေးလို့ရ)", En: "What's in your image? (choose any)"},
				Help:     L10n{My: "ဥပမာ- လူ + အရာဝတ္ထု ကို တွဲရွေးလို့ရ", En: "e.g. person + object together"},
				Options: []Option{
					{ID: "person", Value: "person", Label: L10n{My: "လူ", En: "Person"}},
					{ID: "object", Value: "object", Label: L10n{My: "အရာဝတ္ထု", En: "Object"}},
					{ID: "scene", Value: "scene", Label: L10n{My: "မြင်ကွင်း/နောက်ခံ", En: "Scene / setting"}},
				},
			},

			// --- Person element --------------------------------------------
			{
				ID: "person_hasphoto", Order: 5, Type: TypeSingle,
				Condition: "elements~=person",
				Question:  L10n{My: "လူအတွက် reference photo ရှိလား?", En: "Reference photo for the person?"},
				Options: []Option{
					{ID: "yes", Value: "yes", Label: L10n{My: "ရှိတယ် — တင်မယ်", En: "Yes, upload"}},
					{ID: "no", Value: "no", Label: L10n{My: "မရှိဘူး", En: "No"}},
				},
			},
			{
				ID: "person_upload", Order: 6, Type: TypeImage,
				Condition: "elements~=person AND person_hasphoto=yes",
				Question:  L10n{My: "လူ၏ reference photo တင်ပါ", En: "Upload the person's reference photo"},
				Fragment:  "resembling the reference person",
			},
			{
				ID: "person_expression", Order: 7, Type: TypeSingle,
				Condition: "elements~=person AND person_hasphoto=yes",
				Question:  L10n{My: "မျက်နှာအမူအရာ?", En: "Facial expression?"},
				Fragment:  "with a {value} facial expression",
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
				ID: "person_gender", Order: 6, Type: TypeSingle,
				Condition: "elements~=person AND person_hasphoto=no",
				Question:  L10n{My: "ကျား / မ?", En: "Male or female?"},
				Fragment:  "a {value}",
				Options: []Option{
					{ID: "male", Value: "man", Label: L10n{My: "ကျား", En: "Male"}},
					{ID: "female", Value: "woman", Label: L10n{My: "မ", En: "Female"}},
				},
			},
			{
				ID: "person_age", Order: 8, Type: TypeSingle, Advanced: true,
				Condition: "elements~=person AND person_hasphoto=no",
				Question:  L10n{My: "အသက်အရွယ်?", En: "Age range?"},
				Fragment:  "{value}",
				Options: []Option{
					{ID: "child", Value: "a child", Label: L10n{My: "ကလေး", En: "Child"}},
					{ID: "teen", Value: "a teenager", Label: L10n{My: "ဆယ်ကျော်သက်", En: "Teen"}},
					{ID: "young", Value: "a young adult", Label: L10n{My: "လူငယ်", En: "Young adult"}},
					{ID: "adult", Value: "an adult", Label: L10n{My: "အရွယ်ရောက်", En: "Adult"}},
					{ID: "senior", Value: "an elderly person", Label: L10n{My: "သက်ကြီး", En: "Senior"}},
				},
			},
			{
				ID: "person_hair", Order: 9, Type: TypeText, Advanced: true,
				Condition: "elements~=person AND person_hasphoto=no",
				Question:  L10n{My: "ဆံပင် (ပုံစံ/အရောင်)?", En: "Hair (style / color)?"},
				Help:      L10n{My: "ဥပမာ- ရှည်လျား နက်မှောင်", En: "e.g. long black hair"},
				Fragment:  "with {value} hair",
			},
			{
				ID: "person_action", Order: 12, Type: TypeText,
				Condition: "elements~=person",
				Question:  L10n{My: "လူက ဘာလုပ်နေလဲ / ဘာကိုင်ထားလဲ?", En: "What is the person doing / holding?"},
				Help:      L10n{My: "ဥပမာ- teapot ကို ကိုင်ထား", En: "e.g. holding a teapot"},
				Fragment:  "{value}",
			},
			{
				ID: "person_clothing", Order: 14, Type: TypeText, Advanced: true,
				Condition: "elements~=person AND person_hasphoto=no",
				Question:  L10n{My: "ဘာဝတ်ထားလဲ?", En: "What are they wearing?"},
				Help:      L10n{My: "ဥပမာ- အပြာရောင် ရိုးရာဝတ်စုံ", En: "e.g. a blue traditional outfit"},
				Fragment:  "wearing {value}",
			},
			{
				ID: "person_pose", Order: 15, Type: TypeSingle, Advanced: true,
				Condition: "elements~=person",
				Question:  L10n{My: "ကိုယ်ဟန်?", En: "Pose?"},
				Fragment:  "{value}",
				Options: []Option{
					{ID: "standing", Value: "standing", Label: L10n{My: "ရပ်", En: "Standing"}},
					{ID: "sitting", Value: "sitting", Label: L10n{My: "ထိုင်", En: "Sitting"}},
					{ID: "walking", Value: "walking", Label: L10n{My: "လမ်းလျှောက်", En: "Walking"}},
					{ID: "closeup", Value: "a head-and-shoulders pose", Label: L10n{My: "ခေါင်း/ပခုံး", En: "Head & shoulders"}},
				},
			},

			// --- Object element --------------------------------------------
			{
				ID: "object_hasphoto", Order: 20, Type: TypeSingle,
				Condition: "elements~=object",
				Question:  L10n{My: "အရာဝတ္ထုအတွက် reference photo ရှိလား?", En: "Reference photo for the object?"},
				Options: []Option{
					{ID: "yes", Value: "yes", Label: L10n{My: "ရှိတယ် — တင်မယ်", En: "Yes, upload"}},
					{ID: "no", Value: "no", Label: L10n{My: "မရှိဘူး", En: "No"}},
				},
			},
			{
				ID: "object_upload", Order: 21, Type: TypeImage,
				Condition: "elements~=object AND object_hasphoto=yes",
				Question:  L10n{My: "အရာဝတ္ထု၏ reference photo တင်ပါ", En: "Upload the object's reference photo"},
				Fragment:  "resembling the reference object",
			},
			{
				ID: "object_what", Order: 21, Type: TypeText,
				Condition: "elements~=object AND object_hasphoto=no",
				Question:  L10n{My: "ဘာအရာဝတ္ထုလဲ?", En: "What object is it?"},
				Help:      L10n{My: "ဥပမာ- ရှေးဟောင်း ရေနွေးအိုး", En: "e.g. vintage teapot"},
				Fragment:  "{value}",
			},
			{
				ID: "object_material", Order: 22, Type: TypeText, Advanced: true,
				Condition: "elements~=object",
				Question:  L10n{My: "ပစ္စည်း/အသားအရေ?", En: "Material / texture?"},
				Fragment:  "made of {value}",
			},
			{
				ID: "object_finish", Order: 23, Type: TypeSingle, Advanced: true,
				Condition: "elements~=object",
				Question:  L10n{My: "မျက်နှာပြင်?", En: "Finish?"},
				Fragment:  "{value} finish",
				Options: []Option{
					{ID: "matte", Value: "matte", Label: L10n{My: "မှေး", En: "Matte"}},
					{ID: "glossy", Value: "glossy", Label: L10n{My: "တောက်", En: "Glossy"}},
					{ID: "metallic", Value: "metallic", Label: L10n{My: "သတ္တု", En: "Metallic"}},
					{ID: "rough", Value: "rough", Label: L10n{My: "ကြမ်း", En: "Rough"}},
				},
			},

			// --- Scene element ---------------------------------------------
			{
				ID: "scene_location", Order: 30, Type: TypeText,
				Condition: "elements~=scene",
				Question:  L10n{My: "ဘယ်နေရာလဲ?", En: "Where is it?"},
				Help:      L10n{My: "ဥပမာ- တောင်ပေါ်ရွာလေး", En: "e.g. a small mountain village"},
				Fragment:  "in {value}",
			},
			{
				ID: "scene_time", Order: 31, Type: TypeSingle, Advanced: true,
				Condition: "elements~=scene",
				Question:  L10n{My: "အချိန်?", En: "Time of day?"},
				Fragment:  "at {value}",
				Options: []Option{
					{ID: "dawn", Value: "dawn", Label: L10n{My: "အရုဏ်တက်", En: "Dawn"}},
					{ID: "day", Value: "daytime", Label: L10n{My: "နေ့ခင်း", En: "Day"}},
					{ID: "golden", Value: "golden hour", Label: L10n{My: "ရွှေရောင်အချိန်", En: "Golden hour"}},
					{ID: "night", Value: "night", Label: L10n{My: "ည", En: "Night"}},
				},
			},
			{
				ID: "scene_weather", Order: 32, Type: TypeSingle, Advanced: true,
				Condition: "elements~=scene",
				Question:  L10n{My: "ရာသီဥတု?", En: "Weather?"},
				Fragment:  "{value} weather",
				Options: []Option{
					{ID: "clear", Value: "clear", Label: L10n{My: "သာယာ", En: "Clear"}},
					{ID: "cloudy", Value: "cloudy", Label: L10n{My: "တိမ်ထူ", En: "Cloudy"}},
					{ID: "rain", Value: "rainy", Label: L10n{My: "မိုးရွာ", En: "Rainy"}},
					{ID: "fog", Value: "foggy", Label: L10n{My: "မြူဆိုင်း", En: "Foggy"}},
					{ID: "snow", Value: "snowy", Label: L10n{My: "နှင်းကျ", En: "Snowy"}},
				},
			},

			// --- Background (only when no scene element chosen) --------------
			{
				ID: "background", Order: 33, Type: TypeText,
				Condition: "elements!~=scene",
				Question:  L10n{My: "နောက်ခံ ဘယ်လိုလိုချင်လဲ?", En: "What background?"},
				Help:      L10n{My: "ဥပမာ- ချစ်စရာအခန်းလေးထဲမှာ", En: "e.g. in a cozy little room"},
				Fragment:  "in {value}",
			},

			// --- Shared tail: light / camera / style / technical -----------
			{
				ID: "lighting", Order: 40, Type: TypeSingle,
				Question: L10n{My: "အလင်းရောင်?", En: "Lighting?"},
				Fragment: "{value} lighting",
				Options: []Option{
					{ID: "soft", Value: "soft", Label: L10n{My: "နူးညံ့", En: "Soft"}},
					{ID: "natural", Value: "natural", Label: L10n{My: "သဘာဝ", En: "Natural"}},
					{ID: "studio", Value: "studio", Label: L10n{My: "စတူဒီယို", En: "Studio"}},
					{ID: "dramatic", Value: "dramatic", Label: L10n{My: "ထင်ရှား", En: "Dramatic"}},
					{ID: "neon", Value: "neon", Label: L10n{My: "နီယွန်", En: "Neon"}},
				},
			},
			{
				ID: "light_dir", Order: 41, Type: TypeSingle, Advanced: true,
				Question: L10n{My: "အလင်း လာရာ?", En: "Light direction?"},
				Fragment: "{value} light",
				Options: []Option{
					{ID: "front", Value: "front", Label: L10n{My: "ရှေ့", En: "Front"}},
					{ID: "side", Value: "side", Label: L10n{My: "ဘေး", En: "Side"}},
					{ID: "back", Value: "back", Label: L10n{My: "နောက် (rim)", En: "Back / rim"}},
					{ID: "top", Value: "top", Label: L10n{My: "အပေါ်", En: "Top"}},
				},
			},
			{
				ID: "camera_shot", Order: 45, Type: TypeSingle,
				Question: L10n{My: "ရိုက်ကွက် အကွာအဝေး?", En: "Shot framing?"},
				Fragment: "{value}",
				Options: []Option{
					{ID: "closeup", Value: "close-up shot", Label: L10n{My: "အနီးကပ်", En: "Close-up"}},
					{ID: "portrait", Value: "portrait shot", Label: L10n{My: "ပုံတူ", En: "Portrait"}},
					{ID: "medium", Value: "medium shot", Label: L10n{My: "အလယ်အလတ်", En: "Medium"}},
					{ID: "full", Value: "full-body shot", Label: L10n{My: "တစ်ကိုယ်လုံး", En: "Full body"}},
					{ID: "wide", Value: "wide shot", Label: L10n{My: "ကျယ်ပြန့်", En: "Wide"}},
				},
			},
			{
				ID: "camera_angle", Order: 46, Type: TypeSingle, Advanced: true,
				Question: L10n{My: "ရိုက်ကွက် ထောင့်?", En: "Camera angle?"},
				Fragment: "{value} angle",
				Options: []Option{
					{ID: "eye", Value: "eye-level", Label: L10n{My: "မျက်စိအမြင့်", En: "Eye-level"}},
					{ID: "low", Value: "low", Label: L10n{My: "အနိမ့်မှ", En: "Low"}},
					{ID: "high", Value: "high", Label: L10n{My: "အမြင့်မှ", En: "High"}},
					{ID: "bird", Value: "birds-eye", Label: L10n{My: "ငှက်မြင်ကွင်း", En: "Bird's-eye"}},
				},
			},
			{
				ID: "camera_lens", Order: 47, Type: TypeSingle, Advanced: true,
				Question: L10n{My: "Lens?", En: "Lens?"},
				Fragment: "shot on a {value} lens",
				Options: []Option{
					{ID: "wide", Value: "24mm wide", Label: L10n{My: "24mm wide", En: "24mm wide"}},
					{ID: "standard", Value: "50mm", Label: L10n{My: "50mm", En: "50mm"}},
					{ID: "portrait", Value: "85mm portrait", Label: L10n{My: "85mm portrait", En: "85mm portrait"}},
					{ID: "macro", Value: "macro", Label: L10n{My: "macro", En: "Macro"}},
				},
			},
			{
				ID: "dof", Order: 48, Type: TypeSingle, Advanced: true,
				Question: L10n{My: "Depth of field (bokeh)?", En: "Depth of field?"},
				Fragment: "{value} depth of field",
				Options: []Option{
					{ID: "shallow", Value: "shallow", Label: L10n{My: "အနက် တိမ် (bokeh)", En: "Shallow (bokeh)"}},
					{ID: "deep", Value: "deep", Label: L10n{My: "အနက် နက် (ကြည်လင်)", En: "Deep (all sharp)"}},
				},
			},
			{
				ID: "style", Order: 50, Type: TypeSingle,
				Question: L10n{My: "ပုံစံ (style)?", En: "Visual style?"},
				Fragment: "{value}",
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
				ID: "color", Order: 52, Type: TypeSingle, Advanced: true,
				Question: L10n{My: "အရောင် စနစ်?", En: "Color palette?"},
				Fragment: "{value} color palette",
				Options: []Option{
					{ID: "warm", Value: "warm", Label: L10n{My: "နွေးထွေး", En: "Warm"}},
					{ID: "cool", Value: "cool", Label: L10n{My: "အေးမြ", En: "Cool"}},
					{ID: "vibrant", Value: "vibrant", Label: L10n{My: "ရင့်သန်", En: "Vibrant"}},
					{ID: "muted", Value: "muted", Label: L10n{My: "နုးညံ့", En: "Muted"}},
					{ID: "mono", Value: "monochrome", Label: L10n{My: "တစ်ရောင်တည်း", En: "Monochrome"}},
				},
			},
			{
				ID: "composition", Order: 54, Type: TypeSingle, Advanced: true,
				Question: L10n{My: "ဖွဲ့စည်းပုံ (composition)?", En: "Composition?"},
				Fragment: "{value} composition",
				Options: []Option{
					{ID: "thirds", Value: "rule-of-thirds", Label: L10n{My: "rule of thirds", En: "Rule of thirds"}},
					{ID: "center", Value: "centered", Label: L10n{My: "ဗဟို", En: "Centered"}},
					{ID: "symmetry", Value: "symmetrical", Label: L10n{My: "ညီညာ", En: "Symmetrical"}},
				},
			},
			{
				ID: "mood", Order: 60, Type: TypeSingle, Advanced: true,
				Question: L10n{My: "ခံစားမှု (mood)?", En: "Mood?"},
				Fragment: "{value} mood",
				Options: []Option{
					{ID: "calm", Value: "calm", Label: L10n{My: "ငြိမ်သက်", En: "Calm"}},
					{ID: "joyful", Value: "joyful", Label: L10n{My: "ရွှင်လန်း", En: "Joyful"}},
					{ID: "moody", Value: "moody", Label: L10n{My: "ဆိုးဝါး", En: "Moody"}},
					{ID: "mysterious", Value: "mysterious", Label: L10n{My: "လျှို့ဝှက်", En: "Mysterious"}},
					{ID: "energetic", Value: "energetic", Label: L10n{My: "တက်ကြွ", En: "Energetic"}},
				},
			},
			{
				ID: "text_in_image", Order: 65, Type: TypeText, Advanced: true,
				Question: L10n{My: "ပုံထဲ စာသား ထည့်ချင်လား? (မလိုရင် ကျော်)", En: "Any text in the image? (skip if none)"},
				Help:     L10n{My: "ဥပမာ- ဆိုင်းဘုတ်စာသား", En: "e.g. a sign's text"},
				Fragment: "with the text \"{value}\"",
			},
			{
				ID: "aspect", Order: 70, Type: TypeSingle,
				Question: L10n{My: "အချိုးအစား (aspect ratio)?", En: "Aspect ratio?"},
				Fragment: "{value} aspect ratio",
				Options: []Option{
					{ID: "square", Value: "1:1", Label: L10n{My: "1:1 (စတုရန်း)", En: "1:1 square"}},
					{ID: "portrait", Value: "4:5", Label: L10n{My: "4:5 (ထောင်)", En: "4:5 portrait"}},
					{ID: "photo", Value: "3:2", Label: L10n{My: "3:2", En: "3:2"}},
					{ID: "wide", Value: "16:9", Label: L10n{My: "16:9 (အလျား)", En: "16:9 wide"}},
					{ID: "story", Value: "9:16", Label: L10n{My: "9:16 (ဒေါင်လိုက်)", En: "9:16 tall"}},
				},
			},
			{
				ID: "details", Order: 80, Type: TypeText,
				Question: L10n{My: "ထပ်ဖြည့်ချင်တာ ရှိလား? (မဖြည့်လဲရ)", En: "Any extra details? (optional)"},
				Fragment: "{value}",
			},
		},
	}
}

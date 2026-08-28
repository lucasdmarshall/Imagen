import 'package:flutter/widgets.dart';

import 'state/session.dart';

/// Bilingual UI strings. Burmese is the app default; English is the optional
/// switch (from the user's profile locale). Flow question labels come from the
/// backend flow JSON (already bilingual); this covers app-side chrome.
///
/// Screens read strings via `T.of(context)`, which depends on [SessionScope],
/// so toggling the language rebuilds them automatically.
class T {
  T(this.locale);
  final String locale;

  static T of(BuildContext context) => T(SessionScope.of(context).locale);

  String pick(String my, String en) => locale == 'en' ? en : my;

  // Brand / splash
  String get tagline => pick('အဆင့်ဆင့် လမ်းညွှန်ပေးသော ပုံထုတ် Prompt စနစ်', 'Guided image prompt engine');

  // Auth
  String get welcomeBack => pick('ပြန်လည် ကြိုဆိုပါတယ်', 'Welcome back');
  String get createAccount => pick('အကောင့် အသစ်ဖွင့်ပါ', 'Create your account');
  String get name => pick('အမည်', 'Name');
  String get nameHint => pick('သင့်အမည် ထည့်ပါ', 'Your name');
  String get email => pick('အီးမေးလ်', 'Email');
  String get password => pick('စကားဝှက်', 'Password');
  String get signIn => pick('ဝင်ရောက်ရန်', 'Sign in');
  String get pleaseWait => pick('ခဏစောင့်ပါ…', 'Please wait…');
  String get haveAccount => pick('အကောင့် ရှိပြီးသားလား? ဝင်ရောက်ပါ', 'Have an account? Sign in');
  String get newHere => pick('အကောင့် မရှိသေးဘူးလား? အသစ်ဖွင့်ပါ', 'New here? Create an account');
  String get continueWithGoogle => pick('Google ဖြင့် ဝင်ရောက်ရန်', 'Continue with Google');
  String get orUseEmail => pick('သို့မဟုတ် အီးမေးလ်ဖြင့်', 'or use email');
  String get googleSetupNeeded => pick(
      'Google Sign-in ချိတ်ဆက်ရန် setup လိုအပ်သေးသည် (Client ID)',
      'Google sign-in needs setup (Client ID).');

  // Waiting Area (approval gate)
  String get waitingTitle => pick('ခဏစောင့်ပါ', "You're on the list");
  String get waitingSub => pick(
      'သင့်အကောင့်ကို Admin မှ အတည်ပြုပေးရန် စောင့်ဆိုင်းနေပါသည်။ အတည်ပြုပြီးသည်နှင့် အလိုအလျောက် ဝင်ရောက်နိုင်ပါမည်။',
      "Your account is awaiting admin approval. You'll get in automatically once approved.");
  String get checkAgain => pick('ပြန်စစ်မည်', 'Check again');

  // Home
  String hello(String n) => pick('မင်္ဂလာပါ $n', 'Hello, $n');
  String get modes => pick('လုပ်ဆောင်ချက် မုဒ်များ', 'Modes');
  String get promptGen => pick('Prompt ဖန်တီးစနစ်', 'Prompt Generator');
  String get promptGenSub =>
      pick('မေးခွန်းများကို အဆင့်ဆင့်ဖြေဆိုပြီး တိကျသော Prompt ဖန်တီးပါ', 'Build a precise prompt step by step.');
  String get imageGen => pick('ပုံ ထုတ်လုပ်စနစ်', 'Image Generator');
  String get imageGenSub => pick('Nano Banana Pro / GPT Image 2 ဖြင့် ပုံထုတ်ယူပါ',
      'Render with Nano Banana Pro or GPT Image 2.');
  String credits(int n) => pick('$n credits', '$n credits');

  // Home — editorial landing
  String get heroTitle =>
      pick('စိတ်ကူးများကို\nပုံဖော်လိုက်ပါ။', 'Turn your idea\ninto an image.');
  String get heroSub => pick(
      'မေးခွန်းလေးများကို ဖြေဆိုရုံဖြင့် ပရော်ဖက်ရှင်နယ်အဆင့် Prompt ရရှိပါမည်။',
      'Answer a few questions — get a pro-grade prompt.');
  String get ctaStart => pick('စတင် အသုံးပြုမည်', 'Start creating');
  String get showcase => pick('နမူနာ လက်ရာများ', 'Showcase');
  String get showcaseSub => pick('SHOW ဖြင့် ဖန်တီးနိုင်သော ပုံအမျိုးအစားများ',
      'What you can create with SHOW');
  String get sampleTag => pick('နမူနာ', 'sample');

  // Effects carousel / gallery
  String get effectsTitle => pick('အထူး Effect များ', 'Effects');
  String get effectsSub =>
      pick('ဓာတ်ပုံတင်ပြီး တစ်ချက်နှိပ်ရုံနဲ့', 'Upload a photo, tap once.');
  String get seeAll => pick('အားလုံး ကြည့်ရန်', 'See all');
  String get galleryTitle => pick('Effect Gallery', 'Effect Gallery');

  // Effect runner page
  String get slotUpload => pick('ပုံ တင်ရန်', 'Upload');
  String get effectRun => pick('ဖန်တီးမည်', 'Generate');
  String get effectResultHere =>
      pick('ရလဒ်ပုံ ဤနေရာတွင် ပေါ်လာပါမည်', 'Your result appears here');
  String get saveToGallery => pick('Gallery သို့ သိမ်းရန်', 'Save to gallery');
  String get savedOk => pick('သိမ်းဆည်းပြီးပါပြီ', 'Saved');
  String get needAllPhotos =>
      pick('ပုံ အားလုံး အရင် တင်ပါ', 'Please add all photos first.');
  List<String> get effectLoading => locale == 'en'
      ? const [
          'Sketching…',
          'Adding detail…',
          'Colouring…',
          'Adjusting light…',
          'Final polish…',
          'Almost done…'
        ]
      : const [
          'Sketch ဆွဲနေသည်…',
          'အသေးစိတ် ပြင်ဆင်နေသည်…',
          'အရောင် ခြယ်နေသည်…',
          'အလင်းအမှောင် ချိန်ညှိနေသည်…',
          'အချောသတ် ပြင်ဆင်နေသည်…',
          'ပြီးခါနီးပါပြီ…'
        ];

  // Bottom nav
  String get navHome => pick('ပင်မ', 'Home');
  String get navStore => pick('စတိုး', 'Store');
  String get navCredits => pick('Credits', 'Credits');
  String get navProfile => pick('ကိုယ်ရေးအချက်အလက်', 'Profile');

  // Store
  String get store => pick('စတိုး', 'Store');
  String get storeHero => pick('စိတ်ကြိုက် ပိုမိုဖန်တီးပါ', 'Create more');
  String get storeHeroSub => pick('အစီအစဉ် (Plan) ရွေးချယ်ပါ သို့မဟုတ် Credit ထပ်ဖြည့်ပါ',
      'Pick a plan, or top up credits.');
  String get subscriptions => pick('Subscriptions (အစီအစဉ်များ)', 'Subscriptions');
  String get addonCredits => pick('Credit ထပ်ဖြည့်ရန်', 'Add-on credits');
  String get renewsAuto => pick('အလိုအလျောက် သက်တမ်းတိုးပါသည်', 'Renews automatically');
  String get storeUnavailable => pick('စတိုးကို လောလောဆယ် အသုံးမပြုနိုင်သေးပါ', 'Store unavailable');
  String get free => pick('အခမဲ့', 'Free');
  String creditsAmount(int n) => pick('$n credits', '$n credits');
  String payVia(String price) =>
      pick('အောက်ပါ မိုဘိုင်းပိုက်ဆံအိတ် (Wallet) များမှ $price ပေးချေပါ', 'Pay $price via a mobile wallet below.');
  String get receiver => pick('လက်ခံသူ အမည်', 'Receiver');
  String get number => pick('ဖုန်းနံပါတ်', 'Number');
  String get iPaid => pick('ငွေလွှဲပြီးပါပြီ — အထောက်အထား တင်မည်', 'I have paid — submit proof');
  String get proofSubmitted =>
      pick('အထောက်အထား ပေးပို့ပြီးပါပြီ (စစ်ဆေးနေပါသည်)', 'Proof submitted for verification.');

  // Credits
  String get creditsTitle => pick('Credits', 'Credits');
  String get creditsAvailable => pick('ကျန်ရှိသော Credit', 'credits available');
  String get history => pick('အသုံးပြုမှု မှတ်တမ်း', 'History');
  String get noActivity => pick('မှတ်တမ်း မရှိသေးပါ', 'No activity yet');
  String get noActivitySub =>
      pick('Credit ရရှိမှုနှင့် အသုံးပြုမှု မှတ်တမ်းများ ဤနေရာတွင် ပေါ်လာပါမည်', 'Credit grants and usage will show here.');
  String reason(String r) => switch (r) {
        'grant' => pick('အစီအစဉ်မှ ပေးအပ်မှု', 'Plan grant'),
        'purchase' => pick('Credit ဝယ်ယူမှု', 'Credit pack'),
        'consume' => pick('အသုံးပြုမှု', 'Used'),
        'refund' => pick('ပြန်အမ်းငွေ/Credit', 'Refund'),
        'admin_adjust' => pick('စီမံခန့်ခွဲသူ ချိန်ညှိမှု', 'Adjustment'),
        _ => r,
      };

  // Profile
  String get profile => pick('ကိုယ်ရေးအချက်အလက်', 'Profile');
  String get account => pick('အကောင့်', 'Account');
  String get editName => pick('အမည် ပြင်ဆင်ရန်', 'Edit name');
  String get language => pick('ဘာသာစကား', 'Language');
  String get sessionLabel => pick('အကောင့် အခြေအနေ', 'Session');
  String get signOut => pick('အကောင့်မှ ထွက်ရန်', 'Sign out');
  String get displayName => pick('ပြသလိုသော အမည်', 'Display name');
  String get cancel => pick('မလုပ်တော့ပါ', 'Cancel');
  String get save => pick('သိမ်းဆည်းမည်', 'Save');
  String plan(String id) => switch (id) {
        'free' => pick('အခမဲ့ အစီအစဉ် (Free)', 'Free plan'),
        'pro_monthly' => pick('Pro (လစဉ်)', 'Pro — Monthly'),
        'pro_yearly' => pick('Pro (နှစ်စဉ်)', 'Pro — Yearly'),
        _ => id,
      };

  // Notifications
  String get notifications => pick('အသိပေးချက်များ', 'Notifications');
  String get noNotifications => pick('အသိပေးချက် မရှိသေးပါ', 'No notifications');

  // Image Generator
  String get promptLabel => pick('Prompt', 'Prompt');
  String get promptHint => pick('ဖန်တီးလိုသော ပုံအကြောင်း အသေးစိတ် ဖော်ပြပါ…', 'Describe the image…');
  String get model => pick('Model', 'Model');
  String get preview => pick('အစမ်းကြည့်ရှုရန်', 'Preview');
  String get imageAppears => pick('ဖန်တီးထားသော ပုံ ဤနေရာတွင် ပေါ်လာပါမည်', 'Your image appears here');
  String get generateImage => pick('ပုံထုတ်ယူမည် (၅ credits)', 'Generate image (5 credits)');
  String get generating => pick('ပုံထုတ်လုပ်နေပါသည်…', 'Generating…');
  String get imgRequested => pick(
      'ပုံထုတ်ရန် ပေးပို့ပြီးပါပြီ — စာကြည့်တိုက် (Library) တွင် မကြာမီ ပေါ်လာပါမည်', 'Requested. Rendering will appear in your library.');

  // Wizard chrome
  String get next => pick('ရှေ့သို့', 'Next');
  String get back => pick('နောက်သို့', 'Back');
  String get skip => pick('ကျော်မည်', 'Skip');
  String get other => pick('အခြား (စိတ်ကြိုက် ရိုက်ထည့်ရန်)', 'Other — type your own');
  String get typeHere => pick('ဤနေရာတွင် ရိုက်ထည့်ပါ', 'Type here');
  String get quick => pick('အမြန်မုဒ် (မေးခွန်း အနည်းငယ်)', 'Quick (few questions)');
  String get quickSub => pick('မေးခွန်း အနည်းငယ်ဖြင့် မိနစ်ပိုင်းအတွင်း ပြီးစီးပါမည်',
      'A few questions, done in a minute.');
  String get detailed => pick('အသေးစိတ်မုဒ် (ရွေးချယ်စရာ အားလုံး)', 'Detailed (all options)');
  String get detailedSub => pick('တိကျသေသပ်ဆုံးသော Prompt ရရှိရန် အသေးစိတ် ရွေးချယ်ပါ',
      'Every option, for the most precise prompt.');
  String get chooseDepth => pick('မည်မျှ အသေးစိတ် ပြုလုပ်လိုပါသလဲ?', 'How detailed?');
  String get chooseDepthSub =>
      pick('မိမိနှစ်သက်ရာ ဖန်တီးမှုအဆင့်ကို ရွေးချယ်ပါ', 'Pick how much control you want.');
  String get uploadPhoto => pick('ဓာတ်ပုံ တင်ရန်', 'Upload photo');
  String get changePhoto => pick('ဓာတ်ပုံ ပြောင်းရန်', 'Change');
  String get review => pick('ပြန်လည် စစ်ဆေးရန်', 'Review');
  String get yourPrompt => pick('သင်ရရှိသော Prompt', 'Your prompt');
  String get copy => pick('ကူးယူမည်', 'Copy');
  String get copied => pick('ကူးယူပြီးပါပြီ', 'Copied');
  String get enhance => pick('AI ဖြင့် ပိုမိုကောင်းမွန်အောင် ပြုပြင်မည် (၁ credit)', 'Enhance with AI (1 credit)');
  String get generateCta =>
      pick('ဤ Prompt ဖြင့် App ထဲတွင် တစ်ခါတည်း ပုံထုတ်ယူမလား?', 'Generate this image in the app?');
  String get generate => pick('ပုံထုတ်မည်', 'Generate');
  String get editStep => pick('ပြင်ဆင်မည်', 'Edit');
  String get livePreview => pick('တိုက်ရိုက် အစမ်းကြည့်ရှုရန်', 'Live preview');
  String stepOf(int a, int b) => pick('အဆင့် $a / $b', 'Step $a of $b');

  String error(Object e) => pick('ချို့ယွင်းချက်: $e', 'Error: $e');
}

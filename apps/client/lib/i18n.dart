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
  String get tagline => pick('ပုံအတွက် prompt အဆင့်ဆင့် ဖန်တီးမှု', 'Guided image prompt engine');

  // Auth
  String get welcomeBack => pick('ပြန်လည် ကြိုဆိုပါတယ်', 'Welcome back');
  String get createAccount => pick('အကောင့် ဖွင့်မယ်', 'Create your account');
  String get name => pick('အမည်', 'Name');
  String get nameHint => pick('သင့်အမည်', 'Your name');
  String get email => pick('အီးမေးလ်', 'Email');
  String get password => pick('စကားဝှက်', 'Password');
  String get signIn => pick('ဝင်မယ်', 'Sign in');
  String get pleaseWait => pick('ခဏစောင့်ပါ…', 'Please wait…');
  String get haveAccount => pick('အကောင့် ရှိပြီးသားလား? ဝင်မယ်', 'Have an account? Sign in');
  String get newHere => pick('အသစ်လား? အကောင့် ဖွင့်မယ်', 'New here? Create an account');

  // Home
  String hello(String n) => pick('မင်္ဂလာပါ, $n', 'Hello, $n');
  String get modes => pick('မုဒ်များ', 'Modes');
  String get promptGen => pick('Prompt ဖန်တီးမှု', 'Prompt Generator');
  String get promptGenSub =>
      pick('အဆင့်ဆင့် မေးခွန်းနဲ့ တိကျတဲ့ prompt', 'Build a precise prompt step by step.');
  String get imageGen => pick('ပုံ ဖန်တီးမှု', 'Image Generator');
  String get imageGenSub => pick('Nano Banana Pro / GPT Image 2 နဲ့ ထုတ်မယ်',
      'Render with Nano Banana Pro or GPT Image 2.');
  String credits(int n) => pick('$n credits', '$n credits');

  // Bottom nav
  String get navHome => pick('ပင်မ', 'Home');
  String get navStore => pick('စတိုး', 'Store');
  String get navCredits => pick('Credits', 'Credits');
  String get navProfile => pick('ကိုယ်ရေး', 'Profile');

  // Store
  String get store => pick('စတိုး', 'Store');
  String get subscriptions => pick('Subscription များ', 'Subscriptions');
  String get addonCredits => pick('Credit ထပ်ဖြည့်', 'Add-on credits');
  String get renewsAuto => pick('အလိုအလျောက် သက်တမ်းတိုး', 'Renews automatically');
  String get storeUnavailable => pick('စတိုး မရနိုင်ပါ', 'Store unavailable');
  String get free => pick('အခမဲ့', 'Free');
  String creditsAmount(int n) => pick('$n credits', '$n credits');
  String payVia(String price) =>
      pick('အောက်က wallet ဖြင့် $price ပေးပါ', 'Pay $price via a mobile wallet below.');
  String get receiver => pick('လက်ခံသူ', 'Receiver');
  String get number => pick('နံပါတ်', 'Number');
  String get iPaid => pick('ပေးပြီးပြီ — အထောက်အထား တင်မယ်', 'I have paid — submit proof');
  String get proofSubmitted =>
      pick('အထောက်အထား တင်ပြီးပါပြီ', 'Proof submitted for verification.');

  // Credits
  String get creditsTitle => pick('Credits', 'Credits');
  String get creditsAvailable => pick('credit ကျန်', 'credits available');
  String get history => pick('မှတ်တမ်း', 'History');
  String get noActivity => pick('လှုပ်ရှားမှု မရှိသေး', 'No activity yet');
  String get noActivitySub =>
      pick('Credit ရ/သုံး မှတ်တမ်း ဒီမှာ ပေါ်မယ်', 'Credit grants and usage will show here.');
  String reason(String r) => switch (r) {
        'grant' => pick('Plan ခွဲဝေ', 'Plan grant'),
        'purchase' => pick('Credit ထုပ်', 'Credit pack'),
        'consume' => pick('သုံးထား', 'Used'),
        'refund' => pick('ပြန်အမ်း', 'Refund'),
        'admin_adjust' => pick('ချိန်ညှိ', 'Adjustment'),
        _ => r,
      };

  // Profile
  String get profile => pick('ကိုယ်ရေးအချက်', 'Profile');
  String get account => pick('အကောင့်', 'Account');
  String get editName => pick('အမည် ပြင်မယ်', 'Edit name');
  String get language => pick('ဘာသာစကား', 'Language');
  String get sessionLabel => pick('Session', 'Session');
  String get signOut => pick('ထွက်မယ်', 'Sign out');
  String get displayName => pick('ပြသ အမည်', 'Display name');
  String get cancel => pick('မလုပ်တော့', 'Cancel');
  String get save => pick('သိမ်းမယ်', 'Save');
  String plan(String id) => switch (id) {
        'free' => pick('အခမဲ့ Plan', 'Free plan'),
        'pro_monthly' => pick('Pro — လစဉ်', 'Pro — Monthly'),
        'pro_yearly' => pick('Pro — နှစ်စဉ်', 'Pro — Yearly'),
        _ => id,
      };

  // Notifications
  String get notifications => pick('အသိပေးချက်', 'Notifications');
  String get noNotifications => pick('အသိပေးချက် မရှိ', 'No notifications');

  // Image Generator
  String get promptLabel => pick('Prompt', 'Prompt');
  String get promptHint => pick('ပုံကို ဖော်ပြပါ…', 'Describe the image…');
  String get model => pick('Model', 'Model');
  String get preview => pick('အစမ်းကြည့်', 'Preview');
  String get imageAppears => pick('ပုံ ဒီမှာ ပေါ်လာမယ်', 'Your image appears here');
  String get generateImage => pick('ပုံထုတ်မယ် (၅ credits)', 'Generate image (5 credits)');
  String get generating => pick('ထုတ်နေသည်…', 'Generating…');
  String get imgRequested => pick(
      'တောင်းဆိုပြီး — library မှာ ပေါ်လာပါမယ်', 'Requested. Rendering will appear in your library.');

  // Wizard chrome
  String get next => pick('ရှေ့ဆက်', 'Next');
  String get back => pick('နောက်သို့', 'Back');
  String get skip => pick('ကျော်မယ်', 'Skip');
  String get other => pick('အခြား — ကိုယ်တိုင်ရိုက်', 'Other — type your own');
  String get typeHere => pick('ဒီမှာ ရိုက်ပါ', 'Type here');
  String get quick => pick('အမြန် (မေးခွန်း အနည်းငယ်)', 'Quick (few questions)');
  String get detailed => pick('အသေးစိတ် (အကုန်)', 'Detailed (all options)');
  String get chooseDepth => pick('ဘယ်လို ဆောက်မလဲ?', 'How detailed?');
  String get uploadPhoto => pick('ဓာတ်ပုံ တင်မယ်', 'Upload photo');
  String get changePhoto => pick('ပြောင်းမယ်', 'Change');
  String get review => pick('ပြန်စစ်မယ်', 'Review');
  String get yourPrompt => pick('သင့် Prompt', 'Your prompt');
  String get copy => pick('ကူးမယ်', 'Copy');
  String get copied => pick('ကူးပြီးပြီ', 'Copied');
  String get enhance => pick('AI နဲ့ ပိုချောအောင် (၁ credit)', 'Enhance with AI (1 credit)');
  String get generateCta =>
      pick('App ထဲမှာ တစ်ခါတည်း ပုံထုတ်မလား?', 'Generate this image in the app?');
  String get generate => pick('ပုံထုတ်မယ်', 'Generate');
  String get editStep => pick('ပြင်မယ်', 'Edit');
  String get livePreview => pick('အစမ်းကြည့်', 'Live preview');
  String stepOf(int a, int b) => pick('အဆင့် $a / $b', 'Step $a of $b');

  String error(Object e) => pick('အမှား: $e', 'Error: $e');
}

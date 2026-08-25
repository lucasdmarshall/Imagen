import 'package:flutter/widgets.dart';

import 'state/session.dart';

/// Minimal bilingual UI-string helper for the wizard chrome. Burmese is the app
/// default; English is the optional switch. (Flow question labels come from the
/// backend flow JSON, already bilingual — this covers app-side chrome only.)
class T {
  T(this.locale);
  final String locale;

  static T of(BuildContext context) => T(SessionScope.of(context).locale);

  String pick(String my, String en) => locale == 'en' ? en : my;

  // Wizard chrome.
  String get next => pick('ရှေ့ဆက်', 'Next');
  String get back => pick('နောက်သို့', 'Back');
  String get skip => pick('ကျော်မယ်', 'Skip');
  String get other => pick('အခြား — ကိုယ်တိုင်ရိုက်', 'Other — type your own');
  String get typeHere => pick('ဒီမှာ ရိုက်ပါ', 'Type here');
  String get done => pick('ပြီးပါပြီ', 'Done');
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
}

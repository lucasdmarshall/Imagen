import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:show_ui/show_ui.dart';

/// A one-tap image effect shown on the home carousel and the gallery page.
///
/// [prompt] is intentionally blank for now — the exact prompt per effect will
/// be supplied later. Everything is data-driven, so filling it in is a one-line
/// change per card with no UI work.
/// A labelled input slot on an effect page. Normally a photo-upload slot; when
/// [allowText] is true the user may instead type a description (e.g. describe a
/// background in words rather than uploading a reference photo).
class EffectInput {
  const EffectInput(
    this.labelMy,
    this.labelEn, {
    this.allowText = false,
    this.textOnly = false,
    this.textLabelMy = '',
    this.textLabelEn = '',
    this.textHintMy = '',
    this.textHintEn = '',
  });
  final String labelMy;
  final String labelEn;

  /// Whether this slot can be satisfied by typed text instead of a photo
  /// (shows a Photo ⇄ Text toggle).
  final bool allowText;

  /// Whether this slot is ALWAYS a typed field (no photo option, no toggle).
  /// The typed value is substituted into the prompt's `{text}` placeholder.
  final bool textOnly;

  /// Label/hint shown for the text alternative when [allowText] is true.
  final String textLabelMy;
  final String textLabelEn;
  final String textHintMy;
  final String textHintEn;
}

class Effect {
  const Effect({
    required this.id,
    required this.titleMy,
    required this.titleEn,
    required this.subMy,
    required this.subEn,
    required this.icon,
    required this.color,
    this.prompt = '',
    this.promptText = '',
    this.inputs = const [EffectInput('သင့်ပုံ', 'Your photo')],
  });

  final String id;
  final String titleMy;
  final String titleEn;
  final String subMy;
  final String subEn;
  final HeroIcons icon;
  final Color color;

  /// The generation prompt — NEVER shown to the user.
  final String prompt;

  /// Alternate prompt used when an [EffectInput] with `allowText` is satisfied
  /// by typed text instead of a photo. Any `{text}` placeholder is replaced
  /// with what the user typed. Also never shown to the user.
  final String promptText;

  /// Photo inputs the page asks for (Outfit Swap needs two: person + outfit).
  final List<EffectInput> inputs;
}

// Matte palette, cycled across the cards (kept flat per the SHOW system).
const _c1 = ShowColors.accent; // slate blue
const _c2 = ShowColors.success; // green
const _c3 = Color(0xFF8A5A3B); // clay
const _c4 = ShowColors.warning; // ochre
const _c5 = ShowColors.danger; // brick
const _c6 = Color(0xFF3B4A7A); // indigo
const _c7 = Color(0xFF6B3F5B); // plum
const _c8 = ShowColors.grey900; // near-black
const _c9 = Color(0xFF3E6B6B); // teal

/// All effects, in order. The first five also appear on the home carousel.
const effects = <Effect>[
  Effect(
      id: 'outfit_swap',
      titleMy: 'Outfit Swap',
      titleEn: 'Outfit Swap',
      subMy: 'အင်္ကျီလဲ · မျက်နှာ/နောက်ခံ မပြောင်း',
      subEn: 'Change the outfit — keep face & background',
      icon: HeroIcons.swatch,
      color: _c1,
      inputs: [
        EffectInput('သင့်ပုံ', 'Your photo'),
        EffectInput('ပြောင်းချင်သော ဝတ်စုံပုံ', 'Outfit to apply'),
      ],
      prompt:
          "Dress the person in the first image with the clothing from the second image while preserving the exact identity, facial features, pose, body proportions, skin texture, hairstyle, lighting, camera angle, background, and overall image composition. Accurately transfer the clothing design, fit, fabric texture, colors, folds, wrinkles, shadows, accessories, and material details from the reference outfit onto the person naturally and realistically. Maintain realistic fabric draping, body tension, perspective consistency, lighting interaction, and natural clothing folds based on the person's pose and body shape. Ensure the outfit looks physically worn by the same real person, NOT pasted on or AI-generated. Preserve the original image realism exactly. Avoid distorted anatomy, warped clothing, fake fabric texture, floating accessories, unrealistic shadows, or over-stylized fashion-render effects. The final result should feel photorealistic, seamless, naturally styled, Pinterest-worthy, and indistinguishable from a real fashion outfit photo."),
  Effect(
      id: 'background_change',
      titleMy: 'Background Change',
      titleEn: 'Background Change',
      subMy: 'နောက်ခံ ပြောင်း · မျက်နှာ/ဟန်ပန် မပြောင်း',
      subEn: 'Change the background — keep face & pose',
      icon: HeroIcons.photo,
      color: _c2,
      inputs: [
        EffectInput('သင့်ပုံ', 'Your photo'),
        EffectInput(
          'နောက်ခံ ပုံ',
          'Background photo',
          allowText: true,
          textLabelMy: 'နောက်ခံကို စာနဲ့ ဖော်ပြပါ',
          textLabelEn: 'Describe the background',
          textHintMy: 'ဥပမာ — နေဝင်ချိန် ပင်လယ်ကမ်းခြေ၊ အလင်းနွေးထွေး',
          textHintEn: 'e.g. a beach at sunset with warm golden light',
        ),
      ],
      // Used when the user UPLOADS a background photo (2 images).
      prompt:
          "Take the person or main subject from the first image and place them into the environment shown in the second image, replacing the original background entirely. Preserve the exact identity, facial features, expression, hairstyle, body pose, proportions, clothing, colors, and skin texture of the subject from the first image with zero changes. Cut the subject along clean, realistic edges — including individual hair strands, fingers, and clothing outlines — with no halos, fringing, color bleed, or leftover pixels from the old background. Composite the subject into the new scene so the result reads as a single real photograph: match the second image's lighting direction, intensity, color temperature, and contrast onto the subject; add natural, physically correct contact shadows and subtle ambient reflections consistent with the new environment; and align perspective, horizon line, camera height, and subject scale so the person sits believably within the scene's depth. Keep the subject in sharp, natural focus while respecting the background's own depth of field. Do NOT distort, warp, restyle, beautify, slim, or regenerate the subject, do NOT alter their identity, and do NOT add elements that were not present. The final image must be photorealistic, seamless, and indistinguishable from a genuine photo actually taken in that location.",
      // Used when the user TYPES a background description instead ({text} = input).
      promptText:
          "Keep the person or main subject from the uploaded image exactly as they are — identical identity, facial features, expression, hairstyle, pose, body proportions, clothing, colors, and skin texture — and replace ONLY the background with the following described environment: \"{text}\". Separate the subject along clean, realistic edges, including individual hair strands, fingers, and clothing outlines, with no halos, fringing, color bleed, or leftover pixels from the original background. Generate the new background as described in a fully photorealistic style and composite the subject into it as if it were a single real photograph: relight the subject to match the described scene's lighting direction, intensity, color temperature, and mood; add natural contact shadows and subtle ambient reflections; and set perspective, camera height, subject scale, and depth of field so the person sits believably within the scene. If the description is brief, infer a coherent, natural-looking environment consistent with it. Do NOT distort, warp, restyle, beautify, slim, or regenerate the subject, and do NOT change their identity. The final image must be photorealistic, seamless, and indistinguishable from a genuine photo actually taken in that setting."),
  Effect(
      id: 'face_swap',
      titleMy: 'Face Swap',
      titleEn: 'Face Swap',
      subMy: 'မျက်နှာ ပြောင်း · နောက်ခံ/ဟန်ပန် မပြောင်း',
      subEn: 'Swap the face — keep background & pose',
      icon: HeroIcons.arrowsRightLeft,
      color: _c3,
      inputs: [
        EffectInput('မူရင်းပုံ (ကိုယ်ခန္ဓာ/နောက်ခံ)', 'Base photo (body/scene)'),
        EffectInput('ယူမည့် မျက်နှာပုံ', 'Face to apply'),
      ],
      prompt:
          "Replace ONLY the face of the person in the first image with the face and facial identity of the person in the second image, producing a single photorealistic result. Transfer from the second image the complete facial identity — face shape, bone structure, jawline, cheekbones, brow, nose, mouth, lips, eyes, eye color, eyebrows, and any distinctive marks such as moles, freckles, or facial hair — so the result is unmistakably recognizable as the person from the second image. Keep EVERYTHING ELSE from the first image exactly unchanged: the head pose and angle, gaze direction, facial expression and mouth shape, hairstyle and hairline, ears, neck, body, clothing, pose, background, framing, and composition. Seamlessly blend the new face into the first image so skin tone, texture, and color match the neck and body of the first image; relight the swapped face to follow the first image's lighting direction, intensity, softness, color temperature, shadows, and highlights. Preserve the first image's original resolution, grain, sharpness, depth of field, and camera perspective, and align the new face precisely to the original head's orientation and proportions. Render realistic skin with natural pores and micro-texture — no plastic, waxy, over-smoothed, or airbrushed look. Do NOT alter the expression, do NOT change the hairstyle or background, do NOT distort or warp facial features, and avoid double edges, ghosting, mismatched skin tone, visible seams, or a mask-like pasted-on appearance. The final image must look like a genuine, natural photograph of the second person, seamless and free of any face-swap artifacts."),
  Effect(
      id: 'halo',
      titleMy: 'Halo Effect',
      titleEn: 'Halo Effect',
      subMy: 'အလင်းတန်း Filter',
      subEn: 'Glowing halo filter',
      icon: HeroIcons.sparkles,
      color: _c4,
      prompt:
          "Relight the person in the uploaded image as a dramatic backlit rim-glow portrait, while preserving their exact identity, facial features, expression, hairstyle, body pose, and clothing shape with zero changes. Replace the background with a clean, deep solid black. Add a strong rim/backlight from behind the subject so a bright, luminous halo outline traces the edges of the hair, shoulders, and body, separating them from the black background; render the subject in a semi-silhouette with rich, controlled shadows on the front while keeping the face subtly readable — do not crush it into pure black. Keep the glowing rim light clean and continuous with a natural falloff and a soft, cinematic bloom around the brightest edges, no harsh banding or jagged outlines. Preserve realistic skin texture, hair strands, and fabric detail within the lit areas; keep the subject sharp and correctly proportioned. Use high-contrast cinematic studio lighting with a neutral-to-slightly-warm tone, deep blacks, and bright specular highlights. Do NOT distort, warp, restyle, beautify, or change the subject's identity, and do NOT add text, logos, or extra objects. The final image must be ultra-clean, photorealistic, high-contrast, and gallery-grade at 4K quality."),
  Effect(
      id: 'avengers_selfie',
      titleMy: 'Avengers Selfie',
      titleEn: 'Avengers Selfie',
      subMy: 'Avengers နဲ့ Selfie ရိုက်',
      subEn: 'Take a selfie with the Avengers',
      icon: HeroIcons.bolt,
      color: _c5,
      prompt:
          "A wide-angle selfie-style group photo at the entrance of a modern movie theater at night, bright neon marquee lights and illuminated posters behind the group, glass doors reflecting the street and the lobby glow. A tight crowd of superheroes lean into the frame with a casual \"fans photo\" energy: Thor in his armor with red cape on the left, Iron Man centered in full red-and-gold suit, Hulk towering behind everyone, Captain America in his suit on the right holding his shield partly into the lower-right of frame, Spider-Man in a classic red-and-blue suit on the far right giving a thumbs up, and Black Widow on the left in a side-tactical black suit, utility details, confident pose, leaning in close to fit the shot. The main subject is the exact person from the reference image in the foreground, closest to camera, wearing the exact same outfit from the reference image with visible details preserved. Their arm is fully outstretched toward the lens as if taking the selfie; only their hand/forearm is visible near the edge of the frame, but NO phone or device is visible at any time (hand positioned to imply holding something just out of frame). Everyone is smiling/posing for the photo, slightly compressed together, friendly and candid. Shot from slightly above eye level with strong perspective distortion from the close lens; background shows the cinema entrance stanchions and a few indistinct blurred people walking. Lighting is natural nighttime ambient plus cinema signage illumination: no flash, soft mixed light from neon marquee and poster boxes creating gentle highlights and colored reflections on suits, realistic low-light exposure with mild motion-freeze from a fast shutter, clean but slightly grainy shadows, subtle bokeh from streetlights, specular accents on Iron Man's metal and Captain America's shield without harsh hotspots. High realism, accurate proportions, detailed fabric textures, subtle wear and gloss on armor, sharp focus on the foreground subject and heroes, background softly blurred. Recreate the person from the reference image exactly. Use the reference as a strict identity and appearance guide and preserve 100% of their visible facial features, facial structure, skin tone, skin texture, facial hair, body appearance, outfit, and accessories. Do not redesign, replace, recolor, or simplify their clothing. Hair: The hair must be exactly the same as in the reference (same length, color, texture, and hairstyle). Do not invent hair, do not lengthen it, do not change it, do not add white hair or spikes. If the reference includes a cap or hat, keep it. Accessories: Preserve exactly any accessory that appears in the reference (glasses, earrings, piercings, caps, hats, necklaces, etc.), same size and position. If the reference has no accessories, do NOT add any new ones. Format: Ultra-realistic photo. Shot on a Leica M6 with 35mm Summicron. Visible 35mm film grain. Hard daylight. ISO noise in backdrop shadows, warm cast in highlighted edge, minor chromatic aberration at hairline, no styling tricks, no digital cleanup, no artificial glow. Matte skin, visible pores, light freckles. Background blurred."),
  Effect(
      id: 'pixel',
      titleMy: 'Pixel Effect',
      titleEn: 'Pixel Effect',
      subMy: '2D ဂိမ်း ဇာတ်ကောင် ပုံစံ',
      subEn: '2D game-character look',
      icon: HeroIcons.cube,
      color: _c6,
      prompt:
          "Transform the provided image into a clean, high-quality 32-bit pixel art sprite. Preserve the original composition, frame format, subject, silhouette, pose, and key identifying features so the character stays clearly recognizable as the same person — keep the same hairstyle, outfit shapes, colors, and any distinctive accessories. Use pixel-perfect geometry on a strict, uniform grid with a consistent pixel size throughout the whole image; align every edge and cluster to the grid with no stray or off-grid pixels. Apply a limited, cohesive NES/SNES-inspired palette with hard edges only — no blur, no gradients, no anti-aliasing, no smoothing, no dithering noise. Simplify lighting into flat 1-2 tone shading per surface with clean, deliberate highlight and shadow blocks. Remove micro-details, photographic noise, skin texture, fine textures, reflections, and modern HDR effects, while keeping the forms readable and well balanced. Keep the result crisp, sharp, readable, and authentic as a retro game sprite. Do NOT add outlines, text, UI, or extra objects that were not in the original, and do NOT change the pose or identity."),
  Effect(
      id: 'behind_scenes',
      titleMy: 'Behind the Scenes',
      titleEn: 'Behind the Scenes',
      subMy: 'ရုပ်ရှင် ရိုက်ကွင်း ပုံစံ',
      subEn: 'Movie behind-the-scenes look',
      icon: HeroIcons.film,
      color: _c7,
      inputs: [
        EffectInput('သင့်ပုံ', 'Your photo'),
        EffectInput(
          '',
          '',
          textOnly: true,
          textLabelMy: 'ဘယ်ရုပ်ရှင်လဲ?',
          textLabelEn: 'Which movie?',
          textHintMy: 'ဥပမာ — Titanic, Avatar, Harry Potter',
          textHintEn: 'e.g. Titanic, Avatar, Harry Potter',
        ),
      ],
      prompt:
          "Transform the uploaded photo into a raw, candid on-set behind-the-scenes snapshot from the making of the movie \"{text}\". Keep the person from the uploaded image as the actor, in full wardrobe and styling appropriate to \"{text}\", and preserve their exact identity, facial features, likeness, and body appearance with zero changes — do not beautify, restyle, or alter their face. Surround the actor with a realistic working film crew mid-shoot: a camera operator with a cinema camera on a rig, a boom microphone dipping into the top of the frame, light stands with softboxes and reflectors, tangled cables taped across the floor, a clapperboard, crew monitors, and a few crew members in casual clothes watching or adjusting gear. The set, props, and background should clearly evoke the world and setting of \"{text}\". Shot on a Sony a7S III with a 50mm lens, handheld with slightly imperfect framing, harsh mixed on-set lighting, visible ISO grain, natural mild motion, and an unpolished, authentic documentary feel — NOT a clean promotional still. Realistic proportions, natural skin texture with visible pores, sharp focus on the actor with the busy set softly present around them. Photorealistic and candid, as if secretly snapped between takes."),
  Effect(
      id: 'polaroid',
      titleMy: 'Polaroid',
      titleEn: 'Polaroid',
      subMy: '၁၉၈၀ ကင်မရာ ပုံစံ',
      subEn: '1980s Polaroid photo',
      icon: HeroIcons.camera,
      color: _c8,
      prompt:
          "Turn the uploaded image into a real, physical Polaroid instant print that is being photographed. Preserve the original subject, their exact identity, facial features, pose, and composition inside the photo area — only apply the instant-film look, do not restyle or alter the person. Render authentic Polaroid characteristics: thick matte-white film borders with the classic wider band at the bottom, a faded warm color response, gently lifted blacks, soft cyan-green shadows and warm highlights, mild vignetting, and fine instant-film grain and subtle emulsion imperfections. Present the print as a genuine physical object — either held between fingers or resting on a natural surface (table, wood, fabric) — photographed at a slight, casual angle with realistic soft shadows, gentle surface reflections on the glossy print, and a shallow depth of field so the print is the clear subject. Keep the framing believable, with the white borders fully visible and slightly imperfect. Analog, nostalgic, and photorealistic — it must look like an actual Polaroid snapshot captured with a phone, not a digital filter overlay. Do NOT add text, captions, logos, or handwriting unless they exist in the original."),
  Effect(
      id: 'time_travel',
      titleMy: 'Time Travel',
      titleEn: 'Time Travel',
      subMy: 'အီဂျစ်သို့ ခရီး',
      subEn: 'Travel back to ancient Egypt',
      icon: HeroIcons.clock,
      color: _c9,
      prompt:
          "Turn the uploaded photo into a candid 0.5x ultra-wide selfie taken by the person in the image, standing next to an ancient Egyptian pharaoh in a fully intact temple courtyard at the height of its prime. Keep the person from the uploaded image as the foreground selfie-taker, closest to the camera, and preserve their exact identity, facial features, likeness, hairstyle, and body appearance with zero changes — do not beautify or restyle their face. Their arm is outstretched toward the lens in a natural selfie pose, with only the hand/forearm near the frame edge and NO phone or device visible. Beside or just behind them, place a regal pharaoh in authentic full ceremonial regalia — nemes headdress, gold and lapis ornamentation, linen garments — posed candidly for the photo. Surround them with a pristine, brand-new temple: towering painted columns with crisp hieroglyphs, vivid pigments, polished stone, and gleaming gold accents, with NO decay, ruins, cracks, erosion, or weathering. Hard bright desert sunlight with strong directional shadows, a warm dusty haze, and sand underfoot. Absolutely NO modern objects, clothing, technology, signage, or anachronisms anywhere in the scene. Ultra-wide-lens perspective with mild edge distortion, realistic proportions, natural skin texture with visible pores, sharp foreground focus, photorealistic and candid — as if a real time traveler snapped it on the spot."),
  Effect(
      id: 'upscale_4k',
      titleMy: '4K Upscaler',
      titleEn: '4K Upscaler',
      subMy: 'ပုံ ပိုကြည်လင်စေ',
      subEn: 'Make the photo sharper (upscale)',
      icon: HeroIcons.arrowTrendingUp,
      color: _c1,
      prompt:
          "Ultra-high-resolution 4K enhancement based strictly on the provided reference image. Absolute fidelity to the original facial anatomy, proportions, and identity. Preserve expression, gaze, pose, camera angle, framing, and perspective with zero deviation. Clothing, hair, skin, and background elements must remain unchanged in structure, placement, and design. Recover fine-grain detail with natural realism. Enhance pores, fine lines, hair strands, eyelashes, fabric weave, seams, and material edges without introducing stylization. Maintain the original color science, white balance, and tonal relationships exactly as captured. Lighting direction, intensity, contrast, and shadow behavior must match the source image precisely, with only improved clarity and expanded dynamic range — no relighting, no reshaping. Remove any grain, apply controlled sharpening with high-frequency detail reconstruction. Remove compression artifacts and noise while retaining authentic texture. No smoothing, no plastic skin, no artificial gloss. Facial features must remain consistent across the entire image with coherent anatomy and clean, stable edges. Negative constraints: no warping, no facial drift, no added or missing anatomy, no altered hands, no distortions, no perspective shift, no text or graphics, no hallucinated detail, no stylized rendering. The output must read as a true-to-life, photorealistic upscale that matches the reference exactly — only clearer, sharper, and higher resolution."),
  Effect(
      id: 'skin_enhancer',
      titleMy: 'Skin Enhancer',
      titleEn: 'Skin Enhancer',
      subMy: 'အရေးအကြောင်း/အဖု ဖျက်',
      subEn: 'Remove blemishes & wrinkles',
      icon: HeroIcons.faceSmile,
      color: _c2,
      prompt:
          "Natural skin-enhancement retouch of the person in the uploaded image. Preserve the original identity, facial structure, and proportions exactly. Refine skin texture WITHOUT smoothing — maintain pores, freckles, moles, and natural skin variation. Reduce only temporary blemishes, spots, and redness; even out skin tone subtly without flattening depth or dimension. Retain natural highlights and gradual shadow transitions. Keep under-eye detail intact with only slight softening, never full removal. Avoid any plastic, waxy, or airbrushed finish. Maintain the original lighting, white balance, and color exactly. Enhance micro-contrast for realistic, tactile texture. Leave lips and eyes untouched except for natural clarity. Do NOT reshape or slim any facial features, do NOT add artificial glow, and do NOT over-sharpen. The edit must integrate seamlessly with the original image — an invisible, high-realism retouch that looks like naturally healthy skin, not a filter."),
  Effect(
      id: 'id_photo',
      titleMy: 'လိုင်စင်ဓာတ်ပုံ',
      titleEn: 'ID Photo',
      subMy: 'တရားဝင် လိုင်စင်/ID ဓာတ်ပုံ',
      subEn: 'Official ID / passport photo',
      icon: HeroIcons.identification,
      color: _c3,
      prompt:
          "Image-edit directive: convert the subject from the input photo into a clean, professional studio headshot while preserving their exact identity, facial structure, clothing, hairstyle, and accessories from the original image. Studio portrait look with tight head-and-shoulders framing, centered composition, a neutral confident expression, and eyes looking directly toward the camera — the professional talent-headshot aesthetic used by casting agencies and magazine profiles. Background: a minimal, seamless light-gray studio backdrop with soft falloff, no visible texture or environment. Lighting: high-end three-point setup with a key light slightly above eye level, bounced fill, and a subtle rim light behind the subject to separate them from the background; even illumination across the face with a gentle shadow under the jawline, and clear catchlights in both eyes. Camera at eye level, shot on an 85mm portrait lens, crisp focus on the eyes with a shallow depth of field so the ears and shoulders fall slightly softer. Skin rendering realistic and professional — natural pores visible, subtle skin texture, no plastic smoothing. Balanced color grading, neutral skin tones, clean contrast. Hair carefully groomed but natural with individual strands visible. Keep the clothing preserved, looking magazine-professional yet realistic. Remove temporary blemishes only; keep the facial structure, freckles, pores, and fine lines. Do NOT reshape facial features or change identity. Final look: a polished, agency-grade professional headshot."),
  Effect(
      id: 'product_ad',
      titleMy: 'Product ကြော်ငြာ',
      titleEn: 'Product Ad',
      subMy: 'ပရော်ဖက်ရှင်နယ် Product ကြော်ငြာ',
      subEn: 'Professional product ad shot',
      icon: HeroIcons.shoppingBag,
      color: _c4,
      prompt:
          "Product studio transformation: isolate the product from the reference image and rebuild it into a premium advertising composition, while preserving the product's exact identity, shape, label, branding, colors, and material as in the original — do not redesign, relabel, or alter the product itself. Place the hero product centered and sharply in focus, surrounded by its key ingredients arranged with intention and depth. Show the ingredients fresh and tactile — sliced, crushed, or whole depending on context. Keep the composition balanced but not perfectly symmetrical, on a clean surface with subtle reflections. Design the background to match the product's own color palette and mood, using soft gradients or tonal transitions. Use high-end studio lighting with controlled highlights and gentle shadow falloff; keep crisp edges with a slight natural contact shadow grounding the product. Render micro-details — condensation, ingredient texture, and fine surface imperfections. Use minimal but intentional negative space with no clutter beyond the ingredients. Deliver a polished commercial finish that never looks artificial, with accurate color rendering and realistic material response. Do NOT add text, logos, or graphics that are not already on the product."),
  Effect(
      id: 'anime',
      titleMy: 'Anime',
      titleEn: 'Anime',
      subMy: 'ကာတွန်း/Anime ပုံစံ',
      subEn: 'Anime cartoon style',
      icon: HeroIcons.star,
      color: _c5,
      prompt:
          "Anime-style transformation: convert the reference image into a detailed hand-drawn anime illustration while preserving the exact composition, same camera angle, framing, pose, and character proportions unchanged. Maintain the identical facial structure and expression, translated faithfully into an anime aesthetic so the character stays clearly recognizable as the same person. Use clean linework with controlled variation in line weight, large expressive eyes styled naturally to match the original gaze direction, and a simplified but accurate nose and mouth. Reinterpret the hair into defined anime strands with subtle shading, preserving its original shape and flow, with smooth tonal shading and soft gradients. Preserve the lighting direction and intensity from the original image. Keep colors slightly stylized but faithful to the source palette. Convert the background into an anime environment that matches the original depth and perspective. Apply subtle cel shading with gentle highlights. No distortion of anatomy or perspective, no change in crop or zoom. Aim for a high-fidelity anime adaptation of the original rather than a free reinterpretation."),
  Effect(
      id: 'oil_painting',
      titleMy: 'Oil Painting',
      titleEn: 'Oil Painting',
      subMy: 'ဆီဆေး ပန်းချီ',
      subEn: 'Oil painting',
      icon: HeroIcons.paintBrush,
      color: _c6,
      prompt:
          "Surreal mid-century editorial illustration of an eccentric version of the person in the photo and an elegant white cat inside a stylish 1960s French Riviera cafe terrace, elongated proportions, exaggerated narrow faces, deadpan expressions, oversized accessories, bizarre fashionable atmosphere, painterly brush textures, distorted anatomy, subtle lowbrow surrealism, sophisticated absurdity, vivid retro color palette dominated by teal, mustard yellow, and burnt coral, expressive oil-painted strokes, fashionable vintage clothing, dramatic jewelry and eyewear, whimsical background characters softly blurred in the distance, elegant cafe culture energy, cinematic composition, textured painted backdrop, contemporary art gallery meets 1960s Riviera illustration, highly stylized editorial aesthetic, vertical composition 4:5. Keep the person clearly recognizable as the same individual — preserve their core facial identity, hairstyle, and likeness even within the stylized painterly treatment. Do NOT add text, captions, or logos."),
  Effect(
      id: 'gender_switch',
      titleMy: 'Gender Switch',
      titleEn: 'Gender Switch',
      subMy: 'ကျား/မ ပြောင်း',
      subEn: 'Switch gender',
      icon: HeroIcons.userGroup,
      color: _c7,
      prompt:
          "Reimagine the person in the uploaded image as the opposite gender, as if this were their natural sibling of the other sex, while keeping them clearly recognizable as the same individual. Detect the subject's current presented gender and convincingly transform it to the opposite one. Preserve the underlying identity cues — overall face shape, skin tone, ethnicity, approximate age, distinctive features (moles, freckles, eye color), pose, head angle, expression, and gaze direction. Adapt gender-specific characteristics naturally and anatomically correctly: reshape the jawline, brow ridge, cheekbones, nose, and lips to suit the target gender; adjust the hairline and give a natural, flattering hairstyle appropriate to that gender; for a male result add realistic, tasteful facial hair or a clean shave and a slightly stronger jaw and neck, and for a female result soften the features, refine the brow, add subtly fuller lips and natural light makeup, and a smoother complexion. Adjust body build, shoulders, and neck subtly to match. Update the clothing to a natural, era-appropriate outfit fitting the new gender while keeping a similar style and color mood to the original. Keep the original background, framing, camera angle, and lighting direction, intensity, and color temperature unchanged. Render photorealistic skin with natural pores and texture — no plastic, waxy, or airbrushed look. Do NOT caricature, over-sexualize, or exaggerate; the result must look like a real, believable everyday photo of a real person. Avoid distorted anatomy, mismatched skin tone, asymmetry, or uncanny artifacts. Photorealistic and seamless."),
  Effect(
      id: 'age_switch',
      titleMy: 'Age Switch',
      titleEn: 'Age Switch',
      subMy: 'အသက်အရွယ် ပြောင်း',
      subEn: 'Change age',
      icon: HeroIcons.userCircle,
      color: _c8,
      inputs: [
        EffectInput('သင့်ပုံ', 'Your photo'),
        EffectInput(
          '',
          '',
          textOnly: true,
          textLabelMy: 'ဘယ်အသက်ကို ပြောင်းမလဲ?',
          textLabelEn: 'Change to what age?',
          textHintMy: 'ဥပမာ — ၈ နှစ်၊ ၂၅ နှစ်၊ ၇၀ နှစ်',
          textHintEn: 'e.g. 8 years old, 25, 70',
        ),
      ],
      prompt:
          "Realistically change the apparent age of the person in the uploaded image to approximately {text}, while keeping them unmistakably recognizable as the same individual. Preserve their core identity — bone structure, face shape, skin tone, ethnicity, eye color, distinctive features (moles, freckles), pose, head angle, expression, gaze direction, hairstyle intent, background, framing, and lighting. Apply anatomically accurate, age-appropriate changes only. For a younger target: smoother skin, fuller and rounder facial fat, softer and less defined bone structure, brighter eyes, fuller hairline, smaller and less mature proportions consistent with a child or youth, and no facial hair if too young. For an older target: add natural, age-appropriate wrinkles and fine lines (forehead, around the eyes and mouth, neck), subtle skin sagging and volume loss, slightly thinner or greying/whitening hair and receding hairline, age spots, less elastic skin, and more pronounced bone definition. Scale facial proportions correctly for the target age (children have larger eyes and foreheads relative to the face; older adults show gradual bone and soft-tissue changes). Keep the transformation believable and gradual — do NOT distort identity, change ethnicity, or produce a mask-like or morphed look. Render photorealistic skin with natural pores and texture appropriate to the age — no plastic, waxy, or airbrushed finish. Keep the original clothing and scene unless they must change to suit the age, and match the original lighting direction, intensity, and color temperature. Avoid uncanny artifacts, asymmetry, and unnatural smoothing. Photorealistic and seamless."),
  Effect(
      id: 'body_enhancer',
      titleMy: 'Body Enhancer',
      titleEn: 'Body Enhancer',
      subMy: 'ကိုယ်လုံး အချိုးအစား လှအောင်ပြင်',
      subEn: 'Refine the body shape',
      icon: HeroIcons.user,
      color: _c9,
      prompt:
          "Ultra-realistic, tasteful body reshape of the person in the uploaded photo while preserving their exact identity, pose, camera angle, facial features, skin texture, lighting, clothing, and background. Enhance the physique with a sharper waistline, more defined abs, broader shoulders, a fuller chest, more balanced and natural body curves, longer-looking legs, and a stronger athletic silhouette — while maintaining realistic anatomy and natural body proportions. Maintain accurate skin texture, natural shadows, realistic muscle definition, correct fabric stretching and draping over the new shape, and lighting consistency. The transformation should feel like an elite fitness version of the same real person — NOT plastic surgery, CGI, competitive bodybuilding, or exaggerated Instagram editing. Preserve the original perspective, facial identity, hairstyle, composition, and background exactly. Avoid distorted limbs, fake or floating abs, warped backgrounds, AI beauty-filter skin, extra or missing anatomy, and unrealistic proportions. The final result should feel photorealistic, seamless, naturally attractive, and indistinguishable from a real high-end fitness transformation photo."),
  Effect(
      id: 'clothing_color',
      titleMy: 'Clothing Color Switch',
      titleEn: 'Clothing Color Switch',
      subMy: 'အဝတ်အစား အရောင် ပြောင်း',
      subEn: 'Change the outfit colour',
      icon: HeroIcons.swatch,
      color: _c1,
      inputs: [
        EffectInput('သင့်ပုံ', 'Your photo'),
        EffectInput(
          '',
          '',
          textOnly: true,
          textLabelMy: 'ဘယ်အရောင်ကို ပြောင်းမလဲ?',
          textLabelEn: 'Change to which colour?',
          textHintMy: 'ဥပမာ — အနီရင့်၊ အပြာနက်၊ အဖြူ',
          textHintEn: 'e.g. deep red, navy blue, white',
        ),
      ],
      prompt:
          "Detect the main outfit/clothing of the person in the uploaded image and change ONLY its color to {text}, while preserving the exact identity, pose, camera angle, facial features, skin texture, hairstyle, lighting, shadows, accessories, and background. Recolor the entire garment consistently, including all its parts, so it reads as naturally that color. Maintain realistic fabric texture, natural wrinkles, accurate highlights, tonal depth, clothing folds, seams, patterns, and lighting consistency, so the material still looks like real cloth in the same light. Ensure the new color blends naturally into the original image without color bleeding onto skin, hair, accessories, or background, and without fake textures or artificial shading. Do not change the garment's design, cut, fit, or texture — only its hue. Preserve the original composition, proportions, and overall image realism exactly. Avoid warped clothing, over-smoothing, unrealistic reflections, muddy or flat color, and AI-generated fashion-render details. The final result should feel photorealistic, seamless, naturally styled, and indistinguishable from a real professionally photographed outfit in that color."),
  Effect(
      id: 'facial_expression',
      titleMy: 'Facial Expression',
      titleEn: 'Facial Expression',
      subMy: 'မျက်နှာ အမူအရာ ပြောင်း',
      subEn: 'Change the facial expression',
      icon: HeroIcons.faceSmile,
      color: _c2,
      prompt:
          "Change the facial expression of the person in the photo to a naturally attractive soft smile, with a subtle eye-smile (gentle Duchenne warmth) and warmer facial energy. Preserve the exact identity, facial features, eye shape, skin texture, hairstyle, lighting, pose, camera angle, and background. Enhance the expression with slightly lifted mouth corners, softer eyes, relaxed cheeks, and realistic natural smile lines, while maintaining accurate facial anatomy and photorealistic texture. Keep any teeth realistic and natural if the smile shows them, matching the person; if the original mouth is closed, keep a closed or barely-parted soft smile rather than inventing a full toothy grin. Maintain realistic lighting consistency, authentic skin detail, and believable facial-muscle movement. The smile should feel emotionally natural, confident, charming, and clearly noticeable without looking exaggerated or fake. Preserve the original composition and overall realism exactly. Avoid AI-generated or fake-looking teeth, distorted facial proportions, plastic skin, uncanny symmetry, and overdone beauty-filter effects. The final result should feel photorealistic, seamless, noticeably more attractive, Pinterest-worthy, and indistinguishable from a real candid iPhone portrait."),
  Effect(
      id: 'face_smoothen',
      titleMy: 'Face Smoothen',
      titleEn: 'Face Smoothen',
      subMy: 'မျက်နှာ ချောမွတ်အောင် ပြင်',
      subEn: 'Smoothen the face',
      icon: HeroIcons.sparkles,
      color: _c3,
      prompt:
          "Smoothen and refine the facial skin of the person in the photo for a clean, polished, glowing complexion, while preserving their exact identity, facial features, expression, eye shape, hairstyle, pose, camera angle, and background. Even out the skin tone; soften blemishes, acne, spots, dark marks, redness, and uneven patches; gently reduce harsh wrinkles and under-eye shadows; and give the skin a smooth, healthy, well-lit finish. Keep the result natural and believable — retain fine skin micro-texture and subtle pores so the skin still looks real, not plastic. Do NOT fully erase all texture, do NOT reshape or slim any facial features, do NOT change the eyes, nose, mouth, jawline, or bone structure, and do NOT alter identity. Maintain realistic lighting consistency, authentic highlights and shadow transitions, and natural color balance. Avoid an airbrushed, waxy, blurred, or over-smoothed look, uncanny symmetry, and heavy beauty-filter artifacts. The final result should feel photorealistic, seamless, naturally flawless, and indistinguishable from a professionally retouched real portrait."),
];

/// The first five effects shown in the home carousel (the rest live in Gallery).
List<Effect> get homeEffects => effects.take(5).toList();

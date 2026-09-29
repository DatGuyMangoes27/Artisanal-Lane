# Artisan Lane Creator Commerce Preview

This is a private Android sales preview built into the existing Artisan Lane
Flutter app. The preview build installs alongside production as **Artisan Lane
Preview** (`com.artisanallane.artisanal_lane.preview`) and opens directly into
the new experience.

## What is live and testable

- Feed and creator stories populated from the live Artisan Lane catalogue and
  shop-post sources, with follow, like, comment, save and share interactions.
- Tinder-style taste builder with a draggable, tilting card: swipe left to skip
  or right to love, with snap-back, decision stamps and matching button actions.
- Searchable Shop, filters and gift-concierge interaction.
- Creator profile, custom-order prompt, Create Post and linked product.
- Camera, gallery and a built-in product photo for a reliable recorded demo.
- AI Studio with a real before/after product example, prompt, store-style
  choices, brightness/warmth editing, native crop/straighten, generated listing
  suggestions, product-derived tags and image export.
- Both the real listing and showcase result open into a full-screen viewer with
  pinch-to-zoom and drag-to-inspect controls.
- Authenticated image upload through the existing Supabase Storage service.

The checked-in AI nursery scene is the reliable generated showcase result. The
internal preview demonstrates the complete journey and provides working local
image editing/export around uploaded images; arbitrary new prompt-to-image
generation remains outside this private showcase build.

## Suggested 90-second recording

1. Launch **Artisan Lane Preview** and show that Feed is populated with real
   artisan content.
2. Tap Discover, drag a card slightly to show snap-back, then swipe left and
   right to show preference learning. The buttons remain available.
3. Open Shop, search for a product, and show the reason for its recommendation.
4. Open You, tap Create post, then Add media. Choose **Use demo product photo**
   so the recording does not depend on gallery permissions.
5. Tap **Polish with AI**, then **Load test photo**. Show Crop and straighten,
   choose a store style, adjust the sliders, and press Generate image.
6. Scroll through the product-specific title, price, description and tags.
7. Finish with **Export & upload edited image**.

## Validation

- `flutter analyze`: no new issues in the preview changes; the wider project
  still reports 25 pre-existing lint items.
- `flutter test test/creator_commerce_mockups_test.dart`: 16 tests passed.
- Android debug APK: built and installed successfully on the connected device.
- On-device: live data, a left Discover swipe changing from product 1 to 2,
  media selection, native crop editor, generation state, pixel export and
  authenticated Supabase upload were exercised successfully.

## Rebuild

```powershell
C:\Users\st3ph\flutter\bin\flutter.bat build apk --debug --dart-define=CREATOR_COMMERCE_PREVIEW=true
```

The distributable internal APK is in `builds/` beside this file.

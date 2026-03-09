# Product Video Upload — Design Doc
Date: 2026-02-27

## Summary
Allow sellers to upload one optional video per product. Max 100 MB, max 60 seconds. Formats: MP4, MOV, WebM. Video stored in R2 (same bucket as images). Buyers see a thumbnail + play button that opens a fullscreen player.

## Architecture

### Upload Flow (Add Product)
1. Seller picks video via `image_picker.pickVideo`
2. Client validates: size ≤ 100 MB, duration ≤ 60s (via `video_player` probe), MIME ∈ {mp4, mov, webm}
3. Calls `upload_product_video` CF → receives `{ uploadUrl, publicUrl }`
4. HTTP PUT raw bytes directly to R2 (bypasses CF payload limit)
5. `publicUrl` stored in `AddProductState`
6. `createProductAtomic` payload includes `videoUrl: publicUrl`
7. Backend whitelists CDN prefix → stores `videoUrl` in Firestore

### Edit Flow
- Seller opens edit screen → sees existing video thumbnail + "Replace" / "Remove" buttons
- Replace: same upload flow → `update_product { videoUrl: newUrl }` → backend deletes old R2 object
- Remove: `update_product { videoUrl: null }` → backend deletes R2 object

### Buyer View (Product Detail)
- If `product.videoUrl != null`: show thumbnail with play icon in image gallery
- Tap → fullscreen `chewie` / `VideoPlayerController` overlay

### R2 Storage Path
`{env}/products/video/{uuid}.{ext}`

### Firestore Field
`videoUrl: String?` on the `products` collection (optional, no index needed)

## New Cloud Functions
- `upload_product_video`: auth + onboarding check, MIME whitelist, rate limit (3/min per seller), returns `{ uploadUrl, publicUrl }`
- Extend `create_product_atomic`: accept optional `videoUrl` string, validate CDN prefix
- Extend `update_product`: accept optional `videoUrl` (null = delete), validate CDN prefix, delete old R2 object

## Validation Matrix

| Check | Where |
|---|---|
| Size ≤ 100 MB | Client |
| Duration ≤ 60s | Client (`video_player` probe) |
| MIME type whitelist | Client (extension) + Backend (content-type header) |
| `videoUrl` CDN prefix whitelist | Backend (create + update) |
| Auth + onboarding complete | Backend |
| Rate limit: 3 uploads/min | Backend |
| 1 video per product | Client state + backend overwrite-on-replace |
| Orphan R2 objects on failed product creation | R2 lifecycle rule: purge unlinked after 24h |
| Tampered `videoUrl` pointing to foreign CDN | Backend prefix whitelist |

## Supported MIME Types
- `video/mp4` (.mp4)
- `video/quicktime` (.mov)
- `video/webm` (.webm)

## Implementation Waves

### Wave 1 — Schema & Constants
- `functions/utils/schema_constants.py`: `VIDEO_URL`, `MAX_VIDEO_BYTES = 100 * 1024 * 1024`, `MAX_VIDEO_DURATION_SECONDS = 60`, `ALLOWED_VIDEO_MIME_TYPES`
- `origna_gta/lib/core/schema/schema_constants.dart`: mirror all constants + `CloudFunctionEndpoints.uploadProductVideo`
- `pubspec.yaml`: add `video_player`, `chewie`
- `en.json` / `fr.json`: 8 translation keys (see below)

### Wave 2 — Backend
- `functions/handlers/products.py`:
  - New `upload_product_video` CF
  - Extend `create_product_atomic` to accept + validate `videoUrl`
  - Extend `update_product` to handle `videoUrl` replace/remove (delete old R2 object)
- `functions/main.py`: register `upload_product_video`

### Wave 3 — Dart State + Repo
- `add_product_state.dart`: add `XFile? videoFile`, `String? videoUrl`, `int? videoDurationSeconds`
- `add_product_viewmodel.dart`: `pickVideo()`, `removeVideo()`, `_validateVideo()`, pass video through create flow
- `product_repository.dart`: `uploadProductVideo(XFile)` → presigned URL → R2 PUT → return publicUrl
- Freezed product model: add `String? videoUrl`

### Wave 4 — UI
- `addproduct_screen.dart`: video picker widget below images (optional label, file size hint)
- Edit product screen: video replace/remove controls
- Product detail screen: video thumbnail card + fullscreen player

### Wave 5 — Tests
- Unit: video validation (size, duration, MIME) in ViewModel
- E2E (`add-product-e2e.spec.ts`): add product with video (happy path), oversized rejection, remove video in edit

## Translation Keys
```json
"video_optional": "Product Video (optional)",
"video_add": "Add Video",
"video_remove": "Remove Video",
"video_replace": "Replace Video",
"video_ready": "Video ready — {duration}s",
"video_too_large": "Video exceeds 100 MB limit",
"video_too_long": "Video must be 60 seconds or less",
"video_invalid_format": "Unsupported format. Use MP4, MOV, or WebM."
```

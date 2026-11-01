---
name: iphone-duo-support
description: Add or audit iPhone Duo (foldable inner and outer display) support in an iOS app, using the iOS 27.1 SDK in Xcode 27.1. Use when the user mentions iPhone Duo, the foldable iPhone, inner or outer display, hinge, reserved regions, ArrangementView, vertical toolbars on iPhone, or Device Hub Duo poses, even if they only say "make it work on the fold". Prefer this over generic iPad split-view or AirPlay work.
---

# iPhone Duo support

Make an iPhone app resize and stay usable on Apple's foldable: compact **outer** display when closed, large **inner** display when open, and a **folding region** when partially open. Apple's rule is to adapt by **size class and container bounds**, not by idiom or orientation.

## Source of truth

Read `references/apple-docs.md` before writing layout code. Official Apple pages beat blog posts.

Local Xcode `DocumentationSearch` is empty for Duo unless the Mac runs **Xcode 27.1**. When it misses, fetch the DocC JSON, which has the same content as the HTML:

`https://developer.apple.com/tutorials/data/documentation/technologyoverviews/preparing-your-app-for-iphone-duo.json`

**Xcode 27.2 is not a shortcut.** Its release notes send you to the Xcode 27.1 beta for the iPhone Duo SDK and simulator. Build Duo work with 27.1.

**AirPlay and HDMI are not Duo.** An `UIWindowSceneSessionRole.windowExternalDisplayNonInteractive` scene is a TV. Duo's outer display is a second *built-in* panel. A camera capture accessory is the only Apple-documented way for an app on the inner display to show extra content on the outer one, and only during rear-camera capture.

## Why a rebuild is not enough

Rebuilding with the iOS 27.1 SDK matters: older SDKs leave letterboxed compatibility layouts, while 27.1 reaches the screen edge and turns system bars vertical in some poses. The remaining work is the phone-first layout habit:

- `UIRequiresFullScreen` and a portrait-only `UISupportedInterfaceOrientations` do not stop the resize when the phone opens or closes.
- Layout that branches on `UIDevice.current.userInterfaceIdiom` stays on the compact path, because the inner display is still `.phone` with **regular** width.
- Anything that caches `UIScreen.main` geometry at launch goes stale on the first open or close.
- Capture code that assumes one front camera now meets a virtual device that switches between two.

## Steps

### 1. Toolchain

Confirm `xcodebuild -version` is **27.1** (beta is fine) and the iOS 27.1 SDK is present. Confirm Device Hub lists **iPhone Duo**.

Missing simulator: stop and say so. Do not fake Duo with an iPad destination or Xcode 27.2.

**Done when:** the 27.1 SDK and a Duo destination are real on this Mac.

### 2. Inventory the surface, then pick one

Name the user-visible surface (home, player, paywall, scanner). Search that surface for the seeds in `references/audit-checklist.md`.

**Done when:** you have a written list of Duo-sensitive calls on that surface, each with a file path.

### 3. Resize with size class and scene bounds

Replace idiom and orientation *layout* branches with `horizontalSizeClass` and `verticalSizeClass` (SwiftUI `@Environment`, UIKit automatic trait tracking). Size views against the container or `UIWindowScene` bounds.

An orientation mask does not pin the inner display the way it pins a slab iPhone: the scene still scales. Verify that in Device Hub before widening the mask, and unlock landscape only where the surface already supports it.

`UIRequiresFullScreen` does not skip the open and close resize. Do not add it as a workaround.

Hinge angle (`onHingeChange`, `UIHingeInteraction`) drives effects, such as a control that bends with the fold. Layout reads **arrangement** and **reserved regions**.

**Done when:** the surface's layout decisions read size class or container bounds, and hinge is unused for pane placement.

### 4. System bars, then arrangement, then reserved regions

**Bars.** Prefer `NavigationStack`, `UINavigationController` and `UITabBarController` so the system can place bars on the side. Give every toolbar item that must appear vertically both a **symbol and a title**. Title-only items and untitled custom views stay in the horizontal bar. Opt out with `toolbarVerticalBehavior(.disabled)` or `preferredVerticalBarBehavior` only for immersive surfaces such as a video player.

**Arrangement.** Two related regions (player and queue, list and detail, video and chrome) belong in `ArrangementView` or `UIArrangementViewController`.

- Side-by-side or stacked siblings use `.split`, which replaces `HStack` and `VStack`.
- Foreground over background uses `.overlay`, which replaces `ZStack`.

Place navigation *around* the arrangement, never inside it. Do not nest an arrangement in `List`, `ScrollView` or `NavigationSplitView`.

**Reserved regions.** System containers already avoid the fold and cameras. Custom drawing, grids and absolute frames query `reservedRegions`.

- `.division` is the hinge when partially open (`isActive` flips; fully open means inactive with zero width). Prefer an even column count when any division exists, including an inactive one.
- `.occlusion` is the outer camera always, and the inner camera only while it is on.

Pass `.includeInactive` explicitly. For hardware-aligned frames in RTL, use SwiftUI `layoutDirectionBehavior: .fixed`.

**Done when:** bars come from navigation containers, two-pane screens use an arrangement, and every custom overlay you touched consults reserved regions instead of a guessed hinge inset.

### 5. Camera and second display, only if the surface captures

- Today's `.front` wide and ultra-wide device is the **virtual** front camera on Duo. It keeps working and switches between outer and inner for you, limited to what they share (no depth; 1080p60 cap).
- For direction relative to a preview view, use `AVCaptureDeviceDirectionCoordinator` (AVKit). `position` is where the camera sits, not which way it faces. Set mirroring from the direction map, and set `automaticallyAdjustsVideoMirroring = false` before `isVideoMirrored`.
- For outer-display UI during **rear** capture on the inner display, use `CameraCaptureAccessory` or `UISceneAccessory.cameraCapture`. The system owns it and withdraws it when capture stops or the phone closes, so never put essential UI only there.

The simulator has **no camera**. Capture and accessories need hardware.

**Done when:** capture sites either stay on the virtual front camera or adopt the coordinator, and accessory UI is optional.

### 6. Prove it on poses

Walk `references/pose-matrix.md` on the Duo simulator. Capture screenshots of the surface closed, open in portrait, open in landscape, and half-folded.

New layout code gets tests that assert size-class and reserved-region behaviour, not `userInterfaceIdiom == .phone`. Snapshot tests that pin one iPhone frame are not Duo proof.

Guard Duo-only APIs with `#available(iOS 27.1, *)` unless the deployment target has moved.

**Done when:** the pose-matrix rows for the touched surface are checked and tests cover the new branches.

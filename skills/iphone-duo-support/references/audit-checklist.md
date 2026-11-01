# What to search for

Prefer converting an existing branch to size class over a second code path keyed on "is Duo".

| Search for | Why it breaks | What to do |
|---|---|---|
| `userInterfaceIdiom` | The inner display is `.phone` with regular width, so tablet layouts never run | Branch on size class |
| `UIScreen.main` | Ambiguous on two displays, and stale if cached at launch | Use the container, or the window scene's screen |
| Hardcoded widths and phone-frame constants | The display changes under a running scene | Lay out against the container |
| `UIInterfaceOrientation`, `supportedInterfaceOrientations` | A portrait mask does not keep the inner display phone-shaped | Keep the mask for orientation only, not layout |
| `UIRequiresFullScreen` | Does not prevent the resize | Remove any reliance on it |
| Custom `UIToolbar`, `UINavigationBar`, `UITabBar` | Bars outside a navigation container cannot move to the side | Move them into the container, or query reserved regions |
| `AVCaptureDevice`, `UIImagePickerController` | The front camera is now virtual and can change direction mid-session | See step 5 of the skill |
| External display scene delegates | These are AirPlay and HDMI, not the outer display | Leave them alone |

## Tests that pin a slab iPhone

- UI test destinations fixed to one iPhone model. Add Duo as a separate lane rather than retargeting the existing suite.
- Snapshot tests with a fixed width and height. Add regular-width snapshots only for components you rearrange.
- Tests asserting a portrait lock. Re-read them when the orientation mask changes.

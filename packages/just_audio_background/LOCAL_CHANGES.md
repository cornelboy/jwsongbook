# Local changes

This package is vendored from `just_audio_background` 0.0.1-beta.17.

JW Songs keeps a local patch because the upstream single-item player does not
expose previous and next notification actions when its internal queue has only
one item. The patch:

- exposes remote previous and next command streams;
- always publishes previous, play/pause, and next notification controls;
- forwards edge previous/next commands to the app's catalog navigation; and
- omits the stop action from the compact media notification.

Keep this directory tracked. The root `pubspec.yaml` intentionally references
it so clean checkouts reproduce the notification behavior used by the app.

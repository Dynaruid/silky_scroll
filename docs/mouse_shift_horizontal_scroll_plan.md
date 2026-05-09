# Mouse Shift Horizontal Scroll Plan

## Background

PR #2 proposed adding `requireShiftForHorizontalScroll` so horizontal scroll views only scroll when Shift is held.

The feature idea is accepted, but the implementation policy should be narrower than the original PR.

## Goal

Support an opt-in behavior that prevents accidental horizontal scrolling from mouse-wheel input while preserving natural vertical page/container scrolling.

## Intended behavior

- Add or keep an option such as `requireShiftForHorizontalScroll`.
- Apply the Shift requirement only to mouse-wheel input.
- Do not block touch input.
- Do not block trackpad input.
- For a horizontal scroll view:
  - mouse wheel + Shift pressed: handle horizontal scrolling normally.
  - mouse wheel + Shift not pressed: do not scroll the horizontal view.
  - vertical mouse-wheel delta + Shift not pressed: forward the delta to an ancestor scrollable when possible.
- Preserve backward compatibility by defaulting the option to `false`.

## Non-goals

- Do not make every input type require Shift.
- Do not consume vertical mouse-wheel events when they can naturally scroll a parent.
- Do not change existing touch or trackpad behavior.

## Implementation notes

Potential areas to inspect:

- `lib/src/silky_input_handler.dart`
- `lib/src/silky_scroll_state.dart`
- `lib/src/silky_scroll_widget.dart`
- preset widgets under `lib/src/presets/`
- input handler tests under `test/`

Design considerations:

- The Shift check should be testable. Avoid hard-coding `HardwareKeyboard.instance.isShiftPressed` in a way that makes unit tests brittle.
- Parent forwarding should reuse or align with the existing ancestor forwarding behavior where possible.
- Runtime option updates should be considered if the option is stored in state.

## Test checklist

- Horizontal + mouse + requireShift + Shift pressed handles horizontal scroll.
- Horizontal + mouse + requireShift + Shift not pressed does not scroll the horizontal view.
- Horizontal + mouse vertical delta + requireShift + Shift not pressed forwards to parent when possible.
- Touch input is not blocked by the option.
- Trackpad input is not blocked by the option.
- Default behavior remains unchanged when the option is false.

## Reference

Inspired by PR #2.

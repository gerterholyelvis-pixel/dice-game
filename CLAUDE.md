# Dice Game — Project Rules

## Stack
- Godot **4.7.2**, GDScript only (no C#).
- Renderer: **Compatibility** (`gl_compatibility`). Do not use features that need Forward+/Mobile
  (SDFGI, SSR, volumetric fog, compute shaders, `GPUParticles` features beyond what GL supports).
  Prefer `CPUParticles2D` for effects.
- Tests: **GUT 9.6.x** in `addons/gut`, run through the Godot CLI.
- Audio: authored/edited in **Audacity**, exported as `.ogg` (music/ambience) or `.wav` (short SFX)
  into `assets/audio/`. Keep Audacity project files (`.aup3`) out of the repo (see `.gitignore`).

## Commands
Godot lives at (winget install):
`C:\Users\gerte\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`
(referred to as `$GODOT` below; put it on PATH or set the env var).

| Task | Command |
|---|---|
| Run game | `$GODOT --path .` |
| Import assets (needed once after clone / adding assets) | `$GODOT --headless --path . --import` |
| Run all tests | `$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gexit` |
| Run one test file | add `-gtest=res://tests/unit/test_x.gd` |
| Screenshot a scene (needs a display) | `$GODOT --path . -s tools/screenshot.gd -- res://scenes/start_screen.tscn out.png` |

Tests must pass (exit code 0) before a task is considered done. Run the import step first if the
`.godot/` folder is missing.

## Layout
```
addons/gut/           third-party, do not edit
assets/art|audio|fonts
scenes/               .tscn files, one per screen / reusable widget
scripts/              .gd files; scripts/autoload/ for singletons
shaders/              .gdshader
themes/               Theme resources
tests/unit/           GUT tests, files named test_*.gd
tools/                dev-only scripts (screenshots etc.)
```

## GDScript conventions
- Static typing everywhere: typed vars, typed params and return types, typed arrays.
- `snake_case` for files, functions, vars; `PascalCase` for classes/nodes; `UPPER_SNAKE` for constants.
- Scene file and its root script share a name (`start_screen.tscn` / `start_screen.gd`).
- Signals up, calls down. Children never reach into parents with `get_parent()`; they emit signals.
- Reference nodes with `@onready var x: Type = %UniqueName` (scene-unique names), not long paths.
- No logic in `_process` that can be a signal, tween or timer.
- Logic that can be tested must not depend on the scene tree being visible; keep game rules in
  plain `RefCounted`/`Node` scripts so GUT can instantiate them directly.
- Persistent data goes through the `GameSettings` autoload (or a future save system), never
  written ad hoc. Tests must point save paths at `user://test_*` files, never real user data.

## Art & UI
- Aesthetic: dark gothic fantasy (Diablo-like). Palette: near-black reds, ember orange `#ff7a1a`,
  bone/gold text `#e8d9b0`, steel greys.
- Base resolution 1920x1080, stretch mode `canvas_items`. Keep UI anchored so it works at 16:9 and wider.
- Dragon / background art are SVG in `assets/art/`; the glow/scale/flicker look is done in shaders.
  Replace with painted PNG/WebP art later without changing scene structure (same node names).

## Workflow
- Small commits, imperative messages. Don't commit `.godot/`, `*.aup3`, or `user://` data.
- Add or update a GUT test with every behaviour change.

## Graphics notes (Compatibility renderer)
- Glow works without HDR 2D: `WorldEnvironment` with `background_mode = Canvas` and a low `glow_hdr_threshold` (~0.65).
- SVGs import via ThorVG: no filters; use gradients/clip paths only. Imported at `svg/scale=2.0` with mipmaps; TextureRects use `texture_filter = 6`.
- Full-screen shader effects live in `shaders/` (fog, god_rays, heat_haze, vignette, dragon, title_metal). Never use `atan()` directly for radial noise (seam at the wrap); sample noise on `cos/sin` instead.
- Dark gradients band visibly at 8 bits; the vignette shader's grain is the dither. Keep it >= 0.05.

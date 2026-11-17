# Project playtest workflow

- After gameplay or presentation changes, build the Godot **Web** export and give
  the user a clickable browser playtest link in the final response.
- The user prefers a local link on this Mac. Use **http://localhost:8060/** by
  default, and keep the local server running for playtesting. Reuse a healthy
  existing server; rebuild its files and verify the updated game loads.
- Web is the default playtest deliverable. Create native macOS builds only when
  requested or needed for a specific verification task.
- Use `GODOT=/path/to/Godot ./godot/build_web.sh` to rebuild without starting a
  second server, or `./godot/serve_web.sh` to build and start one. Generated files
  belong in the ignored `godot/build/web/` directory.
- Keep working on `main`; do not create branches unless asked. Commit each new
  addition, and keep new code in focused, maintainable modules.
- Keep automated playtests in the background and muted. Prefer headless Godot
  with `--audio-driver Dummy`; do not launch native windows that steal focus.
  Run browser visual checks in a hidden/background tab using `?muted=1`.

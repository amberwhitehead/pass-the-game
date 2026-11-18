extends RefCounted
## Developer tools (the save editor) show only in developer mode: runs from the Godot
## editor, a "--dev" launch option (after "--"), or "?dev=1" in a Web build's address.
## Normal exported builds never show them.


static func enabled() -> bool:
	if OS.has_feature("editor") or "--dev" in OS.get_cmdline_user_args():
		return true
	return OS.has_feature("web") and bool(JavaScriptBridge.eval(
		"new URLSearchParams(window.location.search).get('dev') === '1'"))

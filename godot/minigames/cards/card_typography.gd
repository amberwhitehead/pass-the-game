extends RefCounted
## Text fitting shared by both screen inspection and physical card textures.

static func fit_title(copy: String, font: Font, width: float, preferred := 35, minimum := 22) -> Dictionary:
	for point in range(preferred, minimum - 1, -1):
		if font.get_string_size(copy, HORIZONTAL_ALIGNMENT_LEFT, -1, point).x <= width:
			return {"text": copy, "size": point}
	return {"text": ellipsis(copy, font, width, minimum), "size": minimum}

static func wrap_lines(copy: String, font: Font, width: float, point: int) -> PackedStringArray:
	var lines := PackedStringArray()
	for paragraph in copy.split("\n"):
		var current := ""
		for word in paragraph.split(" ", false):
			var next := word if current.is_empty() else current + " " + word
			if font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, point).x <= width:
				current = next
			else:
				if not current.is_empty():
					lines.append(current)
				current = ""
				# Long unbroken words must not escape the printed rule area.
				for character in word:
					if not current.is_empty() and font.get_string_size(current + character, HORIZONTAL_ALIGNMENT_LEFT, -1, point).x > width:
						lines.append(current)
						current = ""
					current += character
		lines.append(current)
	return lines

static func rules(copy: String, font: Font, width: float, preferred := 24, minimum := 20, maximum_lines := 3) -> Dictionary:
	for point in range(preferred, minimum - 1, -1):
		var lines := wrap_lines(copy, font, width, point)
		if lines.size() <= maximum_lines:
			return {"lines": lines, "size": point, "truncated": false}
	var lines := wrap_lines(copy, font, width, minimum)
	lines.resize(maximum_lines)
	lines[maximum_lines - 1] = ellipsis(lines[maximum_lines - 1] + "…", font, width, minimum)
	return {"lines": lines, "size": minimum, "truncated": true}

static func ellipsis(copy: String, font: Font, width: float, point: int) -> String:
	var fitted := copy
	while not fitted.is_empty() and font.get_string_size(fitted + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, point).x > width:
		fitted = fitted.left(fitted.length() - 1)
	return fitted.trim_suffix("…") + "…"

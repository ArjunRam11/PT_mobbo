class_name PdfDoc
extends RefCounted
## Minimal PDF 1.4 writer: A4 pages with text (Helvetica / Helvetica-Bold,
## the PDF standard fonts, so nothing is embedded), lines, polylines and
## rectangles. Everything is vector, so plots stay sharp when zoomed or
## printed. Coordinates are in points (1/72 in) with the origin at the
## TOP-LEFT of the page (converted to PDF's bottom-left internally).
## Text is limited to ASCII; anything else is replaced with '?'.

const PAGE_W := 595.0  # A4
const PAGE_H := 842.0

var _pages: Array[String] = []

func new_page() -> void:
	_pages.append("")

func _emit(op: String) -> void:
	if _pages.is_empty():
		new_page()
	_pages[_pages.size() - 1] += op + "\n"

static func _n(v: float) -> String:
	return "%.2f" % v

func _rgb(c: Color, stroke: bool) -> String:
	return "%s %s %s %s" % [_n(c.r), _n(c.g), _n(c.b), "RG" if stroke else "rg"]

static func _escape(s: String) -> String:
	var out := ""
	for ch in s:
		var code := ch.unicode_at(0)
		if code < 32 or code > 126:
			out += "?"
		elif ch == "\\" or ch == "(" or ch == ")":
			out += "\\" + ch
		else:
			out += ch
	return out

## Approximate Helvetica text width (average glyph ~0.52 em), for centring
## and right-aligning short labels.
static func text_width(s: String, size: float) -> float:
	return s.length() * size * 0.52

## y is the text baseline.
func text(x: float, y: float, s: String, size: float = 10.0, bold: bool = false, color: Color = Color.BLACK) -> void:
	_emit("BT %s /%s %s Tf %s %s Td (%s) Tj ET" % [
		_rgb(color, false), "F2" if bold else "F1", _n(size), _n(x), _n(PAGE_H - y), _escape(s)])

func text_right(x_right: float, y: float, s: String, size: float = 10.0, bold: bool = false, color: Color = Color.BLACK) -> void:
	text(x_right - text_width(s, size), y, s, size, bold, color)

func text_center(cx: float, y: float, s: String, size: float = 10.0, bold: bool = false, color: Color = Color.BLACK) -> void:
	text(cx - text_width(s, size) * 0.5, y, s, size, bold, color)

func line(a: Vector2, b: Vector2, color: Color = Color.BLACK, width: float = 0.5, dashed: bool = false) -> void:
	_emit("%s %s w %s %s %s m %s %s l S%s" % [
		_rgb(color, true), _n(width), "[3 2] 0 d" if dashed else "[] 0 d",
		_n(a.x), _n(PAGE_H - a.y), _n(b.x), _n(PAGE_H - b.y), ""])

func polyline(pts: PackedVector2Array, color: Color, width: float = 0.5, closed: bool = false) -> void:
	if pts.size() < 2:
		return
	var s := "%s %s w [] 0 d 1 j %s %s m" % [_rgb(color, true), _n(width), _n(pts[0].x), _n(PAGE_H - pts[0].y)]
	for i in range(1, pts.size()):
		s += " %s %s l" % [_n(pts[i].x), _n(PAGE_H - pts[i].y)]
	_emit(s + (" h S" if closed else " S"))

func rect(pos: Vector2, size: Vector2, stroke: Color = Color.BLACK, fill: Variant = null, width: float = 0.5) -> void:
	var r := "%s %s %s %s re" % [_n(pos.x), _n(PAGE_H - pos.y - size.y), _n(size.x), _n(size.y)]
	if fill != null:
		_emit("%s %s %s w [] 0 d %s B" % [_rgb(fill, false), _rgb(stroke, true), _n(width), r])
	else:
		_emit("%s %s w [] 0 d %s S" % [_rgb(stroke, true), _n(width), r])

func dot(c: Vector2, radius: float, color: Color) -> void:
	# Square-ish dot is fine at marker sizes; avoids Bezier maths.
	_emit("%s %s %s %s %s re f" % [_rgb(color, false), _n(c.x - radius), _n(PAGE_H - c.y - radius), _n(radius * 2), _n(radius * 2)])

## Writes the file. Returns true on success.
func save(path: String) -> bool:
	if _pages.is_empty():
		new_page()
	var objs: Array[String] = []
	# 1 catalog, 2 pages, 3 Helvetica, 4 Helvetica-Bold, then page/content pairs.
	var kids := []
	for i in _pages.size():
		kids.append("%d 0 R" % (5 + i * 2))
	objs.append("<< /Type /Catalog /Pages 2 0 R >>")
	objs.append("<< /Type /Pages /Kids [%s] /Count %d >>" % [" ".join(kids), _pages.size()])
	objs.append("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>")
	objs.append("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>")
	for i in _pages.size():
		objs.append("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %s %s] /Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> /Contents %d 0 R >>" % [
			_n(PAGE_W), _n(PAGE_H), 6 + i * 2])
		var content: String = _pages[i]
		objs.append("<< /Length %d >>\nstream\n%sendstream" % [content.length(), content])

	var out := "%PDF-1.4\n"
	var offsets := []
	for i in objs.size():
		offsets.append(out.length())  # ASCII only, so chars == bytes
		out += "%d 0 obj\n%s\nendobj\n" % [i + 1, objs[i]]
	var xref_at := out.length()
	out += "xref\n0 %d\n0000000000 65535 f \n" % (objs.size() + 1)
	for o in offsets:
		out += "%010d 00000 n \n" % o
	out += "trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % [objs.size() + 1, xref_at]

	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(out.to_ascii_buffer())
	f.close()
	return true

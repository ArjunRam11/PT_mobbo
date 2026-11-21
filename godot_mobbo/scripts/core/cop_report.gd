class_name CopReport
extends RefCounted
## Turns a CopAnalysis result into tables (shared by the Analysis tab and
## the exports), a 2-page PDF report and a CSV summary.

const C_LEFT := Color("1f6fd6")      # left board: blue
const C_RIGHT := Color("1a9a50")     # right board: green
const C_COMBINED := Color("e08a00")  # combined COP: mango/orange (readable on white)
const C_GRID := Color(0.85, 0.85, 0.85)
const C_MUTED := Color(0.4, 0.4, 0.4)
const MAX_PLOT_POINTS := 1500

static func _f(v: float, digits: int = 2) -> String:
	return ("%." + str(digits) + "f") % v

## Rows: [measure, combined, left board, right board].
static func cop_table(r: Dictionary) -> Array:
	var c: Dictionary = r.series.combined
	var l: Dictionary = r.series.left
	var rt: Dictionary = r.series.right
	var rows := []
	var add := func(label: String, getter: Callable) -> void:
		rows.append([label, getter.call(c), getter.call(l), getter.call(rt)])
	add.call("Samples used (n)", func(s): return str(s.n))
	add.call("Mean ML x (cm)", func(s): return _f(s.x.mean))
	add.call("Median ML x (cm)", func(s): return _f(s.x.median))
	add.call("SD ML x (cm)", func(s): return _f(s.x.sd))
	add.call("Mean AP y (cm)", func(s): return _f(s.y.mean))
	add.call("Median AP y (cm)", func(s): return _f(s.y.median))
	add.call("SD AP y (cm)", func(s): return _f(s.y.sd))
	add.call("ML range (cm)", func(s): return _f(s.range_ml))
	add.call("AP range (cm)", func(s): return _f(s.range_ap))
	add.call("Path length (cm)", func(s): return _f(s.path, 1))
	add.call("ML path length (cm)", func(s): return _f(s.path_ml, 1))
	add.call("AP path length (cm)", func(s): return _f(s.path_ap, 1))
	add.call("Mean COP velocity (cm/s)", func(s): return _f(s.vel))
	add.call("ML velocity (cm/s)", func(s): return _f(s.vel_ml))
	add.call("AP velocity (cm/s)", func(s): return _f(s.vel_ap))
	add.call("95% ellipse area (cm2)", func(s): return _f(s.ellipse.area))
	add.call("Ellipse semi-axes a/b (cm)", func(s): return "%s / %s" % [_f(s.ellipse.a), _f(s.ellipse.b)])
	add.call("Ellipse angle (deg from ML)", func(s): return _f(rad_to_deg(s.ellipse.angle), 1))
	return rows

## Rows: [measure, left mean, left median, left SD, right mean, right median, right SD].
static func force_table(r: Dictionary) -> Array:
	var rows := []
	var names := {"f1": "Sensor 1 front-left (kg)", "f2": "Sensor 2 front-right (kg)",
		"f3": "Sensor 3 back-right (kg)", "f4": "Sensor 4 back-left (kg)", "F": "Board weight (kg)"}
	for k in ["f1", "f2", "f3", "f4", "F"]:
		var a: Dictionary = r.forces.left[k]
		var b: Dictionary = r.forces.right[k]
		rows.append([names[k], _f(a.mean), _f(a.median), _f(a.sd), _f(b.mean), _f(b.median), _f(b.sd)])
	return rows

## Rows: [measure, mean, median, SD].
static func weight_table(r: Dictionary) -> Array:
	var t: Dictionary = r.forces.total
	var wl: Dictionary = r.weight_pct.left
	var wr: Dictionary = r.weight_pct.right
	return [
		["Total weight, both boards (kg)", _f(t.mean), _f(t.median), _f(t.sd)],
		["Left board share (%)", _f(wl.mean, 1), _f(wl.median, 1), _f(wl.sd, 1)],
		["Right board share (%)", _f(wr.mean, 1), _f(wr.median, 1), _f(wr.sd, 1)],
	]

static func info_rows(r: Dictionary, meta: Dictionary) -> Array:
	return [
		["Patient (hospital no.)", meta.get("patient", "")],
		["Session", meta.get("session", "")],
		["Data file", meta.get("file", "")],
		["Recording started", r.start_time],
		["Duration (s)", _f(r.duration_s, 1)],
		["Rows (left / right board)", "%d / %d" % [r.rows_left, r.rows_right]],
		["Sample rate per board (Hz)", _f(r.rate_hz, 1)],
	]

const METHOD_NOTES := [
	"Whole file analysed, regardless of trial timing. COP low-pass filtered (10 Hz, 2nd-order Butterworth, zero-phase)",
	"before all COP measures; forces and weight share are unfiltered.",
	"Board COP counted only while that board carries > 1 kg; combined COP only while both boards together carry > 1 kg.",
	"Combined COP and weight share: one sample per left-board packet, paired with the latest right-board packet.",
	"Frames: board COP relative to that board's centre; combined COP relative to the left board's centre",
	"(right board centre at +56.2 cm). x = medial-lateral (+ right), y = anterior-posterior (+ front).",
	"Path length / velocity: sum of distances between consecutive samples (gaps > 0.25 s skipped) / time spanned.",
	"95% confidence ellipse: semi-axes = sqrt(5.991 x covariance eigenvalues), area = pi a b. SD = sample SD (n-1).",
]

## -- PDF --------------------------------------------------------------------

static func write_pdf(r: Dictionary, meta: Dictionary, path: String) -> bool:
	var pdf := PdfDoc.new()
	var x0 := 40.0
	var w := PdfDoc.PAGE_W - 80.0

	# Page 1: header, info, rig plot, zoomed combined COP, weight table.
	pdf.new_page()
	pdf.text(x0, 52, "MoBBo - Sit Assessment Report", 18, true)
	pdf.text(x0, 68, "Modular Balance Board  |  whole-file centre of pressure (COP) and force analysis", 9, false, C_MUTED)
	pdf.line(Vector2(x0, 76), Vector2(x0 + w, 76), C_GRID, 0.8)
	var y := 92.0
	for row in info_rows(r, meta):
		pdf.text(x0, y, row[0], 9, true)
		pdf.text(x0 + 150, y, str(row[1]), 9)
		y += 13

	y += 8
	pdf.text(x0, y, "COP path on both boards", 11, true)
	_legend(pdf, x0 + 200, y)
	_rig_plot(pdf, r, Vector2(x0, y + 8), Vector2(w, 150))

	y += 200
	pdf.text(x0, y, "Combined COP with 95% confidence ellipse", 11, true)
	_zoom_plot(pdf, r.series.combined, Vector2(x0, y + 8), 255.0, C_COMBINED)

	var tx := x0 + 275
	pdf.text(tx, y, "Weight distribution", 11, true)
	var ty := y + 18
	pdf.text_right(tx + 175, ty, "Mean", 8, true)
	pdf.text_right(tx + 215, ty, "Median", 8, true)
	pdf.text_right(tx + 250, ty, "SD", 8, true)
	for row in weight_table(r):
		ty += 14
		pdf.text(tx, ty, row[0], 8)
		pdf.text_right(tx + 175, ty, row[1], 8)
		pdf.text_right(tx + 215, ty, row[2], 8)
		pdf.text_right(tx + 250, ty, row[3], 8)
	ty += 24
	pdf.text(tx, ty, "Combined COP - key measures", 11, true)
	var c: Dictionary = r.series.combined
	for kv in [
		["ML range (cm)", _f(c.range_ml)], ["AP range (cm)", _f(c.range_ap)],
		["Path length (cm)", _f(c.path, 1)], ["Mean velocity (cm/s)", _f(c.vel)],
		["ML velocity (cm/s)", _f(c.vel_ml)], ["AP velocity (cm/s)", _f(c.vel_ap)],
		["95% ellipse area (cm2)", _f(c.ellipse.area)],
	]:
		ty += 14
		pdf.text(tx, ty, kv[0], 8)
		pdf.text_right(tx + 250, ty, kv[1], 8)

	# Page 2: full tables + method.
	pdf.new_page()
	pdf.text(x0, 52, "COP measures", 13, true)
	y = _table(pdf, Vector2(x0, 64), ["Measure", "Combined", "Left board", "Right board"],
		cop_table(r), [190.0, 105.0, 110.0, 110.0])
	y += 22
	pdf.text(x0, y, "Forces (whole file): mean / median / SD", 13, true)
	y = _table(pdf, Vector2(x0, y + 12),
		["Measure", "L mean", "L median", "L SD", "R mean", "R median", "R SD"],
		force_table(r), [160.0, 59.0, 59.0, 59.0, 59.0, 59.0, 60.0])
	y += 22
	pdf.text(x0, y, "Weight distribution: mean / median / SD", 13, true)
	y = _table(pdf, Vector2(x0, y + 12), ["Measure", "Mean", "Median", "SD"],
		weight_table(r), [190.0, 108.0, 108.0, 109.0])
	y += 22
	pdf.text(x0, y, "Method", 11, true)
	for note in METHOD_NOTES:
		y += 12
		pdf.text(x0, y, note, 7.5, false, C_MUTED)
	pdf.text(x0, PdfDoc.PAGE_H - 30, "Generated %s by MoBBo" % Time.get_datetime_string_from_system(), 7, false, C_MUTED)
	return pdf.save(path)

static func _legend(pdf: PdfDoc, x: float, y: float) -> void:
	var items := [[C_LEFT, "Left board COP"], [C_RIGHT, "Right board COP"], [C_COMBINED, "Combined COP"]]
	for it in items:
		pdf.line(Vector2(x, y - 3), Vector2(x + 14, y - 3), it[0], 2.0)
		pdf.text(x + 18, y, it[1], 8)
		x += 100

## Returns the y below the table.
static func _table(pdf: PdfDoc, pos: Vector2, header: Array, rows: Array, widths: Array) -> float:
	var y := pos.y + 12
	var total := 0.0
	for wd in widths:
		total += wd
	pdf.rect(Vector2(pos.x, pos.y), Vector2(total, 17), C_GRID, Color(0.94, 0.94, 0.94))
	var x := pos.x
	for i in header.size():
		if i == 0:
			pdf.text(x + 4, y, header[i], 8, true)
		else:
			pdf.text_right(x + widths[i] - 4, y, header[i], 8, true)
		x += widths[i]
	for row in rows:
		y += 14
		x = pos.x
		for i in row.size():
			if i == 0:
				pdf.text(x + 4, y, str(row[i]), 8)
			else:
				pdf.text_right(x + widths[i] - 4, y, str(row[i]), 8)
			x += widths[i]
		pdf.line(Vector2(pos.x, y + 4), Vector2(pos.x + total, y + 4), C_GRID, 0.4)
	return y + 6

## World (cm, +y = front) -> page points, aspect preserved, centred in box.
static func _mapper(box_pos: Vector2, box_size: Vector2, wmin: Vector2, wmax: Vector2) -> Callable:
	var span := wmax - wmin
	var s := minf(box_size.x / span.x, box_size.y / span.y)
	var used := span * s
	var origin := box_pos + (box_size - used) * 0.5
	return func(p: Vector2) -> Vector2:
		return Vector2(origin.x + (p.x - wmin.x) * s, origin.y + (wmax.y - p.y) * s)

static func _decimate(pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() <= MAX_PLOT_POINTS:
		return pts
	var step := int(ceil(pts.size() / float(MAX_PLOT_POINTS)))
	var out := PackedVector2Array()
	for i in range(0, pts.size(), step):
		out.append(pts[i])
	return out

static func _map_all(m: Callable, pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(m.call(p))
	return out

static func _rig_plot(pdf: PdfDoc, r: Dictionary, pos: Vector2, size: Vector2) -> void:
	var L := BoardData.L_HALF
	var B := BoardData.B_HALF
	var off: Vector2 = BoardData.right_board_offset
	var m := _mapper(pos, size, Vector2(-L - 2, -B - 2), Vector2(off.x + L + 2, B + 2))
	for centre in [Vector2.ZERO, off]:
		var tl: Vector2 = m.call(centre + Vector2(-L, B))
		var br: Vector2 = m.call(centre + Vector2(L, -B))
		pdf.rect(tl, br - tl, Color(0.6, 0.6, 0.6), Color(0.97, 0.97, 0.97), 0.8)
		pdf.line(m.call(centre + Vector2(0, B)), m.call(centre + Vector2(0, -B)), C_GRID, 0.4, true)
		pdf.line(m.call(centre + Vector2(-L, 0)), m.call(centre + Vector2(L, 0)), C_GRID, 0.4, true)
	var keys := ["left", "right", "combined"]
	var cols := [C_LEFT, C_RIGHT, C_COMBINED]
	for i in 3:
		var s: Dictionary = r.series[keys[i]]
		pdf.polyline(_map_all(m, _decimate(s.plot_pts)), cols[i], 0.5)
		if s.n >= 3:
			var e: Dictionary = s.ellipse.duplicate()
			if keys[i] == "right":
				e.cx += off.x
				e.cy += off.y
			pdf.polyline(_map_all(m, CopAnalysis.ellipse_points(e)), cols[i], 1.0, true)
	pdf.text(pos.x, pos.y + size.y + 10, "Front of the boards at the top. Thin line = COP path, thick = 95% ellipse.", 7, false, C_MUTED)

static func _zoom_plot(pdf: PdfDoc, s: Dictionary, pos: Vector2, side: float, color: Color) -> void:
	pdf.rect(pos, Vector2(side, side), Color(0.6, 0.6, 0.6), null, 0.8)
	if s.n < 3:
		pdf.text_center(pos.x + side * 0.5, pos.y + side * 0.5, "Not enough loaded samples", 9, false, C_MUTED)
		return
	var e: Dictionary = s.ellipse
	var centre := Vector2(e.cx, e.cy)
	var half := maxf(maxf(e.a, s.range_ml * 0.5), maxf(s.range_ap * 0.5, 1.0)) * 1.15
	var step := _nice_step(half * 2.0 / 6.0)
	half = ceilf(half / step) * step
	var wmin := centre - Vector2(half, half)
	var wmax := centre + Vector2(half, half)
	var inner := 28.0  # room for tick labels
	var m := _mapper(pos + Vector2(inner, 4), Vector2(side - inner - 4, side - inner - 4), wmin, wmax)
	var v := ceilf(wmin.x / step) * step
	while v <= wmax.x + 0.0001:
		pdf.line(m.call(Vector2(v, wmin.y)), m.call(Vector2(v, wmax.y)), C_GRID, 0.4)
		var p: Vector2 = m.call(Vector2(v, wmin.y))
		pdf.text_center(p.x, p.y + 10, _f(v, 1 if step < 1.0 else 0), 6.5, false, C_MUTED)
		v += step
	v = ceilf(wmin.y / step) * step
	while v <= wmax.y + 0.0001:
		pdf.line(m.call(Vector2(wmin.x, v)), m.call(Vector2(wmax.x, v)), C_GRID, 0.4)
		var p: Vector2 = m.call(Vector2(wmin.x, v))
		pdf.text_right(p.x - 3, p.y + 2, _f(v, 1 if step < 1.0 else 0), 6.5, false, C_MUTED)
		v += step
	pdf.polyline(_map_all(m, _decimate(s.plot_pts)), color, 0.5)
	pdf.polyline(_map_all(m, CopAnalysis.ellipse_points(e)), Color.BLACK, 1.2, true)
	var c: Vector2 = m.call(centre)
	pdf.line(c - Vector2(4, 0), c + Vector2(4, 0), Color.BLACK, 1.0)
	pdf.line(c - Vector2(0, 4), c + Vector2(0, 4), Color.BLACK, 1.0)
	pdf.text_center(pos.x + side * 0.5 + inner * 0.5, pos.y + side + 12, "ML x (cm, left-board centre = 0)", 7, false, C_MUTED)
	pdf.text(pos.x + 2, pos.y + 10, "AP y", 7, false, C_MUTED)
	pdf.text(pos.x + 2, pos.y + 18, "(cm)", 7, false, C_MUTED)

static func _nice_step(raw: float) -> float:
	var p := pow(10.0, floorf(log(maxf(raw, 1e-6)) / log(10.0)))
	for k in [1.0, 2.0, 5.0, 10.0]:
		if raw <= k * p:
			return k * p
	return 10.0 * p

## -- CSV ----------------------------------------------------------------------

static func write_csv(r: Dictionary, meta: Dictionary, path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	for row in info_rows(r, meta):
		f.store_line("\"%s\",\"%s\"" % [row[0], str(row[1])])
	f.store_line("")
	f.store_line("measure,combined,left_board,right_board")
	for row in cop_table(r):
		f.store_line(",".join(row.map(func(v): return "\"%s\"" % v)))
	f.store_line("")
	f.store_line("measure,left_mean,left_median,left_sd,right_mean,right_median,right_sd")
	for row in force_table(r):
		f.store_line(",".join(row.map(func(v): return "\"%s\"" % v)))
	f.store_line("")
	f.store_line("measure,mean,median,sd")
	for row in weight_table(r):
		f.store_line(",".join(row.map(func(v): return "\"%s\"" % v)))
	f.close()
	return true

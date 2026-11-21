class_name CopAnalysis
extends RefCounted
## Whole-file posturography measures from a MoBBo raw data CSV (the files in
## assessment/ and Rawdata/). Uses every row in the file, whatever the trial
## timing was. Pure maths, no UI -- used by the Analysis tab and the PDF/CSV
## report.
##
## Method (also printed in the report):
## - Forces f1..f4 are read from the file. Each board's COP is recomputed
##   from them (BoardData.board_cop), so older files without gcop columns
##   give the same numbers.
## - A board's COP counts only while that board carries > LOAD_MIN_KG; the
##   combined COP only while both boards together carry > LOAD_MIN_KG.
## - Combined COP / weight %: one sample per LEFT-board packet, paired with
##   the latest right-board packet (the boards stream independently; pairing
##   on every row would zig-zag between stale values and inflate path length).
## - Frames: per-board COP is relative to that board's centre; combined COP
##   is relative to the LEFT board's centre (right board at +56.2 cm).
##   x = medial-lateral (ML, + right), y = anterior-posterior (AP, + front).
## - COP series are low-pass filtered (10 Hz, 2nd-order Butterworth,
##   zero-phase) before ALL COP measures; forces / weight % are unfiltered.
## - Path length / velocity: sum of distances between consecutive valid
##   samples, divided by the time those segments span.
## - 95% confidence ellipse: covariance eigen-decomposition, semi-axes =
##   sqrt(5.991 * eigenvalue) (chi-square, 2 dof, p = 0.95), area = pi*a*b.

const LOAD_MIN_KG := 1.0
const CHI2_95_2DOF := 5.991
const FILTER_HZ := 10.0
## A gap (unloaded stretch, dropped packets) longer than this splits the
## data: it is not counted as movement for path length / velocity.
const MAX_GAP_S := 0.25

## Returns {} with "error" on failure, else the result dictionary
## documented at the end of analyze_rows().
static func analyze_file(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"error": "cannot open %s" % path}
	var header := f.get_csv_line()
	for i in header.size():
		header[i] = header[i].strip_edges()
	var col := {}
	for name in ["side", "systime", "devtime", "f1", "f2", "f3", "f4"]:
		col[name] = header.find(name)
		if col[name] == -1:
			f.close()
			return {"error": "not a MoBBo raw data file (missing '%s' column)" % name}
	var rows := []
	while not f.eof_reached():
		var r := f.get_csv_line()
		if r.size() < header.size() - 1 or r.size() <= col.f4:
			continue
		var side := r[col.side].strip_edges()
		if side != "left" and side != "right":
			continue
		rows.append({
			"side": side,
			"systime": r[col.systime].strip_edges(),
			"t": r[col.devtime].strip_edges().to_float() / 1000.0,
			"f": [r[col.f1].strip_edges().to_float(), r[col.f2].strip_edges().to_float(),
				r[col.f3].strip_edges().to_float(), r[col.f4].strip_edges().to_float()],
		})
	f.close()
	if rows.is_empty():
		return {"error": "file has no data rows"}
	var res := analyze_rows(rows)
	res["file"] = path
	return res

static func analyze_rows(rows: Array) -> Dictionary:
	var off: Vector2 = BoardData.right_board_offset
	var cop := {"left": [], "right": [], "combined": []}      # [t, Vector2]
	var forces := {"left": [[], [], [], [], []], "right": [[], [], [], [], []]}  # f1..f4, F
	var total_w := []
	var pct_left := []
	var pct_right := []
	var last := {"left": null, "right": null}

	for row in rows:
		var side: String = row.side
		var fs: Array = row.f
		var w := BoardData.total_weight(fs)
		for i in 4:
			forces[side][i].append(fs[i])
		forces[side][4].append(w)
		if w > LOAD_MIN_KG:
			cop[side].append([row.t, BoardData.board_cop(fs)])
		last[side] = fs
		# Pair on left packets only (see header).
		if side == "left" and last.right != null:
			var lw := w
			var rw := BoardData.total_weight(last.right)
			var tw := lw + rw
			total_w.append(tw)
			if tw > LOAD_MIN_KG:
				pct_left.append(lw / tw * 100.0)
				pct_right.append(rw / tw * 100.0)
				var c = BoardData.combined_cop(last.left, last.right)
				if c != null:
					cop.combined.append([row.t, c])

	var series := {}
	for key in cop:
		cop[key] = lowpass(cop[key])
		series[key] = _cop_measures(cop[key])
	# Plot coordinates in the combined (left-board-centre) frame.
	for key in ["left", "right", "combined"]:
		var shift := off if key == "right" else Vector2.ZERO
		var pts := PackedVector2Array()
		for s in cop[key]:
			pts.append(s[1] + shift)
		series[key]["plot_pts"] = pts

	var fstats := {}
	for side in ["left", "right"]:
		var d := {}
		var names := ["f1", "f2", "f3", "f4", "F"]
		for i in 5:
			d[names[i]] = stats(forces[side][i])
		fstats[side] = d
	fstats["total"] = stats(total_w)

	var t0: float = rows[0].t
	var t1: float = rows[rows.size() - 1].t
	var n_left: int = forces.left[4].size()
	var n_right: int = forces.right[4].size()
	var dur := maxf(t1 - t0, 0.0)
	return {
		"rows": rows.size(),
		"rows_left": n_left,
		"rows_right": n_right,
		"duration_s": dur,
		"rate_hz": (n_left / dur) if dur > 0.0 else 0.0,
		"start_time": rows[0].systime,
		"series": series,          # left / right / combined -> _cop_measures()
		"forces": fstats,          # left/right -> f1..f4, F stats; total -> stats
		"weight_pct": {"left": stats(pct_left), "right": stats(pct_right)},
	}

## Zero-phase low-pass on each continuous stretch of COP samples (split at
## gaps > MAX_GAP_S): 2nd-order Butterworth at FILTER_HZ, run forward then
## backward (filtfilt). Standard posturography practice -- without it, the
## sensors' sample-to-sample noise inflates path length and velocity.
static func lowpass(samples: Array) -> Array:
	var n := samples.size()
	if n < 8:
		return samples
	var dts := []
	for i in range(1, mini(n, 400)):
		dts.append(samples[i][0] - samples[i - 1][0])
	var fs := 1.0 / maxf(stats(dts).median, 1e-4)
	if fs < FILTER_HZ * 2.5:
		return samples  # too slow to filter meaningfully
	var out := []
	var start := 0
	for i in range(1, n + 1):
		if i == n or samples[i][0] - samples[i - 1][0] > MAX_GAP_S:
			var seg := samples.slice(start, i)
			if seg.size() >= 8:
				var xs := PackedFloat64Array()
				var ys := PackedFloat64Array()
				for s in seg:
					xs.append(s[1].x)
					ys.append(s[1].y)
				xs = _filtfilt(xs, fs)
				ys = _filtfilt(ys, fs)
				for k in seg.size():
					out.append([seg[k][0], Vector2(xs[k], ys[k])])
			else:
				out.append_array(seg)
			start = i
	return out

static func _filtfilt(x: PackedFloat64Array, fs: float) -> PackedFloat64Array:
	return _biquad(_biquad(x, fs, false), fs, true)

static func _biquad(x: PackedFloat64Array, fs: float, reverse: bool) -> PackedFloat64Array:
	var k := tan(PI * FILTER_HZ / fs)
	var norm := 1.0 / (1.0 + sqrt(2.0) * k + k * k)
	var b0 := k * k * norm
	var b1 := 2.0 * b0
	var b2 := b0
	var a1 := 2.0 * (k * k - 1.0) * norm
	var a2 := (1.0 - sqrt(2.0) * k + k * k) * norm
	var n := x.size()
	var y := PackedFloat64Array()
	y.resize(n)
	var first: float = x[n - 1] if reverse else x[0]
	var x1 := first
	var x2 := first
	var y1 := first
	var y2 := first  # start at steady state: no start-up transient
	for j in n:
		var i := n - 1 - j if reverse else j
		var v := b0 * x[i] + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x[i]
		y2 = y1
		y1 = v
		y[i] = v
	return y

## samples: Array of [t (s), Vector2 cop (cm)] (already filtered).
static func _cop_measures(samples: Array) -> Dictionary:
	var n := samples.size()
	var xs := []
	var ys := []
	for s in samples:
		xs.append(s[1].x)
		ys.append(s[1].y)
	var out := {"n": n, "x": stats(xs), "y": stats(ys)}
	if n < 2:
		out.merge({"range_ml": 0.0, "range_ap": 0.0, "path": 0.0, "path_ml": 0.0, "path_ap": 0.0,
			"vel": 0.0, "vel_ml": 0.0, "vel_ap": 0.0, "time_s": 0.0,
			"ellipse": {"cx": 0.0, "cy": 0.0, "a": 0.0, "b": 0.0, "angle": 0.0, "area": 0.0}})
		return out
	var path := 0.0
	var path_ml := 0.0
	var path_ap := 0.0
	var seg_time := 0.0
	for i in range(1, n):
		var dt: float = samples[i][0] - samples[i - 1][0]
		if dt < 0.0 or dt > MAX_GAP_S:
			continue
		var d: Vector2 = samples[i][1] - samples[i - 1][1]
		path += d.length()
		path_ml += absf(d.x)
		path_ap += absf(d.y)
		seg_time += dt
	out["range_ml"] = out.x.max - out.x.min
	out["range_ap"] = out.y.max - out.y.min
	out["path"] = path
	out["path_ml"] = path_ml
	out["path_ap"] = path_ap
	out["time_s"] = seg_time
	out["vel"] = path / seg_time if seg_time > 0.0 else 0.0
	out["vel_ml"] = path_ml / seg_time if seg_time > 0.0 else 0.0
	out["vel_ap"] = path_ap / seg_time if seg_time > 0.0 else 0.0
	out["ellipse"] = ellipse95(xs, ys)
	return out

## 95% confidence ellipse of a 2-D point cloud.
## angle = major-axis direction, radians from +x (ML) toward +y (AP).
static func ellipse95(xs: Array, ys: Array) -> Dictionary:
	var n := xs.size()
	var mx: float = mean(xs)
	var my: float = mean(ys)
	var sxx := 0.0
	var syy := 0.0
	var sxy := 0.0
	for i in n:
		var dx: float = xs[i] - mx
		var dy: float = ys[i] - my
		sxx += dx * dx
		syy += dy * dy
		sxy += dx * dy
	var denom := float(max(n - 1, 1))
	sxx /= denom
	syy /= denom
	sxy /= denom
	var tr := sxx + syy
	var det := sxx * syy - sxy * sxy
	var disc := sqrt(maxf(tr * tr / 4.0 - det, 0.0))
	var l1 := maxf(tr / 2.0 + disc, 0.0)
	var l2 := maxf(tr / 2.0 - disc, 0.0)
	var a := sqrt(CHI2_95_2DOF * l1)
	var b := sqrt(CHI2_95_2DOF * l2)
	return {"cx": mx, "cy": my, "a": a, "b": b, "angle": 0.5 * atan2(2.0 * sxy, sxx - syy), "area": PI * a * b}

## Points on an ellipse dictionary, for drawing.
static func ellipse_points(e: Dictionary, segments: int = 72) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var ca := cos(e.angle)
	var sa := sin(e.angle)
	for i in segments + 1:
		var t := TAU * i / segments
		var px: float = e.a * cos(t)
		var py: float = e.b * sin(t)
		pts.append(Vector2(e.cx + px * ca - py * sa, e.cy + px * sa + py * ca))
	return pts

## mean / median / sample SD / min / max / n of an Array of floats.
static func stats(values: Array) -> Dictionary:
	var n := values.size()
	if n == 0:
		return {"n": 0, "mean": 0.0, "median": 0.0, "sd": 0.0, "min": 0.0, "max": 0.0}
	var m := mean(values)
	var ss := 0.0
	for v in values:
		ss += (v - m) * (v - m)
	var sorted := values.duplicate()
	sorted.sort()
	var med: float = sorted[n / 2] if n % 2 == 1 else (sorted[n / 2 - 1] + sorted[n / 2]) * 0.5
	return {
		"n": n, "mean": m, "median": med, "sd": sqrt(ss / (n - 1)) if n > 1 else 0.0,
		"min": sorted[0], "max": sorted[n - 1],
	}

static func mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var s := 0.0
	for v in values:
		s += v
	return s / values.size()

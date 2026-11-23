class_name Calibration
extends RefCounted
## Known-weight calibration of one board's 4 load cells.
##
## Model (same as BoardData): force_i = (adc_i - tare_i) * gain_i, and the
## board's weight is the sum of the four forces. Each captured point is a
## known weight W placed somewhere on the board, with the averaged
## reading changes d_i = adc_i - tare_i, giving one equation
##     d_1*g_1 + d_2*g_2 + d_3*g_3 + d_4*g_4 = W
## - 4+ points at DIFFERENT places (e.g. near each corner + centre):
##   least squares for all four gains (per-sensor calibration).
## - Fewer points, or points that don't separate the sensors (all at the
##   centre): one common scale on the current gains (overall calibration).
## A per-sensor result is rejected (falls back to scale) if any gain flips
## sign or moves more than MAX_CHANGE from the current one -- that means the
## points were too similar or a reading was bad, not a real sensor change.

const MAX_CHANGE := 0.5  # +-50 %

## points: Array of {"known": kg, "d": [4 floats]}; current: 4 gains in use.
## Returns {"gains": [4], "method": String, "errors": [per-point % error],
##          "max_err": float, "warning": String}
static func solve(points: Array, current: Array) -> Dictionary:
	if points.is_empty():
		return {"gains": current.duplicate(), "method": "none", "errors": [], "max_err": 0.0, "warning": "No points yet."}
	var warning := ""
	var gains: Array = []
	var method := ""
	if points.size() >= 4:
		gains = _least_squares(points)
		if gains.is_empty():
			warning = "Points don't separate the four sensors (place the weight near each corner). Used one overall factor instead."
		else:
			for i in 4:
				var ratio: float = gains[i] / current[i] if current[i] != 0.0 else -1.0
				if ratio <= 1.0 - MAX_CHANGE or ratio >= 1.0 + MAX_CHANGE:
					warning = "Sensor %d factor changed by %+.0f%% -- unrealistic, so one overall factor was used. Re-capture near each corner." % [i + 1, (ratio - 1.0) * 100.0]
					gains = []
					break
		if not gains.is_empty():
			method = "per-sensor least squares, %d points" % points.size()
	if gains.is_empty():
		var known := 0.0
		var read := 0.0
		for p in points:
			known += p.known
			read += reading(p.d, current)
		if absf(read) < 1e-6:
			return {"gains": current.duplicate(), "method": "none", "errors": [], "max_err": 0.0, "warning": "Board reads no load. Tare with the board empty, then capture with the weight on it."}
		var s := known / read
		gains = current.map(func(g): return g * s)
		method = "overall scale x%.4f, %d point%s" % [s, points.size(), "" if points.size() == 1 else "s"]
		if points.size() < 4 and warning.is_empty():
			warning = "Add 4+ points (near each corner + centre) for per-sensor factors."
	var errors := []
	var max_err := 0.0
	for p in points:
		var e: float = (reading(p.d, gains) - p.known) / p.known * 100.0
		errors.append(e)
		max_err = maxf(max_err, absf(e))
	return {"gains": gains, "method": method, "errors": errors, "max_err": max_err, "warning": warning}

## Board weight (kg) for reading changes d with gains g.
static func reading(d: Array, g: Array) -> float:
	var w := 0.0
	for i in 4:
		w += d[i] * g[i]
	return w

## Least squares via normal equations, columns scaled for conditioning.
## Returns [] if the system is (near) singular.
static func _least_squares(points: Array) -> Array:
	var scale := [0.0, 0.0, 0.0, 0.0]
	for p in points:
		for i in 4:
			scale[i] = maxf(scale[i], absf(p.d[i]))
	for i in 4:
		if scale[i] < 1.0:
			return []  # a sensor never saw load
	# A = d / scale, solve (A^T A) h = A^T W, then g = h / scale.
	var m := []
	for r in 4:
		m.append([0.0, 0.0, 0.0, 0.0, 0.0])
	for p in points:
		var a := []
		for i in 4:
			a.append(p.d[i] / scale[i])
		for r in 4:
			for c in 4:
				m[r][c] += a[r] * a[c]
			m[r][4] += a[r] * p.known
	var h := _gauss(m)
	if h.is_empty():
		return []
	var g := []
	for i in 4:
		g.append(h[i] / scale[i])
	return g

## Gaussian elimination with partial pivoting on a 4x5 augmented matrix.
static func _gauss(m: Array) -> Array:
	var n := 4
	var max_diag := 0.0
	for i in n:
		max_diag = maxf(max_diag, absf(m[i][i]))
	for col in n:
		var piv := col
		for r in range(col + 1, n):
			if absf(m[r][col]) > absf(m[piv][col]):
				piv = r
		if absf(m[piv][col]) < max_diag * 1e-9:
			return []
		var tmp = m[col]
		m[col] = m[piv]
		m[piv] = tmp
		for r in range(col + 1, n):
			var f: float = m[r][col] / m[col][col]
			for c in range(col, n + 1):
				m[r][c] -= f * m[col][c]
	var x := [0.0, 0.0, 0.0, 0.0]
	for i in range(n - 1, -1, -1):
		var s: float = m[i][n]
		for c in range(i + 1, n):
			s -= m[i][c] * x[c]
		x[i] = s / m[i][i]
	return x

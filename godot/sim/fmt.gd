class_name Fmt
extends RefCounted
## Formatage des grands nombres : 999 · 12,5K · 3,40M · 1,00B · 1,00T · puis aa, ab…

const SUFFIXES := ["", "K", "M", "B", "T"]


static func num(v: float) -> String:
	var neg := v < 0.0
	v = absf(v)
	var s: String
	if v < 999.5:
		s = str(roundi(v)) if v >= 10.0 or is_equal_approx(v, roundf(v)) else ("%.1f" % v).replace(".", ",")
	else:
		var e := floori(log(v) / log(1000.0))
		var mant := v / pow(1000.0, e)
		if mant >= 999.5:      # « 999,7K » s'arrondirait à « 1000K » : on passe à l'unité suivante
			mant /= 1000.0
			e += 1
		var suffix: String
		if e < SUFFIXES.size():
			suffix = SUFFIXES[e]
		else:
			var k := e - SUFFIXES.size()
			suffix = char(97 + floori(k / 26.0) % 26) + char(97 + k % 26)
		var digits := "%.2f" if mant < 10.0 else ("%.1f" if mant < 100.0 else "%.0f")
		var txt := digits % mant
		if txt.contains("."):
			txt = txt.rstrip("0").rstrip(".")
		s = txt.replace(".", ",") + suffix
	return ("-" if neg else "") + s


static func money(v: float) -> String:
	return num(v) + " $"


static func pct(v: float) -> String:
	return "%d %%" % roundi(v * 100.0)


static func duration(sec: float) -> String:
	var t := maxi(0, roundi(sec))      # on arrondit d'abord : 119,7 s = « 2 min 00 s », pas « 1 min 00 s »
	if t < 60:
		return "%d s" % t
	if t < 3600:
		return "%d min %02d s" % [floori(t / 60.0), t % 60]
	return "%d h %02d min" % [floori(t / 3600.0), floori((t % 3600) / 60.0)]


static func mult(v: float) -> String:
	return "×" + ("%.2f" % v).rstrip("0").rstrip(".").replace(".", ",")

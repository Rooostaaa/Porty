extends SceneTree
func _hd(p: Vector2, c: Vector2, h: Vector2, a: float, b: float) -> float:
	var l := p - c
	var u := absf(l.dot(h)) - a
	var v := absf(l.dot(Vector2(-h.y, h.x))) - b
	return Vector2(maxf(u, 0.0), maxf(v, 0.0)).length()
func _init():
	var light := Vector2(-21, -44)
	for zl in [-26.0, -24.0, -22.0, -20.0]:
		for R in [8.0, 12.0]:
			var o4 := Layout.channel_lane(4, -1)
			var o3 := Layout.channel_lane(3, -1)
			var o2 := Layout.channel_lane(2, -1)
			var t: float = (float(zl) - o4.z) / (o3.z - o4.z)
			var corner := o4.lerp(o3, t)
			var path: Array[Vector3] = [Vector3(20, 0, float(zl))]
			path.append_array(Layout._fillet(path[-1], corner, o2, float(R), 8))
			path.append(o2)
			path.append(Layout.channel_lane(1, -1))
			var pts := Layout.sample_path(path, 1.0)
			var hs := Vector2(16.92, 3.76)
			var worst := INF
			for i in range(1, pts.size()):
				var ia := mini(i + roundi(hs.x), pts.size() - 1)
				var ib := maxi(i - roundi(hs.x), 0)
				var d := Vector2(pts[ia].x - pts[ib].x, pts[ia].z - pts[ib].z)
				var c := Vector2(pts[i].x, pts[i].z)
				if c.y < -100.0 or c.y > -36.0:
					continue
				var w := clampf(float(mini(i, pts.size() - 1 - i)) / hs.x, 0.0, 1.0)
				c = c.lerp((Vector2(pts[ia].x, pts[ia].z) + Vector2(pts[ib].x, pts[ib].z)) * 0.5, w)
				worst = minf(worst, _hd(light, c, d.normalized(), hs.x, hs.y))
			print("z ", zl, " R ", R, " worst ", worst, " corner ", corner)
	quit()

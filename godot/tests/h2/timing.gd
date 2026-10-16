extends Node
## Lot H2-a — durée à l'écran « envoi vers le poste → navire à quai » (ShipView seule, 0,1 s par image, sans retenue).
##   godot --headless --path godot res://tests/h2/timing.tscn


func _ready() -> void:
	var db := DataDB.new()
	var s := PortSim.new(db, 5)
	var cases := [[0, "mini"], [0, "coaster"], [0, "feeder"], [1, "feeder"], [2, "panamax"], [3, "panamax"]]
	for c in cases:
		var tot := 0.0
		var n := 0
		for slot in [0, 1, 4]:
			var sh := Ship.new()
			sh.id = 100 + n
			sh.cls = String(c[1])
			sh.owner = String(db.owners[0].id)
			sh.evp_total = 10.0
			sh.left = PackedFloat64Array([10.0, 0.0, 0.0, 0.0, 0.0])
			sh.anchor_slot = slot
			sh.berth = int(c[0])
			sh.state = Ship.State.ANCHORED
			var v := ShipView.new()
			add_child(v)
			v.setup(sh, s)
			v.place(sh, s)
			v.dispatch(int(c[0]))
			v.gate_level = 2
			var t := 0.0
			var ph := v.phase
			var tph := 0.0
			var log := ""
			for i in 20000:
				if v.phase == ShipView.Phase.MOORED:
					break
				v.step(0.1)
				t += 0.1
				if v.phase != ph:
					log += " %s %.1fs (%.0f u)" % [ShipView.Phase.keys()[ph], t - tph, v.path_len()]
					ph = v.phase
					tph = t
			if slot == 0:
				print("   ", log, " ", ShipView.Phase.keys()[ph], " ", t - tph)
			tot += t
			n += 1
			v.queue_free()
		print("TIMING poste %d %s : %.1f s (moyenne de 3 places du mouillage)" % [int(c[0]) + 1, String(c[1]), tot / float(n)])
	get_tree().quit()

extends "res://lib.gd"
## ADR-0005 Verification Required (1)-(6). Compile probes print parse errors to the log on purpose.

const BASE := "res://fixtures/abstract_event.gd"


func _sub(project_body: String, cancel_sig: String = "func on_cancel(actor: int) -> void:\n\tpass\n") -> String:
	return "extends \"%s\"\n\nfunc project(peer: int) -> Dictionary:\n%s\n%s" % [BASE, project_body, cancel_sig]


func run() -> void:
	# (1) Abstract class: concrete members usable from a subclass; the base cannot be instantiated.
	var base: GDScript = load(BASE)
	var base_inst = base.new() if base.can_instantiate() else null
	var good := GDScript.new()
	good.source_code = _sub("\tif peer == 0:\n\t\treturn {}\n\treturn {\"p\": peer}\n")
	var good_err := good.reload()
	var desc := ""
	if good_err == OK:
		var ev = good.new()
		ev.tick = 5
		desc = ev.describe()
	var by_name := compile("extends RefCounted
func f() -> void:
	var e = FixtureEvent.new()
")
	var one_line: GDScript = load("res://fixtures/abstract_event_one_line.gd")
	var one_line_inst = one_line.new() if one_line.can_instantiate() else null
	var by_name_one := compile("extends RefCounted
func f() -> void:
	var e = FixtureEventOneLine.new()
")
	var ok1: bool = by_name != OK and good_err == OK and desc == "event 5"
	rec("0005-1", "PASS" if ok1 else "FAIL", "own-line @abstract: FixtureEvent.new() in code compiles=%s; load(path).new() at runtime returned %s (can_instantiate=%s); subclass compiles=%s, inherited field+method -> '%s'. One-line form: by name compiles=%s, load(path).new() returned %s" % [by_name == OK, base_inst, base.can_instantiate(), good_err == OK, desc, by_name_one == OK, one_line_inst])
	# (2) Override return rules (4.7).
	var missing := compile(_sub("\tif peer == 0:\n\t\treturn {}\n"))
	var unannotated_missing := compile("extends \"%s\"\n\nfunc project(peer: int):\n\tif peer == 0:\n\t\treturn {}\n\nfunc on_cancel(actor: int) -> void:\n\tpass\n" % BASE)
	var wrong_type := compile("extends \"%s\"\n\nfunc project(peer: int) -> int:\n\treturn 1\n\nfunc on_cancel(actor: int) -> void:\n\tpass\n" % BASE)
	var ok2: bool = good_err == OK and missing != OK
	rec("0005-2", "PASS" if ok2 else "FAIL", "override -> Dictionary: all branches return compiles=%s; a branch without return compiles=%s; unannotated override missing a return compiles=%s; override restating a different return type compiles=%s" % [good_err == OK, missing == OK, unannotated_missing == OK, wrong_type == OK])
	# (3) Callable to a freed Node.
	var n := Node.new()
	var c := Callable(n, &"get_name")
	var before := c.is_valid()
	n.free()
	rec("0005-3", "PASS" if before and not c.is_valid() else "FAIL", "Callable(node).is_valid(): before free=%s, after free=%s" % [before, c.is_valid()])
	# (4) Which references keep a RefCounted alive.
	var holder := []
	var obj: RefCounted = good.new()
	holder.append(Callable(obj, &"describe"))
	var wr: WeakRef = weakref(obj)
	obj = null
	var alive_via_callable: bool = wr.get_ref() != null
	holder.clear()
	var module := RefCounted.new()
	var view := RefCounted.new()
	module.set_meta(&"view", view)
	view.set_meta(&"owner", module)
	var wm: WeakRef = weakref(module)
	var registry := {&"key": view}
	module = null
	view = null
	registry.clear()
	var leaked: bool = wm.get_ref() != null
	if leaked:
		var m: RefCounted = wm.get_ref()
		(m.get_meta(&"view") as RefCounted).remove_meta(&"owner")
		m = null
	var freed_after_break: bool = wm.get_ref() == null
	rec("0005-4", "OBSERVED", "named-method Callable keeps its RefCounted alive=%s; module<->view cycle survives dropping every outside reference=%s, freed once broken=%s" % [alive_via_callable, leaked, freed_after_break])
	# (5) is_instance_of with a class_name script.
	var probe_src := "extends RefCounted\nstatic func check(o: Object) -> bool:\n\treturn is_instance_of(o, FixtureView)\n"
	var probe := GDScript.new()
	probe.source_code = probe_src
	if probe.reload() != OK:
		rec("0005-5", "NOT RUN", "FixtureView not in the global class cache (run --import first)")
	else:
		var v = load("res://fixtures/test_view.gd").new()
		var yes: bool = probe.check(v)
		var no: bool = probe.check(RefCounted.new())
		rec("0005-5", "PASS" if yes and not no else "FAIL", "is_instance_of(view, FixtureView)=%s; on a plain RefCounted=%s" % [yes, no])
	# (6) Nested typed collections.
	var nested := compile("extends RefCounted\nvar d: Dictionary[StringName, Array[Callable]] = {}\n")
	var flat := GDScript.new()
	flat.source_code = "extends RefCounted\nvar d: Dictionary[StringName, Array] = {}\nfunc add(k: StringName, c: Callable) -> void:\n\tif not d.has(k):\n\t\td[k] = []\n\td[k].append(c)\nfunc first(k: StringName) -> Callable:\n\treturn d[k][0] as Callable\n"
	var flat_err := flat.reload()
	var works := false
	if flat_err == OK:
		var bus = flat.new()
		bus.add(&"Ev", Callable(self, &"run"))
		works = bus.first(&"Ev") == Callable(self, &"run")
	rec("0005-6", "PASS" if nested != OK and works else ("OBSERVED" if nested == OK else "FAIL"), "Dictionary[StringName, Array[Callable]] compiles=%s; Dictionary[StringName, Array] with a cast on read works=%s" % [nested == OK, works])

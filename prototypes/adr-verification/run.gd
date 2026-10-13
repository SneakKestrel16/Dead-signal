extends SceneTree
## ADR verification runner.
## godot --headless --path . -s res://run.gd -- [adr filter, e.g. 0001]

const MODULES := [
	"res://checks/adr_0001.gd",
	"res://checks/adr_0002.gd",
	"res://checks/adr_0003.gd",
	"res://checks/adr_0004.gd",
	"res://checks/adr_0005.gd",
	"res://checks/adr_0006.gd",
	"res://checks/adr_0007.gd",
	"res://checks/adr_0008.gd",
]

var results: Array[String] = []


func _initialize() -> void:
	Engine.max_fps = 1000
	_main.call_deferred()


func _main() -> void:
	var args := OS.get_cmdline_user_args()
	var filter := args[0] if args.size() > 0 else ""
	print("ENGINE ", Engine.get_version_info().string)
	for path in MODULES:
		if filter != "" and not path.contains(filter):
			continue
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			rec(path.get_file(), "FAIL", "module did not load (parse error, see log)")
			continue
		var mod = script.new(self)
		await mod.run()
	print("SUMMARY ", results.size(), " results")
	quit(0)


func rec(id: String, verdict: String, observed: String) -> void:
	var line := "RESULT %s %s %s" % [id, verdict, observed]
	print(line)
	results.append(line)

extends SceneTree
## Dev tool: renders a scene for a moment and saves a PNG. Needs a display (not --headless).
## Usage: godot --path . -s tools/screenshot.gd -- res://scenes/start_screen.tscn out.png [seconds]


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: -- <scene.tscn> <out.png> [seconds] [method]")
		quit(1)
		return
	var packed: PackedScene = load(args[0])
	var inst: Node = packed.instantiate()
	root.add_child(inst)
	await process_frame
	if args.size() > 3:
		inst.call(args[3])
	var wait: float = float(args[2]) if args.size() > 2 else 2.5
	await create_timer(wait).timeout
	var img: Image = root.get_texture().get_image()
	var err: Error = img.save_png(args[1])
	print("saved %s (%s) err=%d" % [args[1], img.get_size(), err])
	quit(0 if err == OK else 1)

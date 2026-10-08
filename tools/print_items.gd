extends SceneTree
## Prints the shop items as a Markdown table (used for the README):
##   godot --headless --path . -s tools/print_items.gd

func _initialize() -> void:
	var cat: ItemCatalog = load("res://data/items/catalog.tres")
	print("| Item | Tier | Cost | Recipe | Effect |")
	print("|---|---|---|---|---|")
	for it in cat.all_items():
		var recipe := "—"
		if it.tier == 2:
			var parts: Array = []
			for c in it.components:
				parts.append("%s (%d)" % [c.display_name, c.total_cost()])
			recipe = " + ".join(parts) + " + recipe %d" % it.cost
		print("| **%s** | %s | %d | %s | %s |" % [it.display_name, "Upgrade" if it.tier == 2 else "Basic", it.total_cost(), recipe, ", ".join(it.stat_lines())])
	quit()

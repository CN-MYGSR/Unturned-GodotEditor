extends SceneTree
## 资源导入验证：逐个加载转换后的 GLB，统计网格 / 骨骼 / 动画数量。
## 用法：Godot --headless --path <项目> --script res://verify_assets.gd

const TARGETS := [
	"res://assets/polygon/POLYGON_Characters.glb",
	"res://assets/unturned/models/UT_Human.glb",
	"res://assets/unturned/models/UT_Zombie.glb",
	"res://assets/unturned/models/UT_Viewmodel.glb",
	"res://assets/unturned/animations/UT_Human_Basic_Move.glb",
	"res://assets/unturned/animations/UT_Human_Basic_Idle.glb",
	"res://assets/unturned/animations/UT_Zombie_Basic.glb",
	"res://assets/kaykit/Skeleton_Warrior.glb",
	"res://assets/kaykit/Skeleton_Rogue.glb",
	"res://assets/kaykit/Skeleton_Mage.glb",
	"res://assets/kaykit/Skeleton_Minion.glb",
]

func _init() -> void:
	var ok := 0
	var fail := 0
	print("========================================")
	print(" 资源导入验证")
	print("========================================")

	for path in TARGETS:
		var packed := load(path)
		if packed == null:
			print("[FAIL] 加载失败: ", path)
			fail += 1
			continue

		var inst: Node = packed.instantiate()
		var mesh_count := 0
		var skel_count := 0
		var bone_total := 0
		var anim_names: PackedStringArray = PackedStringArray()

		for node in inst.find_children("*", "MeshInstance3D", true, false):
			mesh_count += 1
		for node in inst.find_children("*", "Skeleton3D", true, false):
			skel_count += 1
			bone_total += (node as Skeleton3D).get_bone_count()
		for node in inst.find_children("*", "AnimationPlayer", true, false):
			for a in (node as AnimationPlayer).get_animation_list():
				anim_names.append(a)

		print("----------------------------------------")
		print("文件: ", path.get_file())
		print("  网格 MeshInstance3D : ", mesh_count)
		print("  骨骼 Skeleton3D     : ", skel_count, "（合计骨骼 ", bone_total, " 根）")
		print("  动画 AnimationPlayer: ", anim_names.size(), " 段")
		if anim_names.size() > 0:
			var preview := anim_names.slice(0, mini(8, anim_names.size()))
			print("    样例: ", ", ".join(preview))
			if anim_names.size() > 8:
				print("    … 其余 ", anim_names.size() - 8, " 段")
		ok += 1
		inst.free()

	print("========================================")
	print("成功 ", ok, " / 失败 ", fail, " / 共 ", TARGETS.size())
	print("========================================")
	quit(0 if fail == 0 else 1)

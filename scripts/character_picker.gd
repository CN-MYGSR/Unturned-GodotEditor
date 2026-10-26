extends Node3D
## POLYGON 角色选择器
## Characters.fbx 一个文件里塞了 23 个角色 + 10 个附件，全部叠在一起。
## 本脚本按名字只显示指定角色，其余隐藏——这是改模的第一步。

@export var visible_character: String = "SM_Chr_Soldier_Male_01":
	set(value):
		visible_character = value
		if is_inside_tree():
			_apply()

@export var show_attachments: bool = false

const CHAR_PREFIX := "SM_Chr_"
const ATTACH_MARKERS := ["Attach", "Attachment", "Headpiece", "Scarf", "Mask", "Neck"]

var _polygon_root: Node3D

func _ready() -> void:
	_polygon_root = get_node_or_null("PolygonCharacters")
	if _polygon_root == null:
		push_warning("找不到 PolygonCharacters 节点")
		return
	_apply()
	_report()

func _apply() -> void:
	if _polygon_root == null:
		return
	for node in _polygon_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_name := String(node.name)
		var is_attachment := _is_attachment(mesh_name)
		var keep := false
		if is_attachment:
			keep = show_attachments
		else:
			keep = mesh_name == visible_character
		(node as MeshInstance3D).visible = keep

func _is_attachment(n: String) -> bool:
	for marker in ATTACH_MARKERS:
		if n.contains(marker):
			return true
	return false

func _report() -> void:
	var total := 0
	var shown := 0
	for node in _polygon_root.find_children("*", "MeshInstance3D", true, false):
		total += 1
		if (node as MeshInstance3D).visible:
			shown += 1
	print("[PICKER] 角色网格总数 ", total, "，当前显示 ", shown, "（", visible_character, "）")

## 列出所有可选角色名，方便挑选
func list_characters() -> PackedStringArray:
	var out := PackedStringArray()
	if _polygon_root == null:
		return out
	for node in _polygon_root.find_children("*", "MeshInstance3D", true, false):
		var n := String(node.name)
		if not _is_attachment(n):
			out.append(n)
	out.sort()
	return out

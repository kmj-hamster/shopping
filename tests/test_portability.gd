extends GutTest

const SOURCE_ROOTS := ["res://scripts", "res://scenes", "res://localization"]
const ROOT_SOURCE_FILES := ["res://project.godot", "res://export_presets.cfg"]


func test_runtime_source_contains_no_machine_absolute_paths() -> void:
	var forbidden := RegEx.new()
	forbidden.compile(
		"((^|[^A-Za-z0-9_])[A-Za-z]:[\\\\/]|file://|/Users/|/home/|res://[^\\s\\\"']*\\\\)"
	)
	for path in _source_files():
		var contents := FileAccess.get_file_as_string(path)
		assert_null(forbidden.search(contents), "Machine-specific path in %s" % path)


func test_res_references_exist_with_exact_disk_case() -> void:
	var reference_pattern := RegEx.new()
	reference_pattern.compile("res://[A-Za-z0-9_./-]+")
	for source_path in _source_files():
		var contents := FileAccess.get_file_as_string(source_path)
		for result in reference_pattern.search_all(contents):
			var resource_path := result.get_string().trim_suffix(".")
			assert_true(
				_path_exists_with_exact_case(resource_path),
				"Missing or case-mismatched path %s referenced by %s" % [
					resource_path, source_path
				]
			)


func test_macos_export_preset_is_portable_and_reproducible() -> void:
	var presets := ConfigFile.new()
	assert_eq(presets.load("res://export_presets.cfg"), OK)
	assert_eq(presets.get_value("preset.0", "name"), "macOS")
	assert_eq(presets.get_value("preset.0", "platform"), "macOS")
	assert_eq(
		presets.get_value("preset.0", "export_path"),
		"builds/macos/MillenniumShoppingGuide-macOS.zip"
	)
	assert_eq(
		presets.get_value("preset.0.options", "binary_format/architecture"),
		"universal"
	)
	assert_eq(
		presets.get_value("preset.0.options", "application/bundle_identifier"),
		"com.kmjhamster.shopping"
	)
	assert_eq(presets.get_value("preset.0.options", "custom_template/debug"), "")
	assert_eq(presets.get_value("preset.0.options", "custom_template/release"), "")


func _source_files() -> Array[String]:
	var result: Array[String] = []
	for root in SOURCE_ROOTS:
		_collect_files(root, result)
	for path in ROOT_SOURCE_FILES:
		if FileAccess.file_exists(path):
			result.append(path)
	return result


func _collect_files(root: String, result: Array[String]) -> void:
	var directory := DirAccess.open(root)
	assert_not_null(directory, "Unable to inspect %s" % root)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if not entry.begins_with("."):
			var path := root.path_join(entry)
			if directory.current_is_dir():
				_collect_files(path, result)
			elif entry.get_extension() in ["gd", "tscn", "tres", "po"]:
				result.append(path)
		entry = directory.get_next()
	directory.list_dir_end()


func _path_exists_with_exact_case(resource_path: String) -> bool:
	var relative := resource_path.trim_prefix("res://").trim_suffix("/")
	if relative.is_empty():
		return true
	var current := "res://"
	for segment in relative.split("/", false):
		var entries := Array(DirAccess.get_directories_at(current))
		entries.append_array(Array(DirAccess.get_files_at(current)))
		if not entries.has(segment):
			return false
		current = current.path_join(segment)
	return true

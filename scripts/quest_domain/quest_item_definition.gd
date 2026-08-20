class_name QuestItemDefinition
extends CardItemDefinition

enum SupplyMode {
	DAILY_BASIC,
	FINITE_ONCE,
	EVENT_ONLY,
	CRAFT_ONLY,
}

@export var supply_mode := SupplyMode.DAILY_BASIC
@export var is_map_key := false
@export var is_story_item := false
@export var allows_all_shapes := false


func validation_errors() -> PackedStringArray:
	var errors := super.validation_errors()
	if property_set != null:
		if property_set.property_count() > 4:
			errors.append("Item %s cannot have more than four properties." % id)
		var shape_limit := CardPropertySet.SHAPES.size() if allows_all_shapes else 2
		if property_set.present_shapes().size() > shape_limit:
			errors.append("Item %s cannot have more than two shapes." % id)
	if supply_mode == SupplyMode.CRAFT_ONLY and not is_crafted:
		errors.append("Craft-only item %s must be marked crafted." % id)
	if is_crafted and supply_mode != SupplyMode.CRAFT_ONLY:
		errors.append("Crafted item %s must use CRAFT_ONLY supply." % id)
	if (is_map_key or is_story_item) and can_recycle:
		errors.append("Protected item %s cannot be recycled." % id)
	return errors

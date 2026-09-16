extends Node
## Selectable identities; expedition rules and grades live in expedition.json.
const CHARACTERS := {
	"wylder": {"name": "Wylder", "visual": "res://assets/nightreign/characters/wylder/selectable.tres", "description": "STR A / Claw Shot / Onslaught Stake"},
	"revenant": {"name": "Revenant", "visual": "res://assets/nightreign/characters/revenant/selectable.tres", "description": "FAI S / Summon Spirit / Immortal March"}
}
var selected_id: String = "wylder"
func select_character(id: String) -> void:
	assert(CHARACTERS.has(id))
	selected_id = id
func get_visual() -> NightreignCharacterVisual:
	return load(CHARACTERS[selected_id].visual) as NightreignCharacterVisual
func get_display_name() -> String:
	return CHARACTERS[selected_id].name

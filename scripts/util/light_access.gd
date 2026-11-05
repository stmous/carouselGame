## Πρόσβαση στην υπηρεσία «Light» (εξωτερικό φως) χωρίς να εξαρτάται ο κώδικας
## από το όνομα του autoload κατά το parsing.
##
## Αν το autoload «Light» δεν είναι καταχωρημένο (π.χ. ο editor του Godot ήταν
## ανοιχτός κατά το git pull και ξαναέγραψε το project.godot από τη μνήμη του),
## η υπηρεσία δημιουργείται εδώ, στο ίδιο σημείο (/root/Light). Έτσι το
## παιχνίδι δεν «σπάει» ποτέ εξαιτίας του φωτός.
extends RefCounted

const LightService = preload("res://scripts/autoload/light.gd")
const NODE_NAME := "Light"


static func service(tree: SceneTree) -> LightService:
	if tree == null or tree.root == null:
		return null
	var n := tree.root.get_node_or_null(NODE_NAME)
	if n == null:
		n = LightService.new()
		n.name = NODE_NAME
		tree.root.add_child(n)
	return n as LightService

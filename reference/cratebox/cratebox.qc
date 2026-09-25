$modelname "ammo/fas2/cratehit.mdl"
$scale 1.0
$body studio "box.smd"
$staticprop
$surfaceprop "wood"
$cdmaterials "models/debug"
$bbox -13.4775 -28.9425 0 19.0125 30.1125 27.0675
$cbox -13.4775 -28.9425 0 19.0125 30.1125 27.0675
$sequence "idle" "box.smd" fps 1
$collisionmodel "box.smd" {
	$mass 50
	$inertia 1
	$damping 0
	$rotdamping 0
}

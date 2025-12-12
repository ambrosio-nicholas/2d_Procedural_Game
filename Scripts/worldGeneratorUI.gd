extends CanvasLayer

# ------------ UI Elements -------------
@onready var continentSlider : HSlider = $ContinentFreqSlider
@onready var continentFreqText : Label = $ContinentFreqLabel
@onready var baseSlider : HSlider = $BaseFreqSlider
@onready var baseFreqText : Label = $BaseFreqLabel
@onready var detailSlider : HSlider = $DetailFreqSlider
@onready var detailFreqText : Label = $DetailFreqLabel
@onready var seaVsLandSlider : HSlider = $SeaVsLandSlider
@onready var seaVsLandText : Label = $SeaVsLandLabel
@onready var newWorldButton : Button = $NewWorldButton

# world generator script
@onready var worldGenerator : TileMapLayer = get_node("../TileMapLayer")

var needsToUpdate : bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Set the sliders to pre-set values
	continentSlider.value = worldGenerator.continentFreq
	continentSlider.step = 0.0001
	baseSlider.value = worldGenerator.baseFreq
	detailSlider.value = worldGenerator.detailFreq
	seaVsLandSlider.value = worldGenerator.seaToLandRatio

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Update the labels for the sliders
	continentFreqText.text = str("Continent Freq: ", continentSlider.value)
	baseFreqText.text = str("Base Freq: ", baseSlider.value)
	detailFreqText.text = str("Detail Freq: ", detailSlider.value)
	seaVsLandText.text = str("Sea to Land Ratio: ", seaVsLandSlider.value)
	
	# If the value has changed, udpate it with the new value
	if worldGenerator.continentFreq != continentSlider.value:
		worldGenerator.continentFreq = continentSlider.value
		needsToUpdate = true
	if worldGenerator.baseFreq != baseSlider.value:
		worldGenerator.baseFreq = baseSlider.value
		needsToUpdate = true
	if worldGenerator.detailFreq != detailSlider.value:
		worldGenerator.detailFreq = detailSlider.value
		needsToUpdate = true
	if worldGenerator.seaToLandRatio != seaVsLandSlider.value:
		worldGenerator.seaToLandRatio = seaVsLandSlider.value
		needsToUpdate = true
	
	# If any value changed, regenerate the world
	if needsToUpdate == true:
		worldGenerator.regenerateWorld()
		needsToUpdate = false
	
	# If the new world button is pressed, randomize the seed and regenerate
	if newWorldButton.button_pressed:
		worldGenerator.reseedWorld()
		worldGenerator.regenerateWorld()

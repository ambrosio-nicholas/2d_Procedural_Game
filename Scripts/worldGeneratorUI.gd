extends CanvasLayer

# ------------ UI Elements -------------
@onready var plateSlider : HSlider = $ContinentFreqSlider
@onready var plateFreqText : Label = $ContinentFreqLabel
@onready var baseSlider : HSlider = $BaseFreqSlider
@onready var baseFreqText : Label = $BaseFreqLabel
@onready var detailSlider : HSlider = $DetailFreqSlider
@onready var detailFreqText : Label = $DetailFreqLabel
@onready var seaVsLandSlider : HSlider = $SeaVsLandSlider
@onready var seaVsLandText : Label = $SeaVsLandLabel
@onready var newWorldButton : Button = $NewWorldButton
@onready var tileInfoLabel : Label = $TileInfoLabel
@onready var detailScaleLabel : Label = $DetailScaleLabel
@onready var detailScaleSlider : HSlider = $DetailScaleSlider

# world generator script
@onready var worldGenerator : TileMapLayer = get_node("../TileMapLayer")
@onready var mapSizeX = worldGenerator.mapSizeX
@onready var mapSizeY = worldGenerator.mapSizeY
# player
@onready var player : CharacterBody2D = get_node("../CharacterBody2D")
var playerCoords : Vector2i = Vector2i(0,0)

var needsToUpdate : bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Set the sliders to pre-set values
	plateSlider.value = worldGenerator.plateFreq
	plateSlider.step = 0.001
	baseSlider.value = worldGenerator.baseFreq
	detailSlider.value = worldGenerator.detailFreq
	seaVsLandSlider.value = worldGenerator.seaToLandRatio
	detailScaleSlider.value = worldGenerator.detailScale

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Update the labels for the sliders
	plateFreqText.text = str("Plate Freq: ", plateSlider.value)
	baseFreqText.text = str("Base Freq: ", baseSlider.value)
	detailFreqText.text = str("Detail Freq: ", detailSlider.value)
	seaVsLandText.text = str("Sea to Land Ratio: ", seaVsLandSlider.value)
	detailScaleLabel.text = str("Scale Multiplier: ", detailScaleSlider.value)
	
	# If the value has changed, udpate it with the new value
	if worldGenerator.plateFreq != plateSlider.value:
		worldGenerator.plateFreq = plateSlider.value
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
	if worldGenerator.detailScale != detailScaleSlider.value:
		worldGenerator.detailScale = detailScaleSlider.value
		needsToUpdate = true
	
	# If any value changed, regenerate the world
	if needsToUpdate == true:
		worldGenerator.generateWorld()
		needsToUpdate = false
	
	# If the new world button is pressed, randomize the seed and regenerate
	if newWorldButton.button_pressed:
		worldGenerator.reseedWorld()
		worldGenerator.generateWorld()
	
	# Display the coords and altitude of the tile the player is currently over
	playerCoords = Vector2i(roundi((player.position.x) / 32) % mapSizeX, roundi((player.position.y) / 32) % mapSizeY)
	if worldGenerator.heightMap.size() == 0:
		tileInfoLabel.text = "Tile: N/A"
	else:
		tileInfoLabel.text = str("Tile: ", playerCoords, " | Altitude: ", worldGenerator.heightMap[((playerCoords.y * mapSizeX) + playerCoords.x) % (mapSizeX * mapSizeY)], " | Avg Humidity: ", worldGenerator.moistMap[((playerCoords.y * mapSizeX) + playerCoords.x)  % (mapSizeX * mapSizeY)])

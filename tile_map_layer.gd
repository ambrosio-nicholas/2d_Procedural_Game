extends TileMapLayer

@export var mapSizeX : int = 200
@export var mapSizeY : int = 200

var heightMap : PackedFloat32Array

#-----------------Terrain Parameters-----------------
@export var numOfMountainRanges : int = 1 
@export var horizontalRangeModifier : int = 1 # Adjusts how long in the x axis mountain ranges will generate
@export var verticalRangeModifier : int = 1 # Adjusts how long in the y axis mountian ranges will generate
@export var mountainRangeLength : int = 5 # Determines how many mountains will be in a mountain range
@export var mountainHeight : float = 1 # Determines the altitude of mountain peaks. Useful when determining tiles

#-----------------Noise Layers-----------------
var baseNoise = FastNoiseLite.new()
#var detailNoise = FastNoiseLite.new()
#var temperatureNoise = FastNoiseLite.new()
#var humidityNoise = FastNoiseLite.new()

func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_R):
		generateWorld()
	pass

func generateWorld() -> void:
	# clear away any old world
	tile_map_data.clear()
	heightMap.clear()
	heightMap.resize(mapSizeX * mapSizeY)
	# randomize the noise layers
	baseNoise.seed = randi()
	
	# generate the different parts of the world before combining it all together
	generateMountains()
	
	# set the tiles to draw the world following all rules
	for y in range(mapSizeY):
		for x in range(mapSizeX):
			# for each square
			determineAndDrawTileType(x,y)

func generateMountains() -> void:
	# Generate a random point and then move in a random direction to place the next point of the mountain range. Length and number of points can be tweaked!
	for i in range(numOfMountainRanges):
		var x = (randi() % mapSizeX)
		var y = (randi() % mapSizeY)
		# Set the first point in the chain to mountain height
		heightMap[(x * mapSizeY) + y] = mountainHeight
		# Make more mountains in the mountain range
		var prevVector = Vector2.ZERO
		var dirVector = Vector2.ZERO
		for j in range(mountainRangeLength - 1):
			# Generate new points until they meet certain criteria: Must not make a U-Turn, Must not be the same spot, Must not lead off the map
			while true:
				# Choose 2 numbers for the movement x and movement y
				var dirX = ((randi() % 50) - 25) * verticalRangeModifier # The next mountian in the range can form from -25 to 24 spots away * the multiplier (horizontal and vertical were flipped for some reason (o_o)
				var dirY = ((randi() % 50) - 25) * horizontalRangeModifier
				dirVector = Vector2(dirX,dirY)
				if (dirX == 0) && (dirY == 0): # Reject 0 movement
					continue
				elif (prevVector != Vector2.ZERO) && (dirVector.dot(prevVector) < 0.6428): # Reject any U-turn action by limiting the angle from original by about 50 degrees
					continue
				elif ((x + dirX > mapSizeX) || (x + dirX < 0)) && ((y + dirY > mapSizeY) || (y + dirY < 0)): # This should prevent ranges wandering off the map (Maybe I don't mind)
					continue
				x = clamp(x + dirX, 0, mapSizeX - 1)
				y = clamp(y + dirY, 0, mapSizeY - 1)
				break # End loop
			prevVector = dirVector
			# Assign the tiles as mountains 
			heightMap[(x * mapSizeY) + y] = mountainHeight

func determineAndDrawTileType(x,y) -> void:
	if heightMap[(y * mapSizeX) + x] > .6:
		set_cell(Vector2i(x,y),0,Vector2i(11,0))
	elif heightMap[(y * mapSizeX) + x] < .3:
		set_cell(Vector2i(x,y),0,Vector2i(10,0))
	else:
		set_cell(Vector2i(x,y),0,Vector2i(0,0))

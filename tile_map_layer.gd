extends TileMapLayer

@export var mapSizeX : int = 400
@export var mapSizeY : int = 400

var heightMap : Array[float] = [] # Contains the altitude for each tile indexed in order
var mountains : Array[Vector2i] = [] # Contains the Coords for each mountain peak

#-----------------Terrain Parameters-----------------
@export var continentFreq : float = 0.0012
@export var baseFreq : float = 0.005
@export var detailFreq: float = 0.01

@export var mountainHeight : float = 1 # Determines the altitude of mountain peaks. Useful when determining tiles
@export var seaToLandRatio : float = 0.3 # Determines how much of the world should bd water

@onready var numOfMountainRanges : int = ((mapSizeX * mapSizeY) / 16000) * seaToLandRatio # Determined by seaToLandRatio and mapSize
@export var horizontalRangeModifier : int = 1 # Adjusts how long in the x axis mountain ranges will generate
@export var verticalRangeModifier : int = 1 # Adjusts how long in the y axis mountian ranges will generate
@export var mountainRangeLength : int = (mapSizeX * mapSizeY) / 40000 # Determines how many mountains will be in a mountain range (Determined by mapSize)
@export var mountainBlendRadius : int = 4 # Determines how far the mountains should take to blend into the surrounding terrain

var seaLevel : float # Determined in generateBase(), and used to determine other the levels
var shoreLevel : float
var plainsLevel : float
var forrestLevel : float
var foothillsLevel : float
var lowMountainLevel : float
var mediumMountainLevel : float
var highMountainLevel : float
var mountainPeakLevel : float # Anything above the previous heights.

#-----------------Noise Layers-----------------
var continentNoise = FastNoiseLite.new()
var baseNoise = FastNoiseLite.new()
var detailNoise = FastNoiseLite.new()
# var humidityNoise = FastNoiseLite.new()
# var temperatureNoise = FastNoiseLite.new()

func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_R):
		reseedWorld()
		regenerateWorld()
	pass

func reseedWorld() -> void:
	# randomize the noise layers
	baseNoise.seed = randi()
	detailNoise.seed = randi()
	continentNoise.seed = randi()

func regenerateWorld() -> void:
	# clear away any old world and prep for a new one
	tile_map_data.clear()
	mountains.clear()
	heightMap.clear()
	heightMap.resize(mapSizeX * mapSizeY)
	
	# generate the different parts of the world before combining it all together
	generateBase()
	#generateMountains()q
	#blendMountains(mountainBlendRadius)
	
	# set the tiles to draw the world following all rules
	for y in range(mapSizeY):
		for x in range(mapSizeX):
			# for each square
			determineAndDrawTileType(x,y)

func generateBase() -> void:
	# Continent Noise
	continentNoise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	continentNoise.fractal_type = FastNoiseLite.FRACTAL_FBM
	continentNoise.frequency = continentFreq      # VERY low = continent size
	continentNoise.fractal_octaves = 3
	continentNoise.fractal_lacunarity = 2.0
	# Base Terrain Noise (Biomes maybe?)
	baseNoise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	baseNoise.frequency = baseFreq
	baseNoise.fractal_type = FastNoiseLite.FRACTAL_FBM
	baseNoise.fractal_octaves = 4
	# Ridge/Detail Noise (mountain basins + ridges hopefully)
	detailNoise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	detailNoise.frequency = detailFreq
	detailNoise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	detailNoise.fractal_octaves = 4
	# Create altitude list
	var altitudes : Array[float] = []
	altitudes.resize(mapSizeX * mapSizeY)
	heightMap.resize(mapSizeX * mapSizeY)
	for y in range(mapSizeY):
		for x in range(mapSizeX):
			var idx := x * mapSizeY + y
			# Get values
			var c = continentNoise.get_noise_2d(x, y)   # -1 .. 1
			var b = baseNoise.get_noise_2d(x, y)
			var d = detailNoise.get_noise_2d(x, y)
			# Combine noise layers at different weights
			var alt = (c * 0.65) + (b * 0.25) + (d * 0.10)
			# Normalize to 0..1
			alt = (alt + 1.0) * 0.5
			heightMap[idx] = alt
			altitudes[idx] = alt
	# determine sea level based on ratio
	altitudes.sort()
	seaLevel = altitudes[int((mapSizeX * mapSizeY) * seaToLandRatio)]
	# figure out the rest of the altitude biomes
	shoreLevel = ((1 - seaLevel) * .01) + seaLevel
	plainsLevel = ((1 - seaLevel) * .09) + shoreLevel
	forrestLevel = ((1 - seaLevel) * .09) + plainsLevel
	foothillsLevel = ((1 - seaLevel) * .09) + forrestLevel
	lowMountainLevel = ((1 - seaLevel) * .09) + foothillsLevel
	mediumMountainLevel = ((1 - seaLevel) * .04) + lowMountainLevel
	highMountainLevel = ((1 - seaLevel) * .04) + mediumMountainLevel

func generateMountains() -> void:
	# Generate a random point and then move in a random direction to place the next point of the mountain range. Length and number of points can be tweaked!
	for i in range(numOfMountainRanges):
		var x = null
		var y = null
		var attempts = 0
		# Generate points until one forms on dry land
		while attempts < 120:
			attempts += 1
			x = (randi() % mapSizeX)
			y = (randi() % mapSizeY)
			if heightMap[(x * mapSizeY) + y] >= lowMountainLevel: # This adjusts whether or not mountains can form at an altitude
				break
		# Set the first point in the chain to mountain height
		heightMap[(x * mapSizeY) + y] = mountainHeight
		mountains.push_front(Vector2i(x,y))
		# Make more mountains in the mountain range
		var prevVector = Vector2.ZERO
		var dirVector = Vector2.ZERO
		for j in range(mountainRangeLength - 1):
			# Generate new points until they meet certain criteria: Must not make a U-Turn, Must not be the same spot, Must not lead off the map, Must stay above sea level (After certain # of tries, it will give up)
			attempts = 0
			while attempts < 20:
				attempts += 1
				# Choose 2 numbers for the movement x and movement y
				var dirX = ((randi() % 8) - 4) * verticalRangeModifier # The next mountian in the range can form from -25 to 24 spots away * the multiplier (horizontal and vertical were flipped for some reason (o_o)
				var dirY = ((randi() % 8) - 4) * horizontalRangeModifier
				dirVector = Vector2(dirX,dirY)
				if (dirX == 0) && (dirY == 0): # Reject 0 movement
					continue
				elif (prevVector != Vector2.ZERO) && (dirVector.dot(prevVector) < 0.9659): # Reject any U-turn action by limiting the angle from original by about 15 degrees
					continue
				elif ((x + dirX > mapSizeX) || (x + dirX < 0)) || ((y + dirY > mapSizeY) || (y + dirY < 0)): # This should prevent ranges wandering off the map (Maybe I don't mind)
					continue
				x = clamp(x + dirX, 0, mapSizeX - 1)
				y = clamp(y + dirY, 0, mapSizeY - 1)
				if heightMap[(x * mapSizeY) + y] <= seaLevel: # This will prevent mountians forming in the ocean
					continue
				break # End loop
			if attempts >= 20: # If we failed to find a good spot for the next mountain, stop making this range 
				break
			prevVector = dirVector.normalized()
			# Assign the tiles as mountains 
			heightMap[(x * mapSizeY) + y] = mountainHeight
			mountains.push_front(Vector2i(x,y))

func blendMountains(radius := 2):
	for m in mountains:
		var mx = m.x
		var my = m.y
		# Loop over the square around the mountain
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var nx = mx + dx
				var ny = my + dy
				# Skip out-of-bounds tiles
				if nx < 0 or nx >= mapSizeX or ny < 0 or ny >= mapSizeY:
					continue
				# Skip the mountain tile itself
				if dx == 0 and dy == 0:
					continue
				var index = nx * mapSizeY + ny
				var dist = Vector2(dx, dy).length()  # distance from mountain
				# Smooth falloff for tiles further away
				var weight = pow(max(0, 1 - ((dist - 1) / (radius - 1))), 2)  # quadratic falloff
				#var weight = max(0, 1 - ((dist - 1) / (radius - 1)))  # weight decreases with distance
				heightMap[index] = lerp(heightMap[index], mountainHeight, weight)

func determineAndDrawTileType(x,y) -> void:
	if heightMap[(y * mapSizeX) + x] >= highMountainLevel:
		# Snow / Mountain Peak
		set_cell(Vector2i(x,y),2,Vector2i(11,0))
	elif heightMap[(y * mapSizeX) + x] >= mediumMountainLevel:
		# High Mountain
		set_cell(Vector2i(x,y),2,Vector2i(10,0))
	elif heightMap[(y * mapSizeX) + x] >= lowMountainLevel:
		# Medium Mountain
		set_cell(Vector2i(x,y),2,Vector2i(9,0))
	elif heightMap[(y * mapSizeX) + x] >= foothillsLevel:
		# Low Mountain
		set_cell(Vector2i(x,y),2,Vector2i(8,0))
	elif heightMap[(y * mapSizeX) + x] >= forrestLevel:
		# Foothills
		set_cell(Vector2i(x,y),2,Vector2i(7,0))
	elif heightMap[(y * mapSizeX) + x] >= plainsLevel:
		# Forests
		set_cell(Vector2i(x,y),2,Vector2i(6,0))
	elif heightMap[(y * mapSizeX) + x] >= shoreLevel:
		# Plains
		set_cell(Vector2i(x,y),2,Vector2i(5,0))
	elif heightMap[(y * mapSizeX) + x] >= seaLevel:
		# Shoreline
		set_cell(Vector2i(x,y),2,Vector2i(3,0))
	elif heightMap[(y * mapSizeX) + x] < seaLevel:
		# Sea / Ocean
		set_cell(Vector2i(x,y),2,Vector2i(2,0))

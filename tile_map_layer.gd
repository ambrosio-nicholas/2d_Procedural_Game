extends TileMapLayer

@export var mapSizeX : int = 400
@export var mapSizeY : int = 400

var heightMap : Array[float] = [] # Contains the altitude for each tile indexed in order
var tempMap : Array[float] = [] # Contains the Average temperature for each tile
var moistMap : Array[float] = [] # Contains the Average moisture for each tile

#-----------------Terrain Parameters-----------------
@export var continentFreq : float = 0.0012
@export var baseFreq : float = 0.005
@export var detailFreq: float = 0.007
@export var tempFreq : float = 0.002

@export var detailScale : float = 2.00 # This changes the distance between samples in the noise

@export var mountainHeight : float = 1 # Determines the altitude of mountain peaks. Useful when determining tiles
@export var seaToLandRatio : float = 0.35 # Determines how much of the world should be water

var numOfRivers : int = 6
var maxLakeSize : int = 600

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
var moistureNoise = FastNoiseLite.new()
var temperatureNoise = FastNoiseLite.new()

func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_R):
		reseedWorld()
		generateWorld()
	pass

# This function will randomize the world and the points within
func reseedWorld() -> void:
	# randomize the noise layers
	baseNoise.seed = randi()
	detailNoise.seed = randi()
	continentNoise.seed = randi()
	temperatureNoise.seed = randi()
	moistureNoise.seed = randi()

func generateWorld() -> void:
	# clear away any old world and prep for a new one
	tile_map_data.clear()
	heightMap.clear()
	heightMap.resize(mapSizeX * mapSizeY)
	tempMap.clear()
	tempMap.resize(mapSizeX * mapSizeY)
	moistMap.clear()
	moistMap.resize(mapSizeX * mapSizeY)
	
	# generate the base part of the world
	generateBase()
	
	generateTemperature()
	
	generateMoisture()
	
	# set the tiles to draw the world following all rules
	for y in range(mapSizeY):
		for x in range(mapSizeX):
			# for each square
			determineAndDrawTileType(x,y)
	
	generateRivers()

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
			var c = continentNoise.get_noise_2d(x * detailScale, y * detailScale)   # -1 .. 1
			var b = baseNoise.get_noise_2d(x * detailScale, y * detailScale)
			var d = detailNoise.get_noise_2d(x * detailScale, y * detailScale)
			# Combine noise layers at different weights
			var alt = (c * 0.65) + (b * 0.25) + (d * 0.10)
			# Normalize to 0..1
			alt = (alt + 1.0) * 0.5
			heightMap[idx] = alt
			altitudes[idx] = alt
	# determine sea level based on ratio
	altitudes.sort()
	seaLevel = altitudes[int((mapSizeX * mapSizeY) * seaToLandRatio) - 1]
	# figure out the rest of the altitude biomes
	shoreLevel = ((1 - seaLevel) * .01) + seaLevel
	plainsLevel = ((1 - seaLevel) * .09) + shoreLevel
	forrestLevel = ((1 - seaLevel) * .09) + plainsLevel
	foothillsLevel = ((1 - seaLevel) * .09) + forrestLevel
	lowMountainLevel = ((1 - seaLevel) * .09) + foothillsLevel
	mediumMountainLevel = ((1 - seaLevel) * .04) + lowMountainLevel
	highMountainLevel = ((1 - seaLevel) * .04) + mediumMountainLevel

func generateRivers() -> void:
	# Figure out how many rivers should be made for the map and how big the lakes should be able to get (These equations may need adjusting
	numOfRivers = int(((mapSizeX * mapSizeY) / 12000) * (1-seaToLandRatio))
	maxLakeSize = int(600 * (1/(seaToLandRatio + .7)))
	
	# Choose a valid point on the map (Criteria: Altitude)
	var source = null
	var nextTile = null
	var lastTile = null
	var lowestHeight = INF
	var secondLowestHeight = INF
	for i in numOfRivers:
		var thisRiver = []
		for attempts in 500:
			source = Vector2i(randi() % mapSizeX, randi() % mapSizeY)
			if (heightMap[(source.y * mapSizeX) + source.x] > lowMountainLevel) && (heightMap[(source.y * mapSizeX) + source.x] < mediumMountainLevel):
				break
		lowestHeight = heightMap[(source.y * mapSizeX) + source.x]
		lastTile = source
		set_cell(source, 2, Vector2i(2,0))
		var poolSize = 0
		# Now that we have a source, flow the river downhill until it hits water
		while (lowestHeight > seaLevel) && (source.x > 0) && (source.x < mapSizeX - 1) && (source.y > 0) && (source.y < mapSizeY - 1):
			var directions = [Vector2i( 0, -1),Vector2i( 0,  1),Vector2i( 1,  0),Vector2i(-1,  0),Vector2i(-1, -1),Vector2i( 1, -1),Vector2i(-1,  1),Vector2i( 1,  1)]
			# Check the surrounding tiles for a lower altitude
			for dir in directions:
				var nx = source.x + dir.x
				var ny = source.y + dir.y
				if nx >= 0 && nx < mapSizeX && ny >= 0 && ny < mapSizeY:
					var checkTile = Vector2i(nx, ny)
					if checkTile != lastTile:
						var heightIndex = (ny * mapSizeX) + nx
						var heightValue = heightMap[heightIndex]
						if heightValue < lowestHeight:
							nextTile = checkTile
							lowestHeight = heightValue
						# Keep track of the second lowest altitude just in case
						elif heightValue > lowestHeight && heightValue < secondLowestHeight:
							secondLowestHeight = heightValue
			
			# If we've reached a dead end, add some altitude and restart from the top of the loop
			if nextTile == source:
				heightMap[(source.y * mapSizeX) + source.x] = secondLowestHeight + .01
				lowestHeight = INF
				secondLowestHeight = INF
				poolSize += 1
				continue
				
			if poolSize > maxLakeSize: # If we end up in a big lake stop river
				break
				
			# If we've hit water, stop making the river, we're done!
			if (get_cell_atlas_coords(nextTile) == Vector2i(2,0)) && (thisRiver.find(nextTile, 0) == -1):
				break
			
			# Set variables before starting the loop again
			lastTile = source
			source = nextTile
			lowestHeight = heightMap[(source.y * mapSizeX) + source.x]
			secondLowestHeight = lowestHeight
			
			# Make the river tile actually water
			set_cell(source, 2, Vector2i(2,0))
			thisRiver.push_front(source)
	addRiverBanks()

func addRiverBanks() -> void:
	for y in range(mapSizeY):
		for x in range(mapSizeX):
			var tile = Vector2i(x, y)
			# Skip if tile is water
			if get_cell_atlas_coords(tile) == Vector2i(2,0):
				continue
				
			# Check neighbors
			var neighbors = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
			var adjacentToWater = false
			for dir in neighbors:
				var nx = x + dir.x
				var ny = y + dir.y
				if nx >= 0 && nx < mapSizeX and ny >= 0 && ny < mapSizeY:
					var neighborTile = Vector2i(nx, ny)
					if get_cell_atlas_coords(neighborTile) == Vector2i(2,0):
						adjacentToWater = true
						break
			
			if adjacentToWater:
				var idx = y * mapSizeX + x
				var currentHeight = heightMap[idx]
				# Color in the correct tile
				if currentHeight > highMountainLevel:
					set_cell(Vector2i(x,y),2,Vector2i(11,1))  # Peak Mountain Shoreline
				elif currentHeight > mediumMountainLevel:
					set_cell(Vector2i(x,y),2,Vector2i(10,1))  # High Mountain Shoreline
				elif currentHeight > lowMountainLevel:
					set_cell(Vector2i(x,y),2,Vector2i(9,1))  # Medium Mountain Shoreline
				elif currentHeight > foothillsLevel:
					set_cell(Vector2i(x,y),2,Vector2i(8,1)) # Low Mountains Shoreline
				elif currentHeight > forrestLevel:
					set_cell(Vector2i(x,y),2,Vector2i(7,1)) # Foothills Shoreline
				elif currentHeight > plainsLevel:
					set_cell(Vector2i(x,y),2,Vector2i(6,1)) # Forrest Shoreline
				elif currentHeight > shoreLevel:
					set_cell(Vector2i(x,y),2,Vector2i(5,1)) #Plains Shoreline

func generateTemperature() -> void:
	temperatureNoise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	temperatureNoise.frequency = 0.005
	temperatureNoise.fractal_type = FastNoiseLite.FRACTAL_FBM
	temperatureNoise.fractal_octaves = 3

	for y in range(mapSizeY):
		for x in range(mapSizeX):
			var idx = y * mapSizeX + x
			var noiseEffect = (temperatureNoise.get_noise_2d(x,y) + 1) * .5
			var altEffect = heightMap[idx] * 0.4
			var latitudeEffect = (1 - float(y) / mapSizeY) / 6
			tempMap[idx] = noiseEffect - latitudeEffect# - altEffect

func generateMoisture() -> void:
	moistureNoise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	moistureNoise.frequency = 0.005
	#moistureNoise.fractal_type = FastNoiseLite.FRACTAL_FBM
	#moistureNoise.fractal_octaves = 3
	
	for y in range(mapSizeY):
		for x in range(mapSizeX):
			var idx = y * mapSizeX + x
			var noiseEffect = (moistureNoise.get_noise_2d(x,y) + 1) * .5
			if heightMap[idx] <= seaLevel:
				moistMap[idx] = 1
			else:
				moistMap[idx] = noiseEffect

func determineAndDrawTileType(x,y) -> void:
	# Pretty Map
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
		# Forrests
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
	
	# Temperature Map
	if heightMap[(y * mapSizeX) + x] <= seaLevel:
		set_cell(Vector2i(x + mapSizeX,y),2,Vector2i(1,0))
	elif tempMap[(y * mapSizeX) + x] >= .75:
		set_cell(Vector2i(x + mapSizeX,y),2,Vector2i(0,1))
	elif tempMap[(y * mapSizeX) + x] >= .50:
		set_cell(Vector2i(x + mapSizeX,y),2,Vector2i(1,1))
	elif tempMap[(y * mapSizeX) + x] >= .15:
		set_cell(Vector2i(x + mapSizeX,y),2,Vector2i(2,1))
	else:
		set_cell(Vector2i(x + mapSizeX,y),2,Vector2i(3,1))
	
	# Moisture Map
	if heightMap[(y * mapSizeX) + x] <= seaLevel:
		set_cell(Vector2i(x, y + mapSizeY),2,Vector2i(0,0))
	elif moistMap[(y * mapSizeX) + x] >= .75:
		set_cell(Vector2i(x, y + mapSizeY),2,Vector2i(3,2))
	elif moistMap[(y * mapSizeX) + x] >= .50:
		set_cell(Vector2i(x, y + mapSizeY),2,Vector2i(2,2))
	elif moistMap[(y * mapSizeX) + x] >= .20:
		set_cell(Vector2i(x, y + mapSizeY),2,Vector2i(1,2))
	else:
		set_cell(Vector2i(x, y + mapSizeY),2,Vector2i(0,2))
	
	# Altitude Map
	if heightMap[(y * mapSizeX) + x] >= highMountainLevel:
		set_cell(Vector2i(x + mapSizeX ,y + mapSizeY),2,Vector2i(5,3))
	elif heightMap[(y * mapSizeX) + x] >= mediumMountainLevel:
		# High Mountain
		set_cell(Vector2i(x + mapSizeX ,y + mapSizeY),2,Vector2i(4,3))
	elif heightMap[(y * mapSizeX) + x] >= foothillsLevel:
		# Medium Mountain
		set_cell(Vector2i(x + mapSizeX ,y + mapSizeY),2,Vector2i(3,3))
	elif heightMap[(y * mapSizeX) + x] >= forrestLevel:
		# Low Mountain
		set_cell(Vector2i(x + mapSizeX ,y + mapSizeY),2,Vector2i(2,3))
	elif heightMap[(y * mapSizeX) + x] >= plainsLevel:
		# Foothills
		set_cell(Vector2i(x + mapSizeX ,y + mapSizeY),2,Vector2i(1,3))
	elif heightMap[(y * mapSizeX) + x] >= shoreLevel:
		# Forrests
		set_cell(Vector2i(x + mapSizeX ,y + mapSizeY),2,Vector2i(0,3))
	elif heightMap[(y * mapSizeX) + x] < seaLevel:
		# Sea / Ocean
		set_cell(Vector2i(x + mapSizeX ,y + mapSizeY),2,Vector2i(0,0))

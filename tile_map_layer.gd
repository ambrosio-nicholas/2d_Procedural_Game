extends TileMapLayer

@export var mapSizeX : int = 400
@export var mapSizeY : int = 400

var heightMap : Array[float] = [] # Contains the altitude for each tile indexed in order
var tempMap : Array[float] = [] # Contains the Average temperature for each tile
var moistMap : Array[float] = [] # Contains the Average moisture for each tile

var riverTiles : Array[Vector2i] = [] # Contains all the river tiles we have

#-----------------Terrain Parameters-----------------
@export var continentFreq : float = 0.0012
@export var baseFreq : float = 0.005
@export var detailFreq: float = 0.007
@export var tempFreq : float = 0.002
@export var moistFreq : float = 0.005

@export var detailScale : float = 2.00 # This changes the distance between samples in the noise

@export var mountainHeight : float = 1 # Determines the altitude of mountain peaks. Useful when determining tiles
@export var seaToLandRatio : float = 0.35 # Determines how much of the world should be water

var numOfRivers : int = 6
var maxLakeSize : int = 600

# Moisture Levels
var dryLevel : float = -1.0
var semiDryLevel : float = 0.20
var semiHumidLevel : float = 0.50
var humidLevel : float = 0.75

# Temperature Levels
var coldLevel : float = -1.0
var coolLevel : float = 0.15
var warmLevel : float = 0.5
var hotLevel : float = 0.85

# Altitude Levels set in generateBase()
var seaLevel : float
var shoreLevel : float
var lowlandsLevel : float
var highlandsLevel : float
var mountainLevel : float
var peakLevel : float

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
	riverTiles.clear()
	heightMap.clear()
	heightMap.resize(mapSizeX * mapSizeY)
	tempMap.clear()
	tempMap.resize(mapSizeX * mapSizeY)
	moistMap.clear()
	moistMap.resize(mapSizeX * mapSizeY)
	
	# generate the base part of the world
	generateBase()
	
	generateRivers()
	
	generateTemperature()
	
	generateMoisture()
	
	# set the tiles to draw the world following all rules
	for y in range(mapSizeY):
		for x in range(mapSizeX):
			# for each square
			determineAndDrawTileType(x,y)
			# drawDataMaps gives seperate humidity, temp, and altitudes. Great for debugging!
			drawDataMaps(x,y)
	# Draw the rivers
	for i in range(riverTiles.size()):
		set_cell(riverTiles[i],2,Vector2i(1,0))

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
	var seaIndex = int((mapSizeX * mapSizeY) * seaToLandRatio)
	seaLevel = altitudes[seaIndex]
	
	var landAltitudes = altitudes.slice(seaIndex, (mapSizeX * mapSizeY))
	var landCount = landAltitudes.size()
	# figure out the rest of the altitude biomes
	shoreLevel = landAltitudes[int(.05 * landCount)]
	lowlandsLevel = landAltitudes[int(.50 * landCount)]
	highlandsLevel = landAltitudes[int(.80 * landCount)]
	mountainLevel = landAltitudes[int(.97 * landCount)]
	peakLevel = landAltitudes[int(.99 * landCount)]

func generateRivers() -> void:
	# Figure out how many rivers should be made for the map and how big the lakes should be able to get (These equations may need adjusting
	numOfRivers = int(((mapSizeX * mapSizeY) / 12000) * (1-seaToLandRatio))
	maxLakeSize = int(600 * (1/(seaToLandRatio + .7)))
	var source = null
	var nextTile = null
	var lastTile = null
	var lowestHeight = INF
	var secondLowestHeight = INF
	# For each river
	for i in numOfRivers:
		var thisRiver = []
		# Choose a valid point on the map (Criteria: Altitude)
		for attempts in 500:
			source = Vector2i(randi() % mapSizeX, randi() % mapSizeY)
			if (heightMap[(source.y * mapSizeX) + source.x] > mountainLevel) && (heightMap[(source.y * mapSizeX) + source.x] < peakLevel):
				break
		lowestHeight = heightMap[(source.y * mapSizeX) + source.x]
		lastTile = source
		set_cell(source, 2, Vector2i(2,0))
		var poolSize = 0
		# Now that we have a source, flow the river downhill until it hits water
		while (lowestHeight > seaLevel) && (source.x > 0) && (source.x < mapSizeX - 1) && (source.y > 0) && (source.y < mapSizeY - 1):
			var directions = [Vector2i( 0, -1),Vector2i( 0,  1),Vector2i( 1,  0),Vector2i(-1,  0),Vector2i(-1, -1),Vector2i( 1, -1),Vector2i(-1,  1),Vector2i( 1,  1)]
			nextTile = source
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
			riverTiles.push_front(source)
			thisRiver.push_front(source)
#	addRiverBanks()

#func addRiverBanks() -> void:
#	for y in range(mapSizeY):
#		for x in range(mapSizeX):
#			var tile = Vector2i(x, y)
#			# Skip if tile is water
#			if get_cell_atlas_coords(tile) == Vector2i(2,0):
#				continue
#				
#			# Check neighbors
#			var neighbors = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
#			var adjacentToWater = false
#			for dir in neighbors:
#				var nx = x + dir.x
#				var ny = y + dir.y
#				if nx >= 0 && nx < mapSizeX and ny >= 0 && ny < mapSizeY:
#					var neighborTile = Vector2i(nx, ny)
#					if get_cell_atlas_coords(neighborTile) == Vector2i(2,0):
#						adjacentToWater = true
#						break
#			
#			if adjacentToWater:
#				var idx = y * mapSizeX + x
#				var currentHeight = heightMap[idx]
#				# Color in the correct tile
#				if currentHeight > highMountainLevel:
#					set_cell(Vector2i(x,y),2,Vector2i(11,1))  # Peak Mountain Shoreline
#				elif currentHeight > mediumMountainLevel:
#					set_cell(Vector2i(x,y),2,Vector2i(10,1))  # High Mountain Shoreline
#				elif currentHeight > lowMountainLevel:
#					set_cell(Vector2i(x,y),2,Vector2i(9,1))  # Medium Mountain Shoreline
#				elif currentHeight > foothillsLevel:
#					set_cell(Vector2i(x,y),2,Vector2i(8,1)) # Low Mountains Shoreline
#				elif currentHeight > forrestLevel:
#					set_cell(Vector2i(x,y),2,Vector2i(7,1)) # Foothills Shoreline
#				elif currentHeight > plainsLevel:
#					set_cell(Vector2i(x,y),2,Vector2i(6,1)) # Forrest Shoreline
#				elif currentHeight > shoreLevel:
#					set_cell(Vector2i(x,y),2,Vector2i(5,1)) #Plains Shoreline

func generateTemperature() -> void:
	temperatureNoise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	temperatureNoise.frequency = 0.005
	temperatureNoise.fractal_type = FastNoiseLite.FRACTAL_FBM
	temperatureNoise.fractal_octaves = 3

	for y in range(mapSizeY):
		for x in range(mapSizeX):
			var idx = y * mapSizeX + x
			var noiseEffect = (temperatureNoise.get_noise_2d(x,y) + 1) * .5
			#var altEffect = heightMap[idx] * 0.4
			var latitudeEffect = (1 - float(y) / mapSizeY) / 6
			tempMap[idx] = noiseEffect - latitudeEffect# - altEffect

func generateMoisture() -> void:
	moistureNoise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	moistureNoise.frequency = moistFreq
	
	for y in range(mapSizeY):
		for x in range(mapSizeX):
			var idx = y * mapSizeX + x
			var noiseEffect = (moistureNoise.get_noise_2d(x,y) + 1) * .5
			if heightMap[idx] <= seaLevel:
				moistMap[idx] = 1
			else:
				moistMap[idx] = noiseEffect

func determineAndDrawTileType(x,y) -> void:
	# Go through each tile and determine what type it should be. Start with getting all of it's info. (Could be used to set final data for the finished map when moving on to other parts of the game)
	var i = (y * mapSizeX) + x
	var alt = heightMap[i]
	var temp = tempMap[i]
	var moisture = moistMap[i]
	
	if alt <= seaLevel:
		# Ocean
		set_cell(Vector2i(x,y),2,Vector2i(1,0))
	elif alt <= shoreLevel:
		# Shore
		set_cell(Vector2i(x,y),2,Vector2i(2,0))
		
	elif alt <= lowlandsLevel || alt <= highlandsLevel || alt <= mountainLevel:
		# Lowlands and Highlands and Low Mountains/Foothills
		if temp >= hotLevel:
			# HOT Biomes
			if moisture >= humidLevel || moisture >= semiHumidLevel:
				# Hot and Humid: rainforest # Hot and Semi-Humid: rainforest
				set_cell(Vector2i(x,y),2,Vector2i(10,2))
			elif moisture >= semiDryLevel:
				# Hot and Semi-Dry: Savanna
				set_cell(Vector2i(x,y),2,Vector2i(9,2))
			elif moisture >= dryLevel:
				# Hot and Dry: Desert
				set_cell(Vector2i(x,y),2,Vector2i(7,2))
		elif temp >= warmLevel:
			# Warm Biomes
			if moisture >= humidLevel || moisture >= semiHumidLevel:
				# Warm and Humid and Semi-Humid: forest/woodland
				set_cell(Vector2i(x,y),2,Vector2i(11,0))
			elif moisture >= semiDryLevel:
				# Warm and Semi-Dry: Grassland/Plains
				set_cell(Vector2i(x,y),2,Vector2i(10,0))
			elif moisture >= dryLevel:
				# Warm and Dry: Mesa
				set_cell(Vector2i(x,y),2,Vector2i(8,2))
		elif temp >= coolLevel:
			# Kinda Cold Biomes
			if moisture >= humidLevel:
				# Cool and Humid: Pacific NW / Autumn
				set_cell(Vector2i(x,y),2,Vector2i(11,2))
			elif moisture >= semiHumidLevel:
				# Cool and Semi-Humid: Forest/Woodland
				set_cell(Vector2i(x,y),2,Vector2i(11,0))
			elif moisture >= semiDryLevel:
				# Cool and Semi-Dry: Grassland/Plains
				set_cell(Vector2i(x,y),2,Vector2i(10,0))
			elif moisture >= dryLevel:
				# Cool and Dry: Tundra
				set_cell(Vector2i(x,y),2,Vector2i(8,0))
		elif temp >= coldLevel:
			# Chilly Biomes
			if moisture >= humidLevel || moisture >= semiHumidLevel:
				# Cold and Humid AND Cold and Semi-Humid: Boreal Forrest
				set_cell(Vector2i(x,y),2,Vector2i(9,0))
			elif moisture >= semiDryLevel:
				# Cold and Semi-Dry: Tundra
				set_cell(Vector2i(x,y),2,Vector2i(8,0))
			elif moisture >= dryLevel:
				# Cold and Dry: Polar Desert/Antarcitca
				set_cell(Vector2i(x,y),2,Vector2i(7,0))
		
	elif alt <= peakLevel:
		# Mountains
		set_cell(Vector2i(x,y),2,Vector2i(4,0))
	else:
		# Peaks
		set_cell(Vector2i(x,y),2,Vector2i(5,0))

func drawDataMaps(x,y) -> void:
	var indx = (y * mapSizeX) + x
	# Temperature Map
	if heightMap[indx] <= seaLevel:
		set_cell(Vector2i(x + mapSizeX,y),2,Vector2i(1,0))
	elif tempMap[indx] >= hotLevel:
		set_cell(Vector2i(x + mapSizeX,y),2,Vector2i(0,1))
	elif tempMap[indx] >= warmLevel:
		set_cell(Vector2i(x + mapSizeX,y),2,Vector2i(1,1))
	elif tempMap[indx] >= coolLevel:
		set_cell(Vector2i(x + mapSizeX,y),2,Vector2i(2,1))
	elif tempMap[indx] >= coldLevel:
		set_cell(Vector2i(x + mapSizeX,y),2,Vector2i(3,1))
	
	# Moisture Map
	if heightMap[indx] <= seaLevel:
		set_cell(Vector2i(x, y + mapSizeY),2,Vector2i(0,0))
	elif moistMap[indx] >= humidLevel:
		set_cell(Vector2i(x, y + mapSizeY),2,Vector2i(3,2))
	elif moistMap[indx] >= semiHumidLevel:
		set_cell(Vector2i(x, y + mapSizeY),2,Vector2i(2,2))
	elif moistMap[indx] >= semiDryLevel:
		set_cell(Vector2i(x, y + mapSizeY),2,Vector2i(1,2))
	elif moistMap[indx] >= dryLevel:
		set_cell(Vector2i(x, y + mapSizeY),2,Vector2i(0,2))
	
	# Altitude Map
	if heightMap[indx] <= seaLevel:
		# Ocean
		set_cell(Vector2i(x + mapSizeX,y + mapSizeY),2,Vector2i(0,0))
	elif heightMap[indx] <= shoreLevel:
		# Shore
		set_cell(Vector2i(x + mapSizeX,y + mapSizeY),2,Vector2i(0,3))
	elif heightMap[indx] <= lowlandsLevel:
		# Lowlands
		set_cell(Vector2i(x + mapSizeX,y + mapSizeY),2,Vector2i(1,3))
	elif heightMap[indx] <= highlandsLevel:
		# Highlands
		set_cell(Vector2i(x + mapSizeX,y + mapSizeY),2,Vector2i(2,3))
	elif heightMap[indx] <= mountainLevel:
		# Mountains
		set_cell(Vector2i(x + mapSizeX,y + mapSizeY),2,Vector2i(3,3))
	elif heightMap[indx] <= peakLevel:
		# High Mountains?
		set_cell(Vector2i(x + mapSizeX,y + mapSizeY),2,Vector2i(4,3))
	else:
		# Peaks
		set_cell(Vector2i(x + mapSizeX,y + mapSizeY),2,Vector2i(5,3))

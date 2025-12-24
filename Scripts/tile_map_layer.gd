extends TileMapLayer

class tectonicPlate:
	var dirVector : Vector2i = Vector2i(0,0)
	var pointCoords : Vector2i
	var isOceanic : bool = 0 # 0 = Continental, 1 = Oceanic
	var moisture : float = 0.3 # Average humidity level of the tectonic plate

@export var mapSizeX : int = 400
@export var mapSizeY : int = 400

var heightMap : Array[float] = [] # Contains the altitude for each tile indexed in order
var moistMap : Array[float] = [] # Contains the Average moisture for each tile
var plateIndexArray : Array[int] = [] # Contain the index of the point each tile belongs to (which continent it is on) (-1 is for fault line and -2 is for shore line)
var tectonicPlates : Array[tectonicPlate] = [] # Contains the plates for the world

var riverTiles : Array[Vector2i] = [] # Contains all the river tiles we have

#-----------------Terrain Parameters-----------------
@export var plateFreq : float = 0.008
@export var numOfPlates : int = 6

@export var baseFreq : float = 0.002
@export var detailFreq: float = 0.003
@export var moistFreq : float = 0.001

@export var detailScale : float = 2.00 # This changes the distance between samples in the noise

@export var mountainHeight : float = 1 # Determines the altitude of mountain peaks. Useful when determining tiles
@export var seaToLandRatio : float = 0.05 # Determines how much of the world should be water

var numOfRivers : int = 6
var maxLakeSize : int = 600

# Moisture Levels
var dryLevel : float = -1.0
var semiDryLevel : float = 0.20
var semiHumidLevel : float = 0.50
var humidLevel : float = 0.75

# Altitude Levels set in generateBase()
var seaLevel : float
var shoreLevel : float
var lowlandsLevel : float
var highlandsLevel : float
var mountainLevel : float
var peakLevel : float

#-----------------Noise Layers-----------------
var plateNoise = FastNoiseLite.new()
var mountainRangeNoise = FastNoiseLite.new()
var baseNoise = FastNoiseLite.new()
var detailNoise = FastNoiseLite.new()
var moistureNoise = FastNoiseLite.new()
var temperatureNoise = FastNoiseLite.new()

# Called every frame
func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_R):
		reseedWorld()
		generateWorld()

# This function will randomize the world and the points within
func reseedWorld() -> void:
	# randomize the noise layers
	baseNoise.seed = randi()
	detailNoise.seed = randi()
	plateNoise.seed = randi()
	temperatureNoise.seed = randi()
	moistureNoise.seed = randi()
	mountainRangeNoise.seed = randi()
	generateTectonicPoints()

# This function will generate the map
func generateWorld() -> void:
	# clear away any old world and prep for a new one
	tile_map_data.clear()
	riverTiles.clear()
	heightMap.clear()
	heightMap.resize(mapSizeX * mapSizeY)
	moistMap.clear()
	moistMap.resize(mapSizeX * mapSizeY)
	plateIndexArray.clear()
	plateIndexArray.resize(mapSizeX * mapSizeY)
	
	# generate the base part of the world
	generateHeightMap()
	
	#generateRivers()
	
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

# This will generate the hieghtmap for the world
func generateHeightMap() -> void:
	# Tectonic Plate Noise
	plateNoise.fractal_octaves = 4
	plateNoise.frequency = plateFreq      # Affects the borders between plates
	mountainRangeNoise.frequency = 0.08   # Affects the mountain mask
	mountainRangeNoise.noise_type = FastNoiseLite.TYPE_PERLIN
	mountainRangeNoise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	mountainRangeNoise.fractal_type = FastNoiseLite.FRACTAL_NONE
	generateTectonics()
	
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
	heightMap.resize(mapSizeX * mapSizeY)
	altitudes.resize(mapSizeX * mapSizeY)
	for y in range(mapSizeY):
		for x in range(mapSizeX):
			var idx = ( y * mapSizeX) + x
			# Get values
			var b = baseNoise.get_noise_2d(x * detailScale, y * detailScale)
			var d = detailNoise.get_noise_2d(x * detailScale, y * detailScale)
			var c = plateNoise.get_noise_2d(x * detailScale, y * detailScale) # c may get removed as it's tied to plate tectonics
			# Combine noise layers at different weights
			var alt = (c * 0.05) + (b * 0.65) + (d * 0.3) # c may get removed as it's tied to plate tectonics
			# Normalize to 0 through 10
			alt = (alt + 1.0) * 5
			# Make Oceanic Plate tiles under sea level
			if tectonicPlates[plateIndexArray[idx]].isOceanic == true: alt *= -1
			# Make fault-lines mountainous
			if plateIndexArray[idx] == -1:
				alt *= 3
			
			heightMap[idx] = alt
			altitudes[idx] = alt
	heightMap = smoothTerrain(heightMap)
	# determine sea level based on ratio (THIS IS MESSED UP RN)
	altitudes.sort()
	var seaIndex = int((mapSizeX * mapSizeY) * seaToLandRatio)
	seaLevel = 0
	
	var landAltitudes = altitudes.slice(seaIndex, (mapSizeX * mapSizeY))
	var landCount = landAltitudes.size()
	# figure out the rest of the altitude biomes
	shoreLevel = -1
	lowlandsLevel = landAltitudes[int(.50 * landCount)]
	highlandsLevel = landAltitudes[int(.80 * landCount)]
	mountainLevel = 9 #landAltitudes[int(.97 * landCount)]
	peakLevel = landAltitudes[int(.99 * landCount)]

func smoothTerrain(heightMap: Array) -> Array:
	var newMap = heightMap.duplicate()
	for x in range(mapSizeX):
		for y in range(mapSizeY):
			var sum = 0.0
			var count = 0
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					var nx = x + dx
					var ny = y + dy
					if nx < 0 or ny < 0 or nx >= mapSizeX or ny >= mapSizeY:
						continue
					sum += heightMap[ny * mapSizeX + nx]
					count += 1
			newMap[y * mapSizeX + x] = sum / count
	return newMap

func generateTectonicPoints() -> void:
	# Generate tectonic plate points for vornoi diagram
	tectonicPlates.clear()
	for i in range(numOfPlates - 1):
		# Generate a new tectonic plate and choose its coords
		tectonicPlates.push_front(tectonicPlate.new())
		var coords = Vector2i(0,0)
		# Assign a random point that isn't too close to another point
		while true:
			var distance = INF
			var nearestDist = INF
			coords = Vector2i(randi() % mapSizeX , randi() % mapSizeY)
			for j in range(i):
				distance = coords.distance_to(tectonicPlates[j].pointCoords)
				if distance < nearestDist:
					nearestDist = distance
			if nearestDist > 50:
				break
		tectonicPlates[0].pointCoords = coords
		
		# Assign a random direction Vector for the plate
		var rand = randi() % 4
		if rand == 0: tectonicPlates[0].dirVector = Vector2i(1,0)
		elif rand == 1: tectonicPlates[0].dirVector = Vector2i(-1,0)
		elif rand == 2: tectonicPlates[0].dirVector = Vector2i(0,1)
		elif rand == 3: tectonicPlates[0].dirVector = Vector2i(0,-1)
		
		# Assign a moisture level to the plate
		rand = randi() % 6 # 16% chance of dry, 32% chance of semi-dry, 32% chance of semi-humid, 16% chance of humid
		if rand == 0: tectonicPlates[0].moisture = -1
		elif rand == 1 || rand == 2: tectonicPlates[0].moisture = 0.21
		elif rand == 3 || rand == 4: tectonicPlates[0].moisture = 0.51
		elif rand == 5: tectonicPlates[0].moisture = 0.75
		
		# Make the plate continental
		tectonicPlates[0].isOceanic = 0
	
	# Generate one tile that is garunteed to be oceanic along one of the edges
	tectonicPlates.push_front(tectonicPlate.new())
	tectonicPlates[0].isOceanic = 1
	tectonicPlates[0].moisture = 1
	var edge = randi() % 4
	if edge == 0: tectonicPlates[0].pointCoords = Vector2i(randi() % (mapSizeX / 5), randi() % mapSizeY)
	elif edge == 1: tectonicPlates[0].pointCoords = Vector2i(randi() % (mapSizeX / 5) + (mapSizeX * 0.8), randi() % mapSizeY)
	elif edge == 2: tectonicPlates[0].pointCoords = Vector2i(randi() % mapSizeX, randi() % (mapSizeY / 5))
	elif edge == 3: tectonicPlates[0].pointCoords = Vector2i(randi() % mapSizeX, randi() % (mapSizeY / 5) + (mapSizeY * 0.8))

func generateTectonics() -> void:
	# This function will create "tectonic plates" using a variation of a vornoi diagram. The points are generated in reseedWorld()
	
	# Check for every tile on the map and see whichever point is closest, assign the closest point as the plateIndexArray
	for x in range(mapSizeX):
		for y in range(mapSizeY):
			var closestIndex = -1
			var secondClosestIndex = -1
			var closestDistance = INF
			var secondClosestDistance = INF
			
			# Warp the point using noise
			var warpedX = x + plateNoise.get_noise_2d( x , y ) * 40
			var warpedY = y + plateNoise.get_noise_2d( x + 1000 , y + 1000 ) * 40
			
			# Go through each tectonic plate point and find which is the closest and which is the second closest (find their indexes)
			for i in range(numOfPlates):
				var d = Vector2i(warpedX,warpedY).distance_squared_to(tectonicPlates[i].pointCoords)
				if d < closestDistance:
					secondClosestDistance = closestDistance
					secondClosestIndex = closestIndex
					closestIndex = i
					closestDistance = d
				elif d < secondClosestDistance:
					secondClosestDistance = d
					secondClosestIndex = i
			
			# Assign the final plateIndexArray for that point
			var edgeWidth = 500
			if (abs(secondClosestDistance - closestDistance) < edgeWidth):
				# If it's an edge/fault line, assign it a value of -1
				plateIndexArray[(y * mapSizeX) + x] = -1
			else:
				# These are all other tiles that aren't faultlines. They should just belong to their own tectonic plate
				plateIndexArray[(y * mapSizeX) + x] = closestIndex

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

func generateMoisture() -> void:
	moistureNoise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	moistureNoise.frequency = moistFreq
	
	for y in range(mapSizeY):
		for x in range(mapSizeX):
			var idx = y * mapSizeX + x
			var noiseEffect = (moistureNoise.get_noise_2d(x,y) + 1) * .1
			if heightMap[idx] <= seaLevel:
				moistMap[idx] = 1
			elif plateIndexArray[idx] == -2: # Shoreline
				moistMap[idx] = 0 
			else:
				moistMap[idx] = tectonicPlates[plateIndexArray[idx]].moisture + noiseEffect

func determineAndDrawTileType(x,y) -> void:
	# Go through each tile and determine what type it should be. Start with getting all of it's info. (Could be used to set final data for the finished map when moving on to other parts of the game)
	var i = (y * mapSizeX) + x
	var alt = heightMap[i]
	var moisture = moistMap[i]
	
	if alt <= seaLevel:
		# Ocean
		set_cell(Vector2i(x,y),2,Vector2i(1,0))
	elif alt <= shoreLevel:
		# Shore
		set_cell(Vector2i(x,y),2,Vector2i(2,0))
		
	elif alt <= lowlandsLevel: 
		# Lowlands
		if moisture <= semiDryLevel:
			set_cell(Vector2i(x,y),2,Vector2i(10,2))
		elif moisture <= semiHumidLevel:
			set_cell(Vector2i(x,y),2,Vector2i(9,2))
		elif moisture <= humidLevel:
			set_cell(Vector2i(x,y),2,Vector2i(8,2))
		else:
			set_cell(Vector2i(x,y),2,Vector2i(7,2))
	elif alt <= highlandsLevel:
		# Highlands
		if moisture <= semiDryLevel:
			set_cell(Vector2i(x,y),2,Vector2i(10,1))
		elif moisture <= semiHumidLevel:
			set_cell(Vector2i(x,y),2,Vector2i(9,1))
		elif moisture <= humidLevel:
			set_cell(Vector2i(x,y),2,Vector2i(8,1))
		else:
			set_cell(Vector2i(x,y),2,Vector2i(7,1))
		pass
	elif alt <= mountainLevel:
		# Foothills
		if moisture <= semiDryLevel:
			set_cell(Vector2i(x,y),2,Vector2i(10,0))
		elif moisture <= semiHumidLevel:
			set_cell(Vector2i(x,y),2,Vector2i(9,0))
		elif moisture <= humidLevel:
			set_cell(Vector2i(x,y),2,Vector2i(8,0))
		else:
			set_cell(Vector2i(x,y),2,Vector2i(7,0))
	elif alt <= peakLevel:
		# Mountains
		set_cell(Vector2i(x,y),2,Vector2i(4,0))
	else:
		# Peaks
		set_cell(Vector2i(x,y),2,Vector2i(5,0))

func drawDataMaps(x,y) -> void:
	var indx = (y * mapSizeX) + x
	# Moisture Map
	if heightMap[indx] <= seaLevel:
		set_cell(Vector2i(x, y + mapSizeY),2,Vector2i(0,0))
	elif moistMap[indx] >= humidLevel:
		set_cell(Vector2i(x, y + mapSizeY),2,Vector2i(3,4))
	elif moistMap[indx] >= semiHumidLevel:
		set_cell(Vector2i(x, y + mapSizeY),2,Vector2i(2,4))
	elif moistMap[indx] >= semiDryLevel:
		set_cell(Vector2i(x, y + mapSizeY),2,Vector2i(1,4))
	elif moistMap[indx] >= dryLevel:
		set_cell(Vector2i(x, y + mapSizeY),2,Vector2i(0,4))
	
	# Altitude Map
	if heightMap[indx] <= seaLevel:
		# Ocean
		set_cell(Vector2i(x + mapSizeX, y),2,Vector2i(0,0))
	elif heightMap[indx] <= shoreLevel:
		# Shore
		set_cell(Vector2i(x + mapSizeX, y),2,Vector2i(0,5))
	elif heightMap[indx] <= lowlandsLevel:
		# Lowlands
		set_cell(Vector2i(x + mapSizeX, y),2,Vector2i(1,5))
	elif heightMap[indx] <= highlandsLevel:
		# Highlands
		set_cell(Vector2i(x + mapSizeX, y),2,Vector2i(2,5))
	elif heightMap[indx] <= mountainLevel:
		# Mountains
		set_cell(Vector2i(x + mapSizeX, y),2,Vector2i(3,5))
	elif heightMap[indx] <= peakLevel:
		# High Mountains?
		set_cell(Vector2i(x + mapSizeX, y),2,Vector2i(4,5))
	else:
		# Peaks
		set_cell(Vector2i(x + mapSizeX, y),2,Vector2i(5,5))
	
	# "Tectonic Plate" Map
	if plateIndexArray[indx] == -1:
		set_cell(Vector2i(x + mapSizeX, y + mapSizeY), 2, Vector2i(0,5))
	elif plateIndexArray[indx] == -2:
		set_cell(Vector2i(x + mapSizeX, y + mapSizeY), 2, Vector2i(5,5))
	elif plateIndexArray[indx] == 0:
		set_cell(Vector2i(x + mapSizeX, y + mapSizeY), 2, Vector2i(1,0))
	else:
		set_cell(Vector2i(x + mapSizeX, y + mapSizeY), 2, Vector2i((plateIndexArray[indx] % 4) + 1,5))
	drawDirectionArrows()
	
# This draws some direction arrows for the tectonic plate vectors
func drawDirectionArrows() -> void:
	for i in range(tectonicPlates.size()):
		var x = tectonicPlates[i].pointCoords.x
		var y = tectonicPlates[i].pointCoords.y
		if tectonicPlates[i].dirVector == Vector2i (1,0): # Right
			set_cell(Vector2i(x + mapSizeX, y + mapSizeY), 2, Vector2i(5,5))
			set_cell(Vector2i(x - 1 + mapSizeX, y + 1 + mapSizeY), 2, Vector2i(5,5))
			set_cell(Vector2i(x - 1 + mapSizeX, y - 1 + mapSizeY), 2, Vector2i(5,5))
		elif tectonicPlates[i].dirVector == Vector2i (-1,0): # Left
			set_cell(Vector2i(x + mapSizeX, y + mapSizeY), 2, Vector2i(5,5))
			set_cell(Vector2i(x + 1 + mapSizeX, y + 1 + mapSizeY), 2, Vector2i(5,5))
			set_cell(Vector2i(x + 1 + mapSizeX, y - 1 + mapSizeY), 2, Vector2i(5,5))
		elif tectonicPlates[i].dirVector == Vector2i (0,1): # Up
			set_cell(Vector2i(x + mapSizeX, y + mapSizeY), 2, Vector2i(5,5))
			set_cell(Vector2i(x + 1 + mapSizeX, y - 1 + mapSizeY), 2, Vector2i(5,5))
			set_cell(Vector2i(x - 1 + mapSizeX, y - 1 + mapSizeY), 2, Vector2i(5,5))
		elif tectonicPlates[i].dirVector == Vector2i (0,-1): # Down
			set_cell(Vector2i(x + mapSizeX, y + mapSizeY), 2, Vector2i(5,5))
			set_cell(Vector2i(x + 1 + mapSizeX, y + 1 + mapSizeY), 2, Vector2i(5,5))
			set_cell(Vector2i(x - 1 + mapSizeX, y + 1 + mapSizeY), 2, Vector2i(5,5))

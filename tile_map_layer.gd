extends TileMapLayer

@export var mapSizeX : int = 400
@export var mapSizeY : int = 400

var heightMap : PackedFloat32Array
var mountains = []

#-----------------Terrain Parameters-----------------
@export var baseFreq : float = 0.005
@export var detailFreq: float = 0.01

@onready var numOfMountainRanges : int = round((mapSizeX * mapSizeY) / 16000) 
@export var horizontalRangeModifier : int = 1 # Adjusts how long in the x axis mountain ranges will generate
@export var verticalRangeModifier : int = 1 # Adjusts how long in the y axis mountian ranges will generate
@export var mountainRangeLength : int = 5 # Determines how many mountains will be in a mountain range
@export var mountainBlendRadius : int = 4

@export var mountainHeight : float = 1 # Determines the altitude of mountain peaks. Useful when determining tiles
@export var snowHeight : float = 0.95 #At what height should snow be falling 
@export var seaLevel : float = 0.1 # Determines the altitude of sea level.
@export var seaToLandRatio : float = 0.3 # Determines how much of the world should bd water

#-----------------Noise Layers-----------------
var baseNoise = FastNoiseLite.new()
var detailNoise = FastNoiseLite.new()
#var temperatureNoise = FastNoiseLite.new()
#var humidityNoise = FastNoiseLite.new()

func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_R):
		generateWorld()
	pass

func generateWorld() -> void:
	# clear away any old world
	tile_map_data.clear()
	mountains.clear()
	heightMap.resize(mapSizeX * mapSizeY)
	# randomize the noise layers
	baseNoise.seed = randi()
	detailNoise.seed = randi()
	
	# generate the different parts of the world before combining it all together
	generateBase()
	generateMountains()
	blendMountains(mountainBlendRadius)
	
	# set the tiles to draw the world following all rules
	for y in range(mapSizeY):
		for x in range(mapSizeX):
			# for each square
			determineAndDrawTileType(x,y)

func generateBase() -> void:
	baseNoise.frequency = baseFreq
	detailNoise.frequency = detailFreq
	var numOfLandTiles = 0
	var numOfSeaTiles = 0
	for y in range(mapSizeY):
		for x in range(mapSizeX):
			# Combine the noise for each level
			var alt = (baseNoise.get_noise_2d(x,y) * 0.6) + (detailNoise.get_noise_2d(x,y) * 0.4) # The multipliers determine how much influence each layer has. Should add to 1
			# Normalize the height between 0 and 1
			alt = (alt + 1) * 0.5
			if alt <= seaLevel:
				numOfSeaTiles += 1
				alt = 0
			else: numOfLandTiles += 1
			heightMap[(x * mapSizeY) + y] = alt
	# If this isn't a good map (sea to land ratio) , we need to regenerate it
	var currentRatio = (1.0 *numOfSeaTiles) / (numOfLandTiles + numOfSeaTiles)

	print("Sea tiles: ")
	print(numOfSeaTiles)
	print("Land tiles: ")
	print(numOfLandTiles)
	print("sTlR: ")
	print(currentRatio)
	
	# IF YOU WANT TO GET 30% or less Ratio every TIME, MAKE SEA LEVEL AND OTHER LEVELS PROCEDURAL BASED ON ALTITUDES OF EACH NOISE

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
			if heightMap[(x * mapSizeY) + y] > .7: # This adjusts whether or not mountains can form at an altitude
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
				#if heightMap[(x * mapSizeY) + y] <= seaLevel: # This will prevent mountians forming in the ocean
				#	continue
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
	if heightMap[(y * mapSizeX) + x] >= snowHeight:
		set_cell(Vector2i(x,y),2,Vector2i(11,0)) # Set it as snowy peak
	elif heightMap[(y * mapSizeX) + x] >= 0.9:
		set_cell(Vector2i(x,y),2,Vector2i(10,0)) # Set it as a mountain
	elif heightMap[(y * mapSizeX) + x] >= 0.8:
		set_cell(Vector2i(x,y),2,Vector2i(9,0)) # Set it as a mountain
	elif heightMap[(y * mapSizeX) + x] >= 0.75:
		set_cell(Vector2i(x,y),2,Vector2i(9,0)) # Set it as a mountain
	elif heightMap[(y * mapSizeX) + x] >= 0.7:
		set_cell(Vector2i(x,y),2,Vector2i(7,0)) # Set it as a mountain
	elif heightMap[(y * mapSizeX) + x] >= .6:
		set_cell(Vector2i(x,y),2,Vector2i(6,0)) # Set it as a dark grass
	elif heightMap[(y * mapSizeX) + x] >= .5:
		set_cell(Vector2i(x,y),2,Vector2i(5,0)) # set it as light grass
	elif heightMap[(y * mapSizeX) + x] > seaLevel:
		set_cell(Vector2i(x,y),2,Vector2i(3,0)) # set it as sand
	elif heightMap[(y * mapSizeX) + x] <= seaLevel:
		set_cell(Vector2i(x,y),2,Vector2i(2,0)) # set it as water

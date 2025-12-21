extends TileMapLayer

@export var gridSizeX : int = 400
@export var gridSizeY : int = 400

@export var numOfPoints : int = 5
var points : Array[Vector2i] = [] # The point that is the "centerish" of a continental plate
var pointsDir : Array[Vector2i] = [] # The direction that a given point is "drifitng in"
var warped_points : Array[Vector2] = []

var noise := FastNoiseLite.new()

func _ready() -> void:
	# Setup noise parameters for smooth warping
	noise.seed = randi()
	noise.fractal_octaves = 4
	noise.frequency =.008
	
	generatePoints()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		generatePoints()
		for y in range(gridSizeY):
			for x in range(gridSizeX):
				findClosestPoint(x, y, warped_points)
		
		# Draw those points based on the direction they are drifting
		for i in points.size():
			set_cell(points[i], 0, Vector2i(0, 5)) 


func reset() -> void:
	points.clear()
	pointsDir.clear()
	warped_points.clear()
	for y in range(gridSizeY):
		for x in range(gridSizeX):
			set_cell(Vector2i(x, y), 0, Vector2i(5, 5))

func generatePoints() -> void:
	reset()
	
	for i in range(numOfPoints):
		var point = Vector2i(randi() % gridSizeX, randi() % gridSizeY)
		points.push_back(point)
		# Generate random direction vector 
		var direction = randi() % 4
		match  direction:
			0:
				pointsDir.push_front(Vector2i(1,0))
			1:
				pointsDir.push_front(Vector2i(-1,0))
			2:
				pointsDir.push_front(Vector2i(0,1))
			3:
				pointsDir.push_front(Vector2i(0,-1))
		
	warped_points = []
	for p in points:
		warped_points.push_back(warp_position(p))

func warp_position(pos: Vector2i) -> Vector2:
	var warp_amount = 40.0  # tweak this for more/less warping
	return Vector2(
		pos.x + noise.get_noise_2d(pos.x, pos.y) * warp_amount,
		pos.y + noise.get_noise_2d(pos.x + 1000, pos.y + 1000) * warp_amount
	)

func findClosestPoint(x: int, y: int, warped_points: Array) -> void:
	var target = warp_position(Vector2i(x, y))
	
	var closestIndex = -1
	var secondClosestIndex = -1
	var closestDistance = INF
	var secondClosestDistance = INF
	
	for i in range(warped_points.size()):
		var d = target.distance_to(warped_points[i])
		if d < closestDistance:
			secondClosestDistance = closestDistance
			secondClosestIndex = closestIndex
			closestDistance = d
			closestIndex = i
		elif d < secondClosestDistance:
			secondClosestDistance = d
			secondClosestIndex = i
	
	var EDGE_THRESHOLD = 1  # increase to thicken edges
	
	if abs(secondClosestDistance - closestDistance) < EDGE_THRESHOLD:
		# This cell is on an edge
		if (pointsDir[closestIndex] - pointsDir[secondClosestIndex]) != Vector2i(0,0):
			set_cell(Vector2i(x, y), 0, Vector2i(0, 3))  # Black tile for edge
		else:
			set_cell(Vector2i(x, y), 0, Vector2i(0, 5))  # Black tile for edge
	else:
		#set_cell(Vector2i(x, y), 0, Vector2i((closestIndex % 4) + 2, 5))
		match pointsDir[closestIndex]:
			Vector2i(0,1):
				set_cell(Vector2i(x, y), 0, Vector2i(5, 0)) # Moving Up : White / Snow
			Vector2i(0,-1):
				set_cell(Vector2i(x, y), 0, Vector2i(10, 1)) # Moving Down : Orange / Tan
			Vector2i(1,0):
				set_cell(Vector2i(x, y), 0, Vector2i(2, 4)) # Moving Right : Green
			Vector2i(-1,0):
				set_cell(Vector2i(x, y), 0, Vector2i(0, 0)) # Moving Left : Blue

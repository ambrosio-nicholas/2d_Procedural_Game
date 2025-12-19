extends TileMapLayer

@export var gridSizeX : int = 400
@export var gridSizeY : int = 400

@export var numOfPoints : int = 10
var points : Array[Vector2i] = []
var warped_points : Array[Vector2] = []

var noise := FastNoiseLite.new()

func _ready() -> void:
	# Setup noise parameters for smooth warping
	noise.seed = randi()
	noise.fractal_octaves = 2
	noise.frequency =.005
	
	generatePoints()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		generatePoints()
		for y in range(gridSizeY):
			for x in range(gridSizeX):
				findClosestPoint(x, y, warped_points)
		
		# Draw those points as black squares
		for i in points.size():
			set_cell(points[i], 0, Vector2i(0, 5))

func reset() -> void:
	points.clear()
	warped_points.clear()
	for y in range(gridSizeY):
		for x in range(gridSizeX):
			set_cell(Vector2i(x, y), 0, Vector2i(5, 5))

func generatePoints() -> void:
	reset()
	
	for i in range(numOfPoints):
		var p = Vector2i(randi() % gridSizeX, randi() % gridSizeY)
		points.push_back(p)
		
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
	var closestDistance = INF
	var secondClosestDistance = INF
	
	for i in range(warped_points.size()):
		var d = target.distance_to(warped_points[i])
		if d < closestDistance:
			secondClosestDistance = closestDistance
			closestDistance = d
			closestIndex = i
		elif d < secondClosestDistance:
			secondClosestDistance = d
	
	var EDGE_THRESHOLD = 0.5  # increase to thicken edges
	
	if abs(secondClosestDistance - closestDistance) < EDGE_THRESHOLD:
		# This cell is on an edge
		set_cell(Vector2i(x, y), 0, Vector2i(0, 5))  # Black tile for edge
	else:
		set_cell(Vector2i(x, y), 0, Vector2i((closestIndex % 4), 3))

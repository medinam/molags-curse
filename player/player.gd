extends KinematicBody

const SPEED = 3
const ACCEL = 2
const DEACCEL = 6
const GRAVITY = -9.8 * 3

var camera_angle = 0
var mouse_sensitivity = 1.5
var velocity = Vector3()

onready var actioner = $Offset/Head/Camera/Actioner
onready var hit_area = $Offset/Head/Camera/HitArea
onready var head_at = $Offset/Head/AnimationTree
onready var right_hand = $Objects/RightHand/AnimationTree
onready var offset_ap = $Offset/AnimationPlayer

var hp = 100.0
var gold = 0

var head_st: AnimationNodeStateMachinePlayback
var right_hand_st: AnimationNodeStateMachinePlayback

var stop_player = false

func _ready():
	GameManager.player = self
	
	head_st = head_at.get("parameters/playback")
	right_hand_st = right_hand.get("parameters/playback")
	
	head_st.start("idle")
	right_hand_st.start("idle")
	
	var right_hand_ap = $Objects/RightHand/AnimationPlayer
	right_hand_ap.connect("animation_finished", self, "_on_animation_finished")

func _process(delta):
	if velocity.length() < 0.5:
		head_st.travel("idle")
	else:
		head_st.travel("walking")
	
	if actioner.is_colliding():
		var collider = actioner.get_collider()
		GameManager.game_info.show_action_icon(collider.has_method("actuate"))
	else:
		GameManager.game_info.show_action_icon(false)
	
	GameManager.game_info.player_hp(hp)

func _input(event):
	if event is InputEventMouseMotion:
		# Horizontal aim
		$Offset/Head.rotate_y(deg2rad(-event.relative.x * mouse_sensitivity))
		
		# Vertical aim
		var change = -event.relative.y * mouse_sensitivity
		var next_angle = change + camera_angle
		if next_angle < 90 and next_angle > -90:
			$Offset/Head/Camera.rotate_x(deg2rad(change))
			camera_angle += change
	
	if event.is_action_pressed("action"):
		if actioner.is_colliding():
			var collider = actioner.get_collider()
			if collider.has_method("actuate"):
				collider.actuate()
	
	if event.is_action_pressed("hit"):
		right_hand_st.travel("attack")
		yield($Objects/RightHand/AnimationPlayer, "animation_finished")

func _physics_process(delta):
	var c_basis = $Offset/Head/Camera.global_transform.basis
	var h_basis = $Offset/Head.global_transform.basis
	var o_basis = $Objects.transform.basis
	
	var current_rot = Quat($Objects.transform.basis.orthonormalized())
	var target_rot = Quat(c_basis)
	var smoothrot = current_rot.slerp(target_rot, 0.20)
	
	$Objects.transform.basis = Basis(smoothrot)
	
	var direction = Vector3()
	
	if not stop_player:
		if Input.is_action_pressed("ui_down"):
			direction += h_basis.z
		if Input.is_action_pressed("ui_up"):
			direction -= h_basis.z
		if Input.is_action_pressed("ui_right"):
			direction += c_basis.x
		if Input.is_action_pressed("ui_left"):
			direction -= c_basis.x
	
	direction = direction.normalized()
	velocity.y += GRAVITY * delta
	
	var temp_velocity = velocity
	temp_velocity.y = 0
	
	var target = direction * SPEED
	
	var acceleration = DEACCEL
	if direction.dot(temp_velocity) > 0:
		acceleration = ACCEL
	
	temp_velocity = temp_velocity.linear_interpolate(target, acceleration * delta)
	
	velocity.x = temp_velocity.x
	velocity.z = temp_velocity.z
	
	velocity = move_and_slide(velocity, Vector3(0, 1, 0))

func do_damage():
	var bodies = hit_area.get_overlapping_bodies()
	for body in bodies:
		if body.has_method("hit"):
			body.hit(-$Objects.transform.basis.z, 8)

func got_hit():
	hp -= 20

func run_pickup_anim():
	stop_player = true
	$Offset/AnimationPlayer.play("pickup")
	$PickupItemDelay.start()

func run_sharpening_sword_anim():
	stop_player = true
	right_hand_st.travel("sharpening_sword")
	$SharpeningSwordDelay.start()

func _on_pickup_item_delay_timeout():
	stop_player = false

func _on_sharpening_sword_delay_timeout():
	stop_player = false

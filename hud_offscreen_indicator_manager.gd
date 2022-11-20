extends Control

# OffscreenIndicatorManager
# This script (and the accompanying scene) handles automatically setting
# offscreen indicators for enemies; at-screen-edge sprites that point toward
# the direction of the enemy relative to the player and allow for the player
# to know where enemies are, even when they cannot see the enemy.

##############################################################################

# README

# Script written by DanDoesAThing (aka Daniel Newby), 2022
# Script and Scene distributed under MIT License
# [Thanks to KCC]
# It would not have been possible without the KidsCanCode minimap/radar
# tutorial, which helped correct some of my misunderstandings and provided
# a great starting point.
# KCC Minimap/Radar Tutorial @:
# http://kidscancode.org/godot_recipes/3.x/ui/minimap/
# Strongly recommend other Godot devs checking out their materials.
# Of course, thanks to Godot and all Godot contributors for this amazing
# open-source game development ecosystem.

# HOW TO USE
# 1) Set up the script; see heading 'To Use (Script Setup)'
# To Use (In-Editor Scene Hierarchy)
# To Use (On Enemies)

# TO USE (SCRIPT SETUP):
# The properties player_node and camera_node need to be set in order
# for this script to work correctly. In future versions (NOTE: TODO) you
# will be able to drag+drop an export/package from the editor scene tree,
# but currently only in-script assignment is supported.
# You can do this via singleton (see below) or scene path, just make
# sure to assign the player at _ready() or on _process()
# [Notes on my own implementation]
# In my own implementation  of this module I have a singleton (GlobalPool)
# that keeps reference variables for main_player_node and main_camera_node;
# whenever a player scene enters the scene tree, or a camera2D scene's
# 'current' property is set/unset, these referenecs are updated.

# TO USE (IN-EDITOR SCENE HIERARCHY):
# hud_offscreen_indicator_manager.tscn should be instanced beneath
# player_node and camera_node, with a CanvasLayer node between them.
# The hierarchy should look like:
# Player Node
#	-> Camera2D Node
#		-> CanvasLayer Node
#			-> OffscreenIndicatorManager

# TO USE (ON ENEMIES):
# The string at the property 'needs_indicator_groupref' should be a group
# that enemies (at least any enemy you wish to have an automatically-assigned
# indicator) are assigned to
# Add the line
# add_to_group("group_string")
# to the _ready() method of your enemies. Where "group_string" is the same
# string as assigned to the property 'needs_indicator_groupref' in this script
# [Notes on my own implementation]
# In my own implementation I assigned the group string in a reference singleton
# ('GlobalRef') that I then reference in both this script and with the
# _ready() method on enemies

# MAKING ADJUSTMENTS:
# You can make tweaks to the script and scene to change the behaviour
# of the offscreen indicator system. Some tweaks you can make:
#	INDICATOR_EDGE_BOUNDARY <- adjust to force indicators further in-screen
#	$IndicatorHolder.rect_min_size <- restrict the area indicators are clamped
#	$OffscreenIndicatorManager <- changeType from centerContainer to make radar
#	$IndicatorHolder/OffscreenIndicator.texture <- change indicator sprite

# CLOSING
# Supports v3.2.2.stable.official
# Revisions or tweaking may be needed to support Godot 4 and beyond,
# I have yet to work with 4.0 so I would appreciate feedback from anyone
# who attempts to use this module with it.
# Feel free to contact me on the Github page if you need any help with
# implementation of this module, if you have any suggestions, or if
# you encounter any bugs.

##############################################################################

# temporary print statement logging
# this should not be set true for a live build
const DEBUG_LOGGING := false

# hardcoded rotation toggle, for if dev uses sprites that shouldn't rotate
# NOTE: implement alternate indicators for different entities, as a script
# with toggles/exports (group, sprite path, sprite offset, should rotate, etc.)
const ENABLE_INDICATOR_ROTATION = false

# forced indicator distance (in px) from edge of bounds,
# shrinking the allowed placement area for indidcators
const INDICATOR_EDGE_BOUNDARY := 25

# size of the area (adj. by camera zoom and indicator root area) which
# offscreen indicators are confined to
var overlay_bounds := Vector2.ZERO

# player is the target for all ofscreen indicators
# this implementation only works for a single player and viewport
# some revision/refactoring necessary for multiplayer (local or online)
var player_node = null #setget _set_player_node
var player_position := Vector2.ZERO

var needs_indicator_groupref = "group_enemy_that_should_appear_on_minimap"

# the currently active camera2D following the player
# TODO: implement setter, export(package), & signal if camera changed
var camera_node = null #setget _set_camera_node

# record of what enemy has what indicator node attached to it
# relevant for knowing when to remove indicators (if enemies are removed)
var active_indicator_record := {}

# independent list of which indicators are being used
var group_indicator_active := "offscreen_indicator_in_use"
var group_indicator_inactive := "offscreen_indicator_not_in_use"

# indicator root is the ui container for all offscreen indicator sprites
onready var indicator_root: Container =\
		$IndicatorHolder
# center_indicator is an invisible indicator which offscreen indicators rotate
# toward, due to the faux-radar implementation of the off-indic system
onready var center_indicator_sprite_node: Sprite =\
		$IndicatorHolder/PlayerMarker
# this is the base sprite for offscreen indicators that all offscreen
# indicators are duplicated from, it isn't an in-use indicator
onready var base_indicator_sprite_node: Sprite =\
		$IndicatorHolder/OffscreenIndicatorSprite

##############################################################################


## whenever the player node property is set, call position update
## add your own validation for player class here
## i.e. in my game the method args read:
## func _set_player_node(value: Player):
#func _set_player_node(value):
#	player_node = value
#	# this is deprecated at the only time the player_node is set, it
#	# is immediately before this method is called anyway
#	update_player_position()


##############################################################################


# Called when the node enters the scene tree for the first time.
func _ready():
	# hook up viewport changes to recalculate the overlay bounds
	var _discard
#	_discard =\
#			get_viewport().connect("size_changed", self, "update_indicator_root_min_size")
	_discard =\
			get_tree().root.connect("size_changed", self, "update_indicator_root_margins")
	
	# the invisible player indicator (for faux radar overlay) needs centering
	_center_indicator(center_indicator_sprite_node)
	# NOTE: add minimum size configuration by viewport (and signal connect)
	# NOTE: add position adjustment for indicator holder (remove
	# the parent center container or adjust it to a basic control?)
	# Note for devs: SET INDICATOR GROUP HERE
	needs_indicator_groupref = GlobalRef.group_offscreen_indicator

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	# 
	if overlay_bounds == Vector2.ZERO:
		# this will call update_overlay_bounds() as part of the method
		update_indicator_root_margins()
	
	# most methods rely on knowing where the player is (from globalPool)
	# will attempt to set player and find player position each frame
	if player_node == null:
		# Note for devs: SET YOUR PLAYER HERE
		self.player_node = GlobalPool.main_player_node
		# NOTE: maybe add connections for enabled/disabled player to unset this
	
	# no further progress if player wasn't set
	if player_node != null:
		update_player_position()
		# loop through every active enemy who requires an offscreen indicator
		# call update indicator to either move the attached indicator, or, if
		# one wasn't found, attach an unused indicator or create a new one
		var get_all_enemies =\
				get_tree().get_nodes_in_group(needs_indicator_groupref)
		# NOTE: potential performance gain by checking if enemy is actually
		# offscreen or not before doing anything to the attached indicator
		for enemy in get_all_enemies:
			update_indicator(enemy)


##############################################################################


# call this method whenever indicator root needs to resize
# sets the indicator root node to the size of the viewport,
# less adjustments for the edge boundary constant
func update_indicator_root_margins():
	# indicator root (base ui boundaries) shrunk by edge boundary constant
	# furthest edges shrunk by constant twice to center the indicator bounds
	var viewport_size = get_viewport_rect().size
	# the viewport should never be this small, raise error if so
	assert(viewport_size.x > 0 and viewport_size.y > 0)
	# validate divisor is greater than 0 before division operation
	if viewport_size.x > 0\
	and viewport_size.y > 0:
		# get half screen
		var half_viewport_x = viewport_size.x/2
		var half_viewport_y = viewport_size.y/2
		
		# prepare top-left margins
		var bounds_margin_left = 0
		var bounds_margin_top = 0
		# top-left (near) margins cannot exceed half the viewport
		bounds_margin_left = clamp(INDICATOR_EDGE_BOUNDARY, 0, half_viewport_x)
		bounds_margin_top = clamp(INDICATOR_EDGE_BOUNDARY, 0, half_viewport_y)
		
		var bounds_margin_right = 0 
		var bounds_margin_bottom = 0
		# bottom-right (far) margins apply edge boundary twice to
		# account for the offset of the near margins
		# set as viewport size to stretch before subtracting the edge boundary
		# combination of near and far margins should center indicators
		# far margins cannot be less than half the axis (the near margin cap)
		# far margins cannot be greater than the viewport axis
		bounds_margin_right =\
				clamp(viewport_size.x-INDICATOR_EDGE_BOUNDARY*2,\
				half_viewport_x, viewport_size.x)
		bounds_margin_bottom =\
				clamp(viewport_size.y-INDICATOR_EDGE_BOUNDARY*2,\
				half_viewport_y, viewport_size.y)
		
		# now we've calculated margins, set the margins
		indicator_root.margin_left = bounds_margin_left
		indicator_root.margin_top = bounds_margin_top
		indicator_root.margin_right = bounds_margin_right
		indicator_root.margin_bottom = bounds_margin_bottom
	
		# if the viewport axis is valid, readjust overlay bounds
		update_overlay_bounds()


# the overlay boundaries are the area in which offscreen indicators
# are confined to; this is calculated from viewport_rect, camera zoom,
# and the size of the indicator root (ui container scene)
func update_overlay_bounds():
	# default values
	var new_calculated_boundaries = Vector2.ZERO
	var calculate_viewport_scale = Vector2.ZERO
	var current_bounding_rect = Vector2.ZERO
	current_bounding_rect = _get_indicator_bounds_rect()

	# main method block
	# viewport scale is a function of viewport and camera zoom
	calculate_viewport_scale = _get_viewport_scale()
	# no axis can be nil when we're about to perform a division operation
	if current_bounding_rect.x > 0\
	and current_bounding_rect.y > 0\
	and calculate_viewport_scale.x > 0\
	and calculate_viewport_scale.y > 0:
		new_calculated_boundaries =\
				current_bounding_rect/calculate_viewport_scale
	
		# this block for debugging only
		# verbose logging for debugging problems with viewport scale
		if DEBUG_LOGGING:
			print("calculating boundaries and viewport scale")
			print("viewport = {1}".format({"1": calculate_viewport_scale}))
			print("boundaries = {1}".format({"1": new_calculated_boundaries}))
	# ergo
	# if calculate_viewport_scale == Vector2.ZERO:
	# which means _get_viewport_scale() returned without setting viewport scale
	else:
		if DEBUG_LOGGING:
			print("ERROR viewport scale not found in update_overlay_bounds")
			print_stack()
	
	# output block, no output if calculated boundaries wasn't in main block
	if new_calculated_boundaries != Vector2.ZERO:
		overlay_bounds = new_calculated_boundaries


# set player position for determining vector to player from indicated enemies
func update_player_position():
	if player_node != null:
		player_position = player_node.position


# check if target has an indicator
# move the indicator (including clamping it to bounds)
# point the indicator toward player/enemy (if ENABLE_INDICATOR_ROTATION true)
func update_indicator(target):
	var target_indicator: Sprite
	target_indicator = _get_indicator(target)
	# if an existing indicator was found and was added to tree properly
	if target_indicator != null\
	and target_indicator.is_inside_tree():
		_update_indicator_position(target, target_indicator)#
		# rotation will immediately check ENABLE_INDICATOR_ROTATION
		_update_indicator_rotation(target, target_indicator)
		
		# visibility reversed to only show indicators for offscreen enemies
		target_indicator.visible = !target.visible
		# NOTE: in own implementation would prefer to check for an 'onscreen'
		# property, so visibility can be controlled independently of offscreen
		# indicator behaviour and not create edge cases where the indicator
		# is toggled whilst the enemy is actually onscreen
	
	# if no attached indicator was found, attach one
	# this uses object pooling behaviour to either find an unattached
	# indicator that was previously used for a now-removed-from-tree enemy
	# or duplicates the sample offscreen indicator sprite node
	else:
		_attach_new_indicator(target)


##############################################################################


# search the active indicator record to find the indicator
# attached to the target enemy
func _get_indicator(target) -> Sprite:
	var get_target_indicator
	# active_indicator_record is key/value of enemy/indicator
	if target in active_indicator_record:
		get_target_indicator = active_indicator_record[target]
		
		# this should always be a sprite
		assert(get_target_indicator is Sprite)
		if get_target_indicator is Sprite:
			return get_target_indicator
		# why is a non-sprite in the active_indicator_record values?
		else:
			if DEBUG_LOGGING:
				print("ERROR non-sprite found in active indicator record")
				print_stack()
#			GlobalDebug.log_error()
			return null
	else:
		# this is an acceptable null return, just means we haven't
		# created the indicator yet (so no need to throw error)
#		GlobalDebug.log_error()
		return null


# method to decide whether to find an unused indicator or create a new one
func _attach_new_indicator(target):
	# find an unused indicator
	var indicator_to_activate
	# [early implementation of globalPool behaviour follows]
	# get inactive offscreen indicators
	# inactivate indicators is empty if all indicators are being used
	var inactive =\
			get_tree().get_nodes_in_group(group_indicator_inactive)
	# if there's already an indicator not being used, use that	
	# pop_back faster than pop_front
	indicator_to_activate = inactive.pop_back()
	# will return null if array is empty
	if indicator_to_activate != null:
		# ready this indicator to be reused
		indicator_to_activate.remove_from_group(group_indicator_inactive)
	else:
		# no indicator found, create a new one
		indicator_to_activate = base_indicator_sprite_node.duplicate()
		indicator_root.add_child(indicator_to_activate)
	
	# either the found indicator or the new indicator is ready to be assigned
	_activate_indicator(target, indicator_to_activate)


# method to assign an offscreen indicator to a target
func _activate_indicator(target, indicator_to_activate):	
	# should always be a sprite
	if not indicator_to_activate is Sprite:
		GlobalDebug.log_error()
	assert(indicator_to_activate is Sprite)
	
	# signal connection block
	# NOTE: remove this signal on deactivation?
	# before activating indicators make sure that if the target
	# is removed from the tree, the indicator is disabled
	var _discard
	if target.has_signal("tree_exiting"):
		_discard =\
				target.connect("tree_exiting",\
				self, "deactivate_indicator", [target])
	
	# set it to active by adjusting group
	active_indicator_record[target] = indicator_to_activate
	if not indicator_to_activate.is_in_group(group_indicator_active):
		indicator_to_activate.add_to_group(group_indicator_active)


# when an enemy is removed from the tree, remove any attached indicator
func _deactivate_indicator(target):
	# NOTE: add disconnect signal behaviour
	var get_indicator
	if target in active_indicator_record:
		# find the attached indicator
		get_indicator = active_indicator_record[target]
		# remove attachment record
		# already valdiating above so erase 100% should work
		var _discard
		_discard = active_indicator_record.erase(target)
		# TODO: maybe check error code anyway and raise error/assert
		
		# hide indicator, in case it was deactivated whilst in use
		get_indicator.visible = false
		# NOTE: in own implementation would prefer to check for an 'onscreen'
		# property, so visibility can be controlled independently of offscreen
		# indicator behaviour and not create edge cases where the indicator
		# is toggled whilst the enemy is actually onscreen
		
		# set to inactive by changing group ownership of the indicator
		if get_indicator.is_in_group(group_indicator_active):
			get_indicator.remove_from_group(group_indicator_active)
		if not get_indicator.is_in_group(group_indicator_inactive):
			get_indicator.add_to_group(group_indicator_inactive)
	# method shouldn't be called if the target isn't in the indicator record
	else:
		if DEBUG_LOGGING:
			print("ERROR _deactivate_indicator passed a non-valid target")
			print_stack()


##############################################################################


# to adjust the indicator position we calculate the difference in position
# from the target to the player, then multiply that difference relative
# to the size of the boundaries
# takes into account potential game zoom, different viewport sizes, and
# the size of the indicator holder (so can fix indicators to a portion
# of the screen if you want, such as for a radar)
func _update_indicator_position(target, target_indicator: Sprite):
	var half_boundary_dist = _get_indicator_bounds_midpoint()
	var new_pos =\
			(target.position - player_position)\
			*overlay_bounds+half_boundary_dist
	# clamp values within allowed bounds
	# position cannot be clamped after set, the newly calculated position
	# has to be clamped before it is assigned to the indicator position
	target_indicator.position = _clamp_indicator_position(new_pos)


# pass vector2 position, return it clamped within bounds of the ui container
func _clamp_indicator_position(given_pos: Vector2) -> Vector2:
	var min_bound_x = 0
	var max_bound_x = indicator_root.rect_size.x
	var min_bound_y = 0
	var max_bound_y = indicator_root.rect_size.y# - INDICATOR_EDGE_BOUNDARY
	# get the axis values
	var clamped_axis_x = given_pos.x
	var clamped_axis_y = given_pos.y
	# clamp the axis values to the bounding min/max
	clamped_axis_x = clamp(clamped_axis_x, min_bound_x, max_bound_x)
	clamped_axis_y = clamp(clamped_axis_y, min_bound_y, max_bound_y)
	# set the newly clamped axis values to a new vector2
	var clamped_pos = Vector2(clamped_axis_x, clamped_axis_y)
	return clamped_pos


# if enabled, rotate indicator to point at center of the ui container
# method should be called after setting the indicators position for the frame
# NOTE: review whether invisible player marker sprite is necessary,
# could just get the center point of the rect instead
func _update_indicator_rotation(_target, target_indicator: Sprite):
	if ENABLE_INDICATOR_ROTATION:
		target_indicator.look_at(center_indicator_sprite_node.global_position)
		# add (circumference/diameter)/2 to rotation
		target_indicator.rotation += PI/2


##############################################################################


# the viewport scale is a function of viewport rect dimensions multiplied
# by the current camera zoom - allowing for the game to zoom in and out
# without the indicators being forced into or out of the screen
func _get_viewport_scale():
	var get_viewport_scale = Vector2.ZERO
	# TODO: implement setter, export(package), & signal if camera changed
	camera_node = GlobalPool.main_camera_node
	if camera_node is Camera2D:
		get_viewport_scale =\
				get_viewport_rect().size*camera_node.zoom
	else:
		GlobalDebug.log_error()
	return get_viewport_scale


# centers the invisible player indicator
# originally used for KCC radar interpretation, leftover that could
# potentially be depreciated in favour of just getting vec2 center of the ui
# container rect, but is left incase dev wishes to revert to radar behaviour
func _center_indicator(given_indicator: Sprite):
	given_indicator.position = _get_indicator_bounds_midpoint()


# get bounds of indicator root
func _get_indicator_bounds_rect() -> Vector2:
	if "rect_size" in indicator_root:
		var indicator_bounding_rect = indicator_root.rect_size
		if DEBUG_LOGGING:
			print("_get_indicator_bounds_rect: ({size})").format(\
			{"size": indicator_bounding_rect})
		return indicator_bounding_rect
	else:
		if DEBUG_LOGGING:
			print("_get_indicator_bounds_rect couldn't find indicator root")
			print_stack()
		return Vector2.ZERO


# get bounds of indicator root
func _get_indicator_bounds_midpoint() -> Vector2:
	if "rect_size" in indicator_root:
		var indicator_bounding_rect = indicator_root.rect_size
		var indicator_bounding_midpoint = Vector2.ZERO
		# no axis can be nil when we're about to perform a division operation
		if indicator_bounding_rect.x > 0\
		and indicator_bounding_rect.y > 0:
			indicator_bounding_midpoint = indicator_bounding_rect/2
		if DEBUG_LOGGING:
			print("_get_indicator_bounds_midpoint: ({size})").format(\
			{"size": indicator_bounding_midpoint})
		return indicator_bounding_midpoint
	else:
		if DEBUG_LOGGING:
			print("_get_indicator_bounds_midpoint couldn't find indicator root")
			print_stack()
		return Vector2.ZERO

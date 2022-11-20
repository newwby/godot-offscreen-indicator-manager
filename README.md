#### Note: No demo project as of yet, coming soon. Initial release package will follow.

---

# Offscreen Indicator Manager
Developed for 2D games in the Godot Game Engine (https://github.com/godotengine/godot)

A small scene and accompanying script for Godot that handles automatically setting offscreen indicators for enemies; at-screen-edge sprites that point toward the direction of the enemy relative to the player and allow for the player to know where enemies are, even when they cannot see the enemy. The script includes simple object pooling for performance, can support any resolution, and is adjustable for the developer's need (including being reinterpreted as a minimap or radar).

Supports v3.2.2.stable.official
Revisions or tweaking may be needed to support Godot 4 and beyond, I have yet to work with 4.0 so I would appreciate feedback from anyone who attempts to use this module with it. Feel free to contact me on Github if you need any help with implementation of this module, if you have any suggestions, or if you encounter any bugs.

---

#### How to use (pending release package and demo project):

Download the following files:

hud_offscreen_indicator_manager.gd, hud_offscreen_indicator_manager.tscn, hazard_offscreen_indicator_64px.png

1) Follow the instructions in the .gd script (or see below for detailed instructions) for setup.
2) Fix the broken sprite texture path (open the .tscn scene in Godot and set the hazard_offscreen_indicator_64px texture to the OffscreenIndicatorSprite node)

---

#### README taken from hud_offscreen_indicator_manager.gd

Script written by DanDoesAThing (aka Daniel Newby), 2022. Distributed under MIT License

It would not have been possible without the KidsCanCode minimap/radar tutorial, which helped correct some of my misunderstandings and provided a great starting point.
You can find the KCC Minimap/Radar Tutorial here: http://kidscancode.org/godot_recipes/3.x/ui/minimap/
(I strongly recommend other Godot devs checking out their materials).

Of course, thanks to Godot and all Godot contributors for this amazing open-source game development ecosystem.

#### HOW TO USE
1) Set up the script; see heading 'To Use (Script Setup)'
2) Set up the HUD scene; see heading 'To Use (In-Editor Scene Hierarchy)'
3) Set up the enemy group; see heading 'To Use (On Enemies)'

#### TO USE (SCRIPT SETUP):
The properties player_node and camera_node need to be set in order for this script to work correctly. In future versions I will add the ability to drag+drop an export/package from the editor scene tree, but currently only in-script assignment is supported.
You can do this via singleton (see below) or scene path, just make sure to assign the player at _ready() or on _process().

[Notes on my own implementation]
In my own implementation  of this module I have a singleton (GlobalPool) that keeps reference variables for main_player_node and main_camera_node; whenever a player scene enters the scene tree, or a camera2D scene's 'current' property is set/unset, these referenecs are updated.

#### TO USE (IN-EDITOR SCENE HIERARCHY):
hud_offscreen_indicator_manager.tscn should be instanced beneath player_node and camera_node, with a CanvasLayer node between them.
The hierarchy should look like:
-		Player Node
-			-> Camera2D Node
-				-> CanvasLayer Node
-					-> OffscreenIndicatorManager

#### TO USE (ON ENEMIES):
The string at the property 'needs_indicator_groupref' should be a group that enemies (at least any enemy you wish to have an automatically-assigned indicator) are assigned to.
Add the line:
add_to_group("group_string")
to the _ready() method of your enemies. Where "group_string" is the same string as assigned to the property 'needs_indicator_groupref' in this script

[Notes on my own implementation]
In my own implementation I assigned the group string in a reference singleton ('GlobalRef') that I then reference in both this script and with the _ready() method on enemies.

#### MAKING ADJUSTMENTS:
You can make tweaks to the script and scene to change the behaviour of the offscreen indicator system. Some tweaks you can make:

INDICATOR_EDGE_BOUNDARY <- adjust to force indicators further in-screen

$IndicatorHolder.rect_min_size <- restrict the area indicators are clamped

$OffscreenIndicatorManager <- changeType from centerContainer to make radar

$IndicatorHolder/OffscreenIndicator.texture <- change indicator sprite

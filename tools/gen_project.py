# Writes project.godot (input map included). Run: python3 tools/gen_project.py
KEYS = {
 "move_left": [65, 4194319], "move_right": [68, 4194321], "move_up": [87, 4194320], "move_down": [83, 4194322],
 "attack": [32, 74], "skill_1": [49, 81], "skill_2": [50, 69], "skill_3": [51, 70], "ultimate": [52, 82],
 "recall": [66], "heal": [72], "pause": [4194305, 80], "toggle_autopilot": [4194339],
}
def ev(k):
    return ('Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,'
            '"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,'
            '"keycode":0,"physical_keycode":%d,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)' % k)
inp = "\n".join('%s={\n"deadzone": 0.2,\n"events": [%s]\n}' % (a, ", ".join(ev(k) for k in ks)) for a, ks in KEYS.items())
txt = f'''; Engine configuration file.
; Open this folder (project.godot) with Godot 4.5.x.
; The game title shown on the title screen comes from config/name below.

config_version=5

[application]

config/name="Spirebreak"
config/description="Original 3v3 one-lane mobile MOBA prototype (bots)"
config/version="0.3"
run/main_scene="res://scenes/title.tscn"
config/features=PackedStringArray("4.5", "GL Compatibility")
boot_splash/bg_color=Color(0.07, 0.08, 0.12, 1)
config/icon="res://icon.svg"

[autoload]

Game="*res://scripts/game.gd"
Sfx="*res://scripts/sfx.gd"

[display]

window/size/viewport_width=1136
window/size/viewport_height=640
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/handheld/orientation=0

[input]

{inp}

[input_devices]

pointing/emulate_mouse_from_touch=true

[physics]

common/physics_ticks_per_second=60
2d/default_gravity=0.0

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/canvas_textures/default_texture_filter=1
environment/defaults/default_clear_color=Color(0.07, 0.08, 0.12, 1)
anti_aliasing/quality/msaa_2d=0
'''
open("project.godot", "w").write(txt)
print("ok")

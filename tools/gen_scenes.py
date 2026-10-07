# Writes scenes/maps/one_lane.tscn, scenes/match.tscn, scenes/title.tscn.
# Bootstrap only: after this, edit the scenes in Godot (drag markers, move towers).
import math
half = [(640,4460),(1120,4120),(1650,3870),(1950,3380),(2230,2880),(2550,2550)]
lane = half + [(y,x) for (x,y) in reversed(half[:-1])]
river = [(-150,-150),(700,800),(1500,1450),(2550,2550),(3500,3650),(4350,4250),(5250,5250)]

def cr(pts, seg):
    out=[]; n=len(pts)
    for i in range(n-1):
        p0=pts[max(i-1,0)]; p1=pts[i]; p2=pts[i+1]; p3=pts[min(i+2,n-1)]
        for s in range(seg):
            t=s/seg; t2=t*t; t3=t2*t
            out.append(tuple(0.5*((2*p1[k])+(-p0[k]+p2[k])*t+(2*p0[k]-5*p1[k]+4*p2[k]-p3[k])*t2+(-p0[k]+3*p1[k]-3*p2[k]+p3[k])*t3) for k in (0,1)))
    out.append(pts[-1]); return out
L = cr(lane, 12)
cum=[0.0]
for i in range(1,len(L)): cum.append(cum[-1]+math.dist(L[i],L[i-1]))
total=cum[-1]
def at(d):
    for i in range(1,len(L)):
        if cum[i]>=d:
            t=(d-cum[i-1])/(cum[i]-cum[i-1]); return (L[i-1][0]+(L[i][0]-L[i-1][0])*t, L[i-1][1]+(L[i][1]-L[i-1][1])*t)
    return L[-1]
print("lane length", round(total))
inner=at(total*0.17); outer=at(total*0.34)
def r(p): return "Vector2(%d, %d)" % (round(p[0]), round(p[1]))
structs = [
 ("DawnHeartspire",0,2,"heart",lane[0]), ("DawnInnerTower",0,1,"inner",inner), ("DawnOuterTower",0,0,"outer",outer),
 ("DuskOuterTower",1,0,"outer",(outer[1],outer[0])), ("DuskInnerTower",1,1,"inner",(inner[1],inner[0])), ("DuskHeartspire",1,2,"heart",lane[-1]),
]
camps=[(1250,3150),(2650,3800)]
camps = camps + [(y,x) for (x,y) in camps]
s = ['[gd_scene load_steps=6 format=3]','',
 '[ext_resource type="Script" path="res://scripts/map.gd" id="1_map"]',
 '[ext_resource type="Script" path="res://scripts/units/structure.gd" id="2_st"]',
 '[ext_resource type="Resource" path="res://data/units/tower_outer.tres" id="3_outer"]',
 '[ext_resource type="Resource" path="res://data/units/tower_inner.tres" id="4_inner"]',
 '[ext_resource type="Resource" path="res://data/units/heartspire.tres" id="5_heart"]','',
 '[node name="OneLane" type="Node2D"]','script = ExtResource("1_map")','',
 '[node name="Lane" type="Node2D" parent="."]','']
for i,p in enumerate(lane):
    s += ['[node name="L%02d" type="Marker2D" parent="Lane"]' % i, 'position = %s' % r(p), 'gizmo_extents = 40.0', '']
s += ['[node name="River" type="Node2D" parent="."]','']
for i,p in enumerate(river):
    s += ['[node name="R%02d" type="Marker2D" parent="River"]' % i, 'position = %s' % r(p), 'gizmo_extents = 40.0', '']
s += ['[node name="Camps" type="Node2D" parent="."]','']
for i,p in enumerate(camps):
    s += ['[node name="Camp%d" type="Marker2D" parent="Camps"]' % (i+1), 'position = %s' % r(p), 'gizmo_extents = 50.0', '']
s += ['[node name="DawnFountain" type="Marker2D" parent="."]','position = Vector2(250, 4850)','gizmo_extents = 60.0','',
      '[node name="DuskFountain" type="Marker2D" parent="."]','position = Vector2(4850, 250)','gizmo_extents = 60.0','',
      '[node name="Shrine" type="Marker2D" parent="."]','position = Vector2(3650, 3650)','gizmo_extents = 60.0','',
      '[node name="Structures" type="Node2D" parent="."]','']
ids={"outer":"3_outer","inner":"4_inner","heart":"5_heart"}
for name,team,tier,kind,p in structs:
    s += ['[node name="%s" type="Node2D" parent="Structures"]' % name, 'position = %s' % r(p), 'script = ExtResource("2_st")',
          'team_id = %d' % team, 'tier = %d' % tier, 'stats = ExtResource("%s")' % ids[kind], '']
open("scenes/maps/one_lane.tscn","w").write("\n".join(s))

m = '''[gd_scene load_steps=6 format=3]

[ext_resource type="Script" path="res://scripts/match.gd" id="1_match"]
[ext_resource type="Resource" path="res://data/match_config.tres" id="2_cfg"]
[ext_resource type="PackedScene" path="res://scenes/maps/one_lane.tscn" id="3_map"]
[ext_resource type="Script" path="res://scripts/units/fx_layer.gd" id="4_fx"]
[ext_resource type="Script" path="res://scripts/ui/hud.gd" id="5_hud"]

[node name="Match" type="Node2D"]
script = ExtResource("1_match")
config = ExtResource("2_cfg")

[node name="Map" parent="." instance=ExtResource("3_map")]

[node name="Ground" type="Node2D" parent="."]

[node name="Units" type="Node2D" parent="."]
y_sort_enabled = true

[node name="Air" type="Node2D" parent="."]
z_index = 5

[node name="Fx" type="Node2D" parent="."]
script = ExtResource("4_fx")

[node name="HUD" type="CanvasLayer" parent="."]
script = ExtResource("5_hud")
'''
open("scenes/match.tscn","w").write(m)
t = '''[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/title.gd" id="1_title"]

[node name="Title" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_title")
'''
open("scenes/title.tscn","w").write(t)
print("scenes written")

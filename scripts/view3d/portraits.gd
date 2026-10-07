class_name Portraits
extends RefCounted
## Renders hero head-and-shoulders portraits from the 3D models into small textures (SubViewports
## that render once). Used by the hero select cards and the in-match HUD portrait.


static func make(parent: Node, d: HeroData, team := 0, px := 160, yaw_deg := -18.0) -> ViewportTexture:
	var vp := SubViewport.new()
	vp.size = Vector2i(px, px)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	parent.add_child(vp)
	var root := Node3D.new()
	vp.add_child(root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("d6e2ff")
	e.ambient_light_energy = 0.7
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -30, 0)
	sun.light_energy = 1.0
	root.add_child(sun)
	var m := HeroModel.new().build(d, team)
	m.rotation_degrees.y = yaw_deg
	root.add_child(m)
	m.animate(0.0, 0.0)
	var cam := Camera3D.new()
	cam.fov = 30.0
	var head_y := 0.72 * d.model_scale
	cam.position = Vector3(0, head_y + 0.12, 1.75 * d.model_scale)
	root.add_child(cam)
	cam.look_at(Vector3(0, head_y - 0.05, 0), Vector3.UP)
	cam.current = true
	return vp.get_texture()

// Flat marks on the ground: range rings, area previews, blob shadows, team rings, aim lines.
// One quad (2 x 2 m, scaled by the node) per mark.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0);
// Alpha of the inside (0 = only the ring).
uniform float fill = 0.15;
// Ring thickness as a fraction of the radius (circle) or of the half width (rectangle).
uniform float ring = 0.1;
// 0 circle, 1 soft blob shadow, 2 rectangle (aim line), 3 pie slice (cone aim).
uniform int mode = 0;
// Pie slice half angle in radians (mode 3).
uniform float half_angle = 0.8;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = 0.0;
	if (mode == 1) {
		float d = length(p);
		a = (1.0 - smoothstep(0.15, 1.0, d)) * color.a;
	} else if (mode == 2) {
		float e = max(abs(p.x), abs(p.y) * 0.0);
		float edge = smoothstep(1.0 - ring, 1.0 - ring * 0.5, abs(p.x));
		float tip = smoothstep(0.96, 0.99, -p.y);
		a = max(fill, max(edge, tip)) * color.a;
	} else {
		float d = length(p);
		if (d > 1.0) discard;
		if (mode == 3) {
			float ang = abs(atan(p.x, -p.y));
			if (ang > half_angle) discard;
		}
		float edge = smoothstep(1.0 - ring, 1.0 - ring * 0.55, d) * (1.0 - smoothstep(0.985, 1.0, d));
		a = max(fill, edge) * color.a;
	}
	ALBEDO = color.rgb;
	ALPHA = clamp(a, 0.0, 1.0);
}

// River water: soft moving ripples, slightly see-through. Cheap enough for phones.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 deep : source_color = vec4(0.16, 0.5, 0.82, 0.9);
uniform vec4 light : source_color = vec4(0.55, 0.85, 1.0, 0.9);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME * 0.6;
	float r = sin(wpos.x * 2.1 + wpos.z * 1.3 + t * 2.0) * 0.5 + sin(wpos.x * -1.4 + wpos.z * 2.7 - t * 1.6) * 0.5;
	float bands = smoothstep(0.55, 0.95, r);
	// lighter near the banks (UV.x = across the river)
	float bank = 1.0 - smoothstep(0.0, 0.22, min(UV.x, 1.0 - UV.x));
	vec3 c = mix(deep.rgb, light.rgb, clamp(bands * 0.45 + bank * 0.5, 0.0, 1.0));
	ALBEDO = c;
	ALPHA = mix(deep.a, 0.95, bank);
}

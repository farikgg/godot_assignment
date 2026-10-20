shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// Sword trail on a half ring: UV.x runs along the arc (0 = start of the swing), UV.y from the inner (0)
// to the outer (1) edge. `progress` goes 0 → 1 over the swing: the bright head sweeps along the arc,
// a comet tail stays behind it, and everything fades out in the second half.

uniform vec4 core_color : source_color = vec4(1.0, 0.95, 0.75, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.42, 0.05, 1.0);
instance uniform float progress = 0.0;

void fragment() {
	float head = progress * 1.35;
	// revealed up to the head, softly trailing behind it
	float revealed = 1.0 - smoothstep(head - 0.05, head, UV.x);
	float tail = clamp(1.0 - (head - UV.x) * 1.4, 0.0, 1.0);
	float fade = 1.0 - smoothstep(0.45, 1.0, progress);
	// thin at the inner edge, brightest near the outer (blade tip) edge
	float radial = smoothstep(0.0, 0.8, UV.y) * (1.0 - smoothstep(0.9, 1.0, UV.y));
	ALBEDO = mix(edge_color.rgb, core_color.rgb, radial * tail);
	ALPHA = clamp(revealed * tail * fade * radial * 1.4, 0.0, 0.95);
}

shader_type canvas_item;

uniform bool enabled = false;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float width : hint_range(0.0, 10.0) = 1.0;
uniform float damage_flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 damage_flash_color : source_color = vec4(1.0, 0.2, 0.2, 0.55);

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	if (damage_flash > 0.0 && col.a > 0.0) {
		float tint_weight = clamp(damage_flash_color.a * damage_flash, 0.0, 1.0);
		col.rgb = mix(col.rgb, damage_flash_color.rgb, tint_weight);
	}
	if (enabled && col.a < 0.5) {
		vec2 ps = TEXTURE_PIXEL_SIZE;
		float a = 0.0;
		a += texture(TEXTURE, UV + vec2(-ps.x * width, 0.0)).a;
		a += texture(TEXTURE, UV + vec2(ps.x * width, 0.0)).a;
		a += texture(TEXTURE, UV + vec2(0.0, -ps.y * width)).a;
		a += texture(TEXTURE, UV + vec2(0.0, ps.y * width)).a;
		if (a > 0.0) {
			col = outline_color;
		}
	}
	COLOR = col;
}

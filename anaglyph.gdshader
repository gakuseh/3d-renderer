shader_type canvas_item;

uniform sampler2D left_eye;
uniform sampler2D right_eye;

void fragment() {
	vec4 left_color = texture(left_eye, UV);
	vec4 right_color = texture(right_eye, UV);
	
	COLOR = vec4(left_color.r, right_color.g, right_color.b, 1.0);
}
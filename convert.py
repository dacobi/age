import re

with open('plasma.frag', 'r') as f:
    frag = f.read()

start = frag.find('if (idx == 0) {')
end = frag.find('    outFragColor')

logic = frag[start:end]

gdshader = """shader_type canvas_item;

uniform float t_time = 0.0;
uniform float d_amp = 0.0;
uniform float d_sx = 0.0;
uniform float d_sy = 0.0;

uniform float r_s = 0.0;
uniform float s_bx = 10.0;
uniform float s_by = 10.0;
uniform float p_r = 0.0;

uniform float p_g = 0.333;
uniform float p_b = 0.666;
uniform float s_ma = 0.0;
uniform float s_msx = 0.0;

uniform float s_msy = 0.0;
uniform float w_b = 0.0;
uniform float w_a = 0.0;
uniform float w_s = 0.0;

uniform float s_dm = 0.0;
uniform float d_r = 1.0;
uniform float d_g = 1.0;
uniform float d_b = 1.0;

uniform float t_c = 0.0;
uniform float w = 1.0;
uniform float h = 1.0;
uniform int idx = 0;

uniform float noise_smooth_amp = 0.0;
uniform float noise_rough_amp = 0.0;
uniform float zoom = 1.0;

void fragment() {
    float t = TIME + t_time;
    float fx = (UV.x - 0.5) / zoom + 0.5;
    float fy = (UV.y - 0.5) / zoom + 0.5;
    
    float R = 0.0, G = 0.0, B = 0.0;

""" + logic + """

    vec4 tex_color = texture(TEXTURE, UV);
    COLOR = vec4(R, G, B, tex_color.a);
}
"""

with open('plasma.gdshader', 'w') as f:
    f.write(gdshader)

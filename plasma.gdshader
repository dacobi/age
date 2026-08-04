shader_type canvas_item;

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

if (idx == 0) {
        if (t_c > 0.0f) {
            float cur_rel = w / h;
            fy = floor(fy * t_c) / t_c;
            fx = floor(fx * (t_c * cur_rel)) / (t_c * cur_rel);
        }
        float dx = d_amp * sin(t * d_sx);
        float dy = d_amp * cos(t * d_sy);
        float rs = sin(t * r_s), rc = cos(t * r_s);
        float jitter = sin(fx * 140.0 + t * 15.0) * cos(fy * 240.0 - t * 10.0) * 0.02;
        float cx = (fx + jitter) - 0.5;
        float cy = (fy + jitter) - 0.5;
        float rx = cx * rc - cy * rs + 0.5 + dx;
        float ry = cx * rs + cy * rc + 0.5 + dy;
        float dist = sqrt(cx * cx + cy * cy);
        float warp_str = w_b + w_a * sin(t * w_s);
        float swirl_angle = dist * s_dm * warp_str;
        float sw_sin = sin(swirl_angle), sw_cos = cos(swirl_angle);
        float wx = (rx - 0.5) * sw_cos - (ry - 0.5) * sw_sin + 0.5;
        float wy = (rx - 0.5) * sw_sin + (ry - 0.5) * sw_cos + 0.5;
        float scale_x = s_bx + s_ma * sin(t * s_msx);
        float scale_y = s_by + s_ma * cos(t * s_msy);
        float v = (sin(wx * scale_x + t) + sin(wy * scale_y - t * 0.5) + 
                   sin((wx + wy) * (scale_x * 0.5) + t) + 
                   sin(sqrt(wx * wx + wy * wy) * 10.0 + t)) * 0.25;
        R = (0.5 + 0.5 * cos(6.28318 * (v + p_r))) * d_r;
        G = (0.5 + 0.5 * cos(6.28318 * (v + p_g))) * d_g;
        B = (0.5 + 0.5 * cos(6.28318 * (v + p_b))) * d_b;
    } else if (idx == 1) {
        if (t_c > 0.0f) {
            float cur_rel = w / h;
            fy = floor(fy * t_c) / t_c;
            fx = floor(fx * (t_c * cur_rel)) / (t_c * cur_rel);
        }
        float drift_x  = d_amp * sin(t * d_sx);
        float drift_y  = d_amp * cos(t * d_sy);
        float scale_x  = s_bx + s_ma * sin(t * s_msx);
        float scale_y  = s_by + s_ma * cos(t * s_msy);
        float rot_sin  = sin(t * r_s);
        float rot_cos  = cos(t * r_s);
        float warp_str = w_b + w_a * sin(t * w_s);
        float jitter = sin(fx * 200.0) * cos(fy * 200.0) * 0.01;
        float curve_x = sin(fy * 10.0 + t) * 0.05;
        float curve_y = cos(fx * 10.0 + t) * 0.05;
        float warped_fx = fx + curve_x + jitter;
        float warped_fy = fy + curve_y + jitter;
        float cx = warped_fx - 0.5;
        float cy = warped_fy - 0.5;
        float rx = cx * rot_cos - cy * rot_sin + 0.5 + drift_x * 0.1;
        float ry = cx * rot_sin + cy * rot_cos + 0.5 + drift_y * 0.1;
        float dist = sqrt(cx * cx + cy * cy);
        float swirl_angle = dist * s_dm * warp_str;
        float sw_sin = sin(swirl_angle);
        float sw_cos = cos(swirl_angle);
        float wx = (rx - 0.5) * sw_cos - (ry - 0.5) * sw_sin + 0.5;
        float wy = (rx - 0.5) * sw_sin + (ry - 0.5) * sw_cos + 0.5;
        float v = 0.0;
        v += sin(wx * scale_x + t);
        v += sin((wy * scale_y + t) * 0.7);
        v += sin((wx * scale_x + wy * scale_y + t) * 0.5);
        v += sin(sqrt(wx * wx * 100.0 + wy * wy * 100.0) + t);
        v *= 0.25;
        float num_bands = 6.0;
        v = floor(v * num_bands) / num_bands;
        R = (0.5 + 0.5 * cos(3.14159 * (v + p_r))) * d_r;
        G = (0.5 + 0.5 * cos(3.14159 * (v + p_g))) * d_g;
        B = (0.5 + 0.5 * cos(3.14159 * (v + p_b))) * d_b;
    } else if (idx == 2) {
        float jitter = sin(fx * 120.0 + t * 10.0) * 0.02;
        float wx = fx + jitter;
        float wy = fy + jitter;
        float v1 = 1.0 - abs(sin(wx * s_bx + t));
        float v2 = 1.0 - abs(sin(wy * s_by - t));
        float v = (v1 + v2) * 0.5;
        float electric_v = v * v * v;
        R = (0.5 + 0.5 * cos(3.14159 * (electric_v + p_r))) * d_r;
        G = (0.5 + 0.5 * cos(3.14159 * (electric_v + p_g))) * d_g;
        B = (0.5 + 0.5 * cos(3.14159 * (electric_v + p_b))) * d_b;
    } else if (idx == 3) {
        float sX = (s_bx == 0.0) ? 10.0 : s_bx;
        float sY = (s_by == 0.0) ? 10.0 : s_by;
        float jitter = sin(fx * 40.0 + fy * 40.0 + t * 3.0) * 0.01;
        float wx = fx + jitter;
        float wy = fy + jitter;
        float v = 0.0;
        v += 1.0 - abs(sin(wx * sX + t));
        v += 1.0 - abs(sin(wy * sY - t));
        v += 1.0 - abs(sin((wx + wy) * (sX * 0.5) + t * 0.5));
        v /= 3.0;
        v = (v > 0.5) ? (v - 0.5) * 2.0 : 0.0;
        R = (0.5 + 0.5 * cos(3.14159 * (v + p_r))) * v * d_r;
        G = (0.5 + 0.5 * cos(3.14159 * (v + p_g))) * v * d_g;
        B = (0.5 + 0.5 * cos(3.14159 * (v + p_b))) * v * d_b;
    } else if (idx == 4) {
        float drift_x  = d_amp * sin(t * d_sx);
        float drift_y  = d_amp * cos(t * d_sy);
        float s_x      = s_bx + s_ma * sin(t * s_msx);
        float s_y      = s_by + s_ma * cos(t * s_msy);
        float rot_sin  = sin(t * r_s);
        float rot_cos  = cos(t * r_s);
        float cx = fx - 0.5;
        float cy = fy - 0.5;
        float rx = cx * rot_cos - cy * rot_sin + 0.5 + drift_x;
        float ry = cx * rot_sin + cy * rot_cos + 0.5 + drift_y;
        float warp_noise = sin(rx * 15.0 + t) * cos(ry * 15.0 - t);
        float wx = rx + warp_noise * 0.05;
        float wy = ry + warp_noise * 0.05;
        float v = 0.0;
        v += 1.0 - abs(sin(wx * s_x + t));
        v += 1.0 - abs(sin(wy * s_y * 1.2 - t * 0.8));
        v += 1.0 - abs(sin((wx + wy) * s_x * 0.5 + t));
        float dist = sqrt((wx-0.5)*(wx-0.5) + (wy-0.5)*(wy-0.5));
        v += 1.0 - abs(sin(dist * 20.0 - t * 2.0));
        v /= 4.0;
        v = pow(v, 6.8);        
        R = clamp((0.5 + 0.5 * cos(3.14159 * (v + p_r))) * v * d_r, 0.0, 1.0);
        G = clamp((0.5 + 0.5 * cos(3.14159 * (v + p_g))) * v * d_g, 0.0, 1.0);
        B = clamp((0.5 + 0.5 * cos(3.14159 * (v + p_b))) * v * d_b, 0.0, 1.0);
        float brightness_boost = 1.4; // Boosts global intensity

        R = clamp((0.6 + 0.4 * cos(3.14159 * (v + p_r))) * v * d_r * brightness_boost, 0.0, 1.0);
        G = clamp((0.6 + 0.4 * cos(3.14159 * (v + p_g))) * v * d_g * brightness_boost, 0.0, 1.0);
        B = clamp((0.6 + 0.4 * cos(3.14159 * (v + p_b))) * v * d_b * brightness_boost, 0.0, 1.0);
    } else if (idx == 5) {
        float jitter = sin(fx * 150.0 + t * 20.0) * 0.012;
        float wx = fx + jitter;
        float wy = fy + jitter;
        float v1 = 1.0 - abs(sin(wx * s_bx + t));
        float v2 = 1.0 - abs(sin(wy * s_by - t * 1.3));
        float v3 = 1.0 - abs(sin((wx + wy) * (s_bx * 0.4) + t));
        float v = (v1 + v2 + v3) / 3.0;
        float electric_v = max(0.0, v - 0.4) * 1.8;
        R = (0.5 + 0.5 * cos(3.14159 * (electric_v + p_r))) * electric_v * d_r;
        G = (0.5 + 0.5 * cos(3.14159 * (electric_v + p_g))) * electric_v * d_g;
        B = (0.5 + 0.5 * cos(3.14159 * (electric_v + p_b))) * electric_v * d_b;
    } else if (idx == 6) {
        float drift_x  = d_amp * sin(t * d_sx);
        float drift_y  = d_amp * cos(t * d_sy);
        float rot_sin  = sin(t * r_s);
        float rot_cos  = cos(t * r_s);
        float cx = fx - 0.5;
        float cy = fy - 0.5;
        float rx = cx * rot_cos - cy * rot_sin + 0.5 + drift_x;
        float ry = cx * rot_sin + cy * rot_cos + 0.5 + drift_y;
        float jitter = sin(rx * 50.0 + t * 2.0) * 0.02;
        float wx = rx + jitter;
        float wy = ry + jitter;
        float v1 = 1.0 - abs(sin(wx * s_bx + t));
        float v2 = 1.0 - abs(sin(wy * s_by - t * 0.5));
        float v3 = 1.0 - abs(sin((wx + wy) * (s_bx * 0.5) + t));
        float v = (v1 + v2 + v3) / 3.0;
        v = max(0.0, v - 0.4) * 1.6;
        R = min(1.0, (0.5 + 0.5 * cos(3.14159 * (v + p_r))) * v * d_r);
        G = min(1.0, (0.5 + 0.5 * cos(3.14159 * (v + p_g))) * v * d_g);
        B = min(1.0, (0.5 + 0.5 * cos(3.14159 * (v + p_b))) * v * d_b);
    } else if (idx == 7) {
        float drift_x = d_amp * sin(t * d_sx);
        float drift_y = d_amp * cos(t * d_sy);
        float rot_sin = sin(t * r_s);
        float rot_cos = cos(t * r_s);
        float cx = fx - 0.5;
        float cy = fy - 0.5;
        float rx = cx * rot_cos - cy * rot_sin + 0.5 + drift_x;
        float ry = cx * rot_sin + cy * rot_cos + 0.5 + drift_y;
        float buzz = sin(rx * 130.0 + t * 15.0) * cos(ry * 210.0 - t * 10.0);
        float wx = rx + buzz * 0.015;
        float wy = ry + buzz * 0.015;
        float v1 = 1.0 - abs(sin(wx * s_bx + t));
        float v2 = 1.0 - abs(sin(wy * s_by - t * 0.5));
        float v3 = 1.0 - abs(sin((wx + wy) * (s_bx * 0.5) + t));
        float v = (v1 + v2 + v3) / 3.0;
        float electric_v = max(0.0, v - 0.5) * 2.0;
        electric_v *= electric_v;
        R = min(1.0, (0.5 + 0.5 * cos(3.14159 * (electric_v + p_r))) * electric_v * d_r);
        G = min(1.0, (0.5 + 0.5 * cos(3.14159 * (electric_v + p_g))) * electric_v * d_g);
        B = min(1.0, (0.5 + 0.5 * cos(3.14159 * (electric_v + p_b))) * electric_v * d_b);
    } else if (idx == 8) {
        float jitter = sin(fx * 140.0 + t * 15.0) * cos(fy * 240.0 - t * 10.0) * 0.02;
        float cx = (fx + jitter) - 0.5;
        float cy = (fy + jitter) - 0.5;
        float drift_x = d_amp * sin(t * d_sx);
        float drift_y = d_amp * cos(t * d_sy);
        float rot_sin = sin(t * r_s);
        float rot_cos = cos(t * r_s);
        float rx = cx * rot_cos - cy * rot_sin + 0.5 + drift_x;
        float ry = cx * rot_sin + cy * rot_cos + 0.5 + drift_y;
        float v = 0.0;
        v += sin(rx * s_bx + t);
        v += sin(ry * s_by - t * 0.5);
        v += sin((rx + ry) * (s_bx * 0.5) + t);
        v += sin(sqrt(rx * rx + ry * ry) * 10.0 + t);
        v *= 0.25;
        R = (0.5 + 0.5 * cos(6.28318 * d_r * (v + p_r)));
        G = (0.5 + 0.5 * cos(6.28318 * d_g * (v + p_g)));
        B = (0.5 + 0.5 * cos(6.28318 * d_b * (v + p_b)));
    } else if (idx == 9) {
        float drift_x = d_amp * sin(t * d_sx);
        float drift_y = d_amp * cos(t * d_sy);
        float rot_sin = sin(t * r_s);
        float rot_cos = cos(t * r_s);
        float cx = fx - 0.5;
        float cy = fy - 0.5;
        float rx = cx * rot_cos - cy * rot_sin + 0.5 + drift_x;
        float ry = cx * rot_sin + cy * rot_cos + 0.5 + drift_y;
        
        // Zoom in by reducing the scale multipliers
        float sX = ((s_bx == 0.0) ? 10.0 : s_bx) * 0.3;
        float sY = ((s_by == 0.0) ? 10.0 : s_by) * 0.3;
        
        // Generate pseudo-random noise to create jagged edges
        float noise = fract(sin(dot(vec2(fx, fy), vec2(12.9898, 78.233))) * 43758.5453);
        
        float v = 0.0;
        // Slow down time multipliers and add noise to the phase
        v += sin(rx * sX + t * 0.5 + noise * noise_rough_amp);
        v += sin(ry * sY - t * 0.4 + noise * noise_rough_amp);
        v += sin(sqrt((rx - 0.5) * (rx - 0.5) + (ry - 0.5) * (ry - 0.5)) * sX * 2.0 - t * 0.7 + noise * noise_rough_amp);
        v += sin(sqrt(rx * rx + ry * ry) * sY * 1.5 + t * 0.6 + noise * noise_rough_amp);
        v /= 4.0;
        
        R = (0.5 + 0.5 * sin(3.14159 * v * 3.0 + p_r * 6.28318)) * d_r;
        G = (0.5 + 0.5 * sin(3.14159 * v * 3.0 + p_g * 6.28318)) * d_g;
        B = (0.5 + 0.5 * sin(3.14159 * v * 3.0 + p_b * 6.28318)) * d_b;
    } else if (idx == 10) {
        float drift_x = d_amp * sin(t * d_sx);
        float drift_y = d_amp * cos(t * d_sy);
        float rot_sin = sin(t * r_s);
        float rot_cos = cos(t * r_s);
        float cx = fx - 0.5;
        float cy = fy - 0.5;
        float rx = cx * rot_cos - cy * rot_sin + 0.5 + drift_x;
        float ry = cx * rot_sin + cy * rot_cos + 0.5 + drift_y;
        
        // Zoom in by reducing the scale multipliers
        float sX = ((s_bx == 0.0) ? 10.0 : s_bx) * 0.3;
        float sY = ((s_by == 0.0) ? 10.0 : s_by) * 0.3;
        
        // Generate pseudo-random noise that moves with the plasma coordinate space
        float noise = fract(sin(dot(vec2(rx, ry), vec2(12.9898, 78.233))) * 43758.5453);
        
        float v = 0.0;
        // Slow down time multipliers and add noise to the phase
        v += sin(rx * sX + t * 0.5 + noise * noise_rough_amp);
        v += sin(ry * sY - t * 0.4 + noise * noise_rough_amp);
        v += sin(sqrt((rx - 0.5) * (rx - 0.5) + (ry - 0.5) * (ry - 0.5)) * sX * 2.0 - t * 0.7 + noise * noise_rough_amp);
        v += sin(sqrt(rx * rx + ry * ry) * sY * 1.5 + t * 0.6 + noise * noise_rough_amp);
        v /= 4.0;
        
        R = (0.5 + 0.5 * sin(3.14159 * v * 3.0 + p_r * 6.28318)) * d_r;
        G = (0.5 + 0.5 * sin(3.14159 * v * 3.0 + p_g * 6.28318)) * d_g;
        B = (0.5 + 0.5 * sin(3.14159 * v * 3.0 + p_b * 6.28318)) * d_b;
    } else if (idx == 11) {
        float drift_x = d_amp * sin(t * d_sx);
        float drift_y = d_amp * cos(t * d_sy);
        float rot_sin = sin(t * r_s);
        float rot_cos = cos(t * r_s);
        float cx = fx - 0.5;
        float cy = fy - 0.5;
        float rx = cx * rot_cos - cy * rot_sin + 0.5 + drift_x;
        float ry = cx * rot_sin + cy * rot_cos + 0.5 + drift_y;
        
        float sX = ((s_bx == 0.0) ? 10.0 : s_bx) * 0.3;
        float sY = ((s_by == 0.0) ? 10.0 : s_by) * 0.3;
        
        // Generate smooth, undulating noise (not pixelated)
        float smooth_noise = sin(rx * 40.0 + t * 2.0) * cos(ry * 40.0 - t * 1.5);
        smooth_noise += sin(rx * 80.0 - t * 3.0) * cos(ry * 80.0 + t * 2.5) * 0.5;
        
        float v = 0.0;
        // Add the smooth noise to the phase of the main waveforms
        v += sin(rx * sX + t * 0.5 + smooth_noise * noise_smooth_amp);
        v += sin(ry * sY - t * 0.4 + smooth_noise * noise_smooth_amp);
        v += sin(sqrt((rx - 0.5) * (rx - 0.5) + (ry - 0.5) * (ry - 0.5)) * sX * 2.0 - t * 0.7 + smooth_noise * noise_smooth_amp);
        v += sin(sqrt(rx * rx + ry * ry) * sY * 1.5 + t * 0.6 + smooth_noise * noise_smooth_amp);
        v /= 4.0;
        
        R = (0.5 + 0.5 * sin(3.14159 * v * 3.0 + p_r * 6.28318)) * d_r;
        G = (0.5 + 0.5 * sin(3.14159 * v * 3.0 + p_g * 6.28318)) * d_g;
        B = (0.5 + 0.5 * sin(3.14159 * v * 3.0 + p_b * 6.28318)) * d_b;
    } else if (idx == 12) {
        float drift_x = d_amp * sin(t * d_sx);
        float drift_y = d_amp * cos(t * d_sy);
        float rot_sin = sin(t * r_s);
        float rot_cos = cos(t * r_s);
        float cx = fx - 0.5;
        float cy = fy - 0.5;
        float rx = cx * rot_cos - cy * rot_sin + 0.5 + drift_x;
        float ry = cx * rot_sin + cy * rot_cos + 0.5 + drift_y;
        
        float sX = ((s_bx == 0.0) ? 10.0 : s_bx) * 0.3;
        float sY = ((s_by == 0.0) ? 10.0 : s_by) * 0.3;
        
        // Combine smooth, undulating noise with a little bit of high-frequency pixelated noise
        float smooth_noise = sin(rx * 40.0 + t * 2.0) * cos(ry * 40.0 - t * 1.5);
        smooth_noise += sin(rx * 80.0 - t * 3.0) * cos(ry * 80.0 + t * 2.5) * 0.5;
        
        float pixel_noise = fract(sin(dot(vec2(rx, ry), vec2(12.9898, 78.233))) * 43758.5453);
        
        float combined_noise = smooth_noise * noise_smooth_amp + pixel_noise * noise_rough_amp;
        
        float v = 0.0;
        // Add the combined noise to the phase of the main waveforms
        v += sin(rx * sX + t * 0.5 + combined_noise);
        v += sin(ry * sY - t * 0.4 + combined_noise);
        v += sin(sqrt((rx - 0.5) * (rx - 0.5) + (ry - 0.5) * (ry - 0.5)) * sX * 2.0 - t * 0.7 + combined_noise);
        v += sin(sqrt(rx * rx + ry * ry) * sY * 1.5 + t * 0.6 + combined_noise);
        v /= 4.0;
        
        R = (0.5 + 0.5 * sin(3.14159 * v * 3.0 + p_r * 6.28318)) * d_r;
        G = (0.5 + 0.5 * sin(3.14159 * v * 3.0 + p_g * 6.28318)) * d_g;
        B = (0.5 + 0.5 * sin(3.14159 * v * 3.0 + p_b * 6.28318)) * d_b;
    } else if (idx == 13) {
        float drift_x = d_amp * sin(t * d_sx);
        float drift_y = d_amp * cos(t * d_sy);
        float rot_sin = sin(t * r_s);
        float rot_cos = cos(t * r_s);
        float cx = fx - 0.5;
        float cy = fy - 0.5;
        float rx = cx * rot_cos - cy * rot_sin + 0.5 + drift_x;
        float ry = cx * rot_sin + cy * rot_cos + 0.5 + drift_y;
        
        float dist = sqrt((rx - 0.5) * (rx - 0.5) + (ry - 0.5) * (ry - 0.5));
        float warp_str = w_b + w_a * sin(t * w_s);
        float swirl_angle = dist * s_dm * warp_str;
        float sw_sin = sin(swirl_angle);
        float sw_cos = cos(swirl_angle);
        float wx = (rx - 0.5) * sw_cos - (ry - 0.5) * sw_sin + 0.5;
        float wy = (rx - 0.5) * sw_sin + (ry - 0.5) * sw_cos + 0.5;
        
        float sX = ((s_bx == 0.0) ? 10.0 : s_bx) * 0.3;
        float sY = ((s_by == 0.0) ? 10.0 : s_by) * 0.3;
        
        float smooth_noise = sin(wx * 40.0 + t * 2.0) * cos(wy * 40.0 - t * 1.5);
        smooth_noise += sin(wx * 80.0 - t * 3.0) * cos(wy * 80.0 + t * 2.5) * 0.5;
        float pixel_noise = fract(sin(dot(vec2(wx, wy), vec2(12.9898, 78.233))) * 43758.5453);
        float combined_noise = smooth_noise * noise_smooth_amp + pixel_noise * noise_rough_amp;
        
        float v = 0.0;
        v += sin(wx * sX + t * 0.5 + combined_noise);
        v += sin(wy * sY - t * 0.4 + combined_noise);
        v += sin(sqrt((wx - 0.5) * (wx - 0.5) + (wy - 0.5) * (wy - 0.5)) * sX * 2.0 - t * 0.7 + combined_noise);
        v += sin(sqrt(wx * wx + wy * wy) * sY * 1.5 + t * 0.6 + combined_noise);
        v /= 4.0;
        
        R = (0.5 + 0.5 * sin(3.14159 * v * 3.0 + p_r * 6.28318)) * d_r;
        G = (0.5 + 0.5 * sin(3.14159 * v * 3.0 + p_g * 6.28318)) * d_g;
        B = (0.5 + 0.5 * sin(3.14159 * v * 3.0 + p_b * 6.28318)) * d_b;
    }



    vec4 tex_color = texture(TEXTURE, UV);
    COLOR = vec4(R, G, B, tex_color.a);
}

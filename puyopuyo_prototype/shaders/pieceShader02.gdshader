shader_type canvas_item;

// === BASIC SHAPE ===
uniform float orb_radius : hint_range(0.01, 0.5) = 0.45;
uniform float edge_softness : hint_range(0.0, 0.25) = 0.02;

// === ANTI-ALIASING ===
uniform float aa_strength : hint_range(0.5, 4.0) = 0.75; // Higher = smoother edges
uniform bool adaptive_detail = true; // Reduce detail at small sizes

// === SHAPE VARIATION ===
uniform float shape_noise_scale : hint_range(0.1, 20.0) = 5.0;
uniform float shape_noise_strength : hint_range(0.0, 0.3) = 0.08;
uniform float shape_noise_octaves : hint_range(1, 6) = 3;
uniform float shape_seed : hint_range(0.0, 1000.0) = 42.0;

// === SPHERE WARPING ===
uniform float sphere_strength : hint_range(-5.0, 5.0) = -1.25;

// === SURFACE DETAIL ===
uniform float surface_scale : hint_range(0.5, 20.0) = 8.0;
uniform float surface_strength : hint_range(0.0, 1.0) = 0.4;
uniform float surface_octaves : hint_range(1, 6) = 4;
uniform float surface_seed : hint_range(0.0, 1000.0) = 123.0;

// === BASE COLOR ===
uniform vec3 base_color : source_color = vec3(0.3, 0.3, 0.35);
uniform vec3 dark_color : source_color = vec3(0.15, 0.15, 0.2);
uniform float color_variation : hint_range(0.0, 1.0) = 0.3;

// === LIGHTING SYSTEM ===
uniform vec2 light_direction = vec2(-0.3, 0.3);
uniform float light_intensity : hint_range(0.0, 3.0) = 1.2;
uniform vec3 light_color : source_color = vec3(1.0, 0.98, 0.95);

uniform float ambient_light : hint_range(0.0, 2.0) = 0.25;
uniform vec3 ambient_color : source_color = vec3(0.4, 0.5, 0.7);

uniform vec3 shadow_tint : source_color = vec3(0.3, 0.4, 0.6);
uniform float shadow_tint_strength : hint_range(0.0, 1.0) = 0.3;

// === RIM LIGHTING ===
uniform float rim_light_intensity : hint_range(0.0, 5.0) = 1.5;
uniform vec3 rim_light_color : source_color = vec3(0.6, 0.7, 1.0);
uniform float rim_light_falloff : hint_range(0.5, 10.0) = 2.5;
uniform float rim_light_width : hint_range(0.0, 1.0) = 0.3;

// === SPECULAR HIGHLIGHT ===
uniform float specular_intensity : hint_range(0.0, 2.0) = 0.3;
uniform float specular_shininess : hint_range(1.0, 128.0) = 32.0;

// === EYE SYSTEM ===
uniform bool eyes_enabled = true;

uniform vec2 eye_center_offset = vec2(0.0, -0.05);
uniform float eye_spacing : hint_range(0.0, 0.3) = 0.12;
uniform float eye_vertical_pos : hint_range(-0.3, 0.3) = 0.05;

uniform float eye_size : hint_range(0.1, 3) = 1;
uniform float eye_width : hint_range(0.5, 2.0) = 1.0;
uniform float eye_height : hint_range(0.5, 2.0) = 1.1;
uniform float eye_rotation : hint_range(-45.0, 45.0) = 0.0;
uniform float eye_roundness : hint_range(0.0, 1.0) = 0.8;

uniform vec3 eye_white_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 eye_outline_color : source_color = vec3(0.0, 0.0, 0.0);
uniform float eye_outline_width : hint_range(0.0, 0.05) = 0.01;

uniform float pupil_size : hint_range(0.1, 1.0) = 0.4;
uniform float pupil_width : hint_range(0.5, 2.0) = 1.0;
uniform float pupil_height : hint_range(0.5, 2.0) = 1.0;
uniform vec3 pupil_color : source_color = vec3(0.0, 0.0, 0.0);
uniform vec2 pupil_offset = vec2(0.0, 0.0);
uniform float pupil_max_offset : hint_range(0.0, 0.5) = 0.3;

uniform int pupil_shape : hint_range(0, 3) = 0;
uniform float pupil_slit_width : hint_range(0.1, 0.8) = 0.3;

uniform bool eye_highlight_enabled = true;
uniform vec3 eye_highlight_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float eye_highlight_size : hint_range(0.1, 0.5) = 0.25;
uniform vec2 eye_highlight_offset = vec2(-0.2, -0.2);
uniform float eye_highlight_softness : hint_range(0.0, 0.5) = 0.1;

uniform bool eye_highlight2_enabled = true;
uniform float eye_highlight2_size : hint_range(0.05, 0.3) = 0.12;
uniform vec2 eye_highlight2_offset = vec2(0.15, 0.15);

// === HELPER FUNCTIONS ===

// Anti-aliased smoothstep
float aastep(float threshold, float value) {
    float afwidth = length(vec2(dFdx(value), dFdy(value))) * aa_strength;
    return smoothstep(threshold - afwidth, threshold + afwidth, value);
}

// Anti-aliased smoothstep with range
float aasmoothstep(float edge0, float edge1, float x) {
    float afwidth = length(vec2(dFdx(x), dFdy(x))) * aa_strength;
    return smoothstep(edge0 - afwidth, edge1 + afwidth, x);
}

// Calculate adaptive octaves based on screen-space derivatives
float get_adaptive_octaves(float base_octaves, vec2 uv) {
    if (!adaptive_detail) {
        return base_octaves;
    }
    
    // Calculate how much detail we can actually see
    vec2 uv_ddx = dFdx(uv);
    vec2 uv_ddy = dFdy(uv);
    float pixel_size = max(length(uv_ddx), length(uv_ddy));
    
    // Reduce octaves when pixels are large (zoomed out)
    float detail_scale = clamp(1.0 / (pixel_size * 100.0), 0.5, 1.0);
    
    return max(2.0, base_octaves * detail_scale);
}

// === NOISE FUNCTIONS ===
vec2 hash22(vec2 p, float seed) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    p += seed;
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float improved_noise(vec2 p, float seed) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    
    vec2 ga = hash22(i + vec2(0.0, 0.0), seed);
    vec2 gb = hash22(i + vec2(1.0, 0.0), seed);
    vec2 gc = hash22(i + vec2(0.0, 1.0), seed);
    vec2 gd = hash22(i + vec2(1.0, 1.0), seed);
    
    float va = dot(ga, f - vec2(0.0, 0.0));
    float vb = dot(gb, f - vec2(1.0, 0.0));
    float vc = dot(gc, f - vec2(0.0, 1.0));
    float vd = dot(gd, f - vec2(1.0, 1.0));
    
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    
    return mix(mix(va, vb, u.x), mix(vc, vd, u.x), u.y);
}

float smooth_noise(vec2 p, float seed) {
    return improved_noise(p, seed) * 0.5 + 0.5;
}

float fractal_noise(vec2 p, float octaves, float persistence, float seed) {
    float value = 0.0;
    float amplitude = 1.0;
    float frequency = 1.0;
    float max_value = 0.0;
    
    for (int i = 0; i < int(octaves); i++) {
        value += smooth_noise(p * frequency, seed) * amplitude;
        max_value += amplitude;
        amplitude *= persistence;
        frequency *= 2.0;
        seed += 100.0;
    }
    
    return value / max_value;
}

// === SPHERE WARPING ===
vec2 sphere_warp(vec2 uv, float strength, float radius) {
    float dist = length(uv);
    
    if (dist > radius) {
        return uv;
    }
    
    float z = sqrt(max(0.0, radius * radius - dist * dist));
    float scale_factor = mix(1.0, z / radius, strength);
    
    return uv * scale_factor;
}

vec2 rotate_point(vec2 p, float angle_deg) {
    float angle = radians(angle_deg);
    float s = sin(angle);
    float c = cos(angle);
    return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

// === SURFACE NORMAL CALCULATION ===
vec3 calculate_surface_normal(vec2 original_uv, float radius) {
    float dist = length(original_uv);
    
    if (dist > radius) {
        return vec3(0.0, 0.0, 1.0);
    }
    
    float z = sqrt(max(0.0, radius * radius - dist * dist));
    vec3 sphere_pos = vec3(original_uv.x, original_uv.y, z);
    
    return normalize(sphere_pos);
}

// === LIGHTING CALCULATION ===
float calculate_diffuse_lighting(vec3 surface_normal, vec2 light_dir, float intensity) {
    vec3 light_direction_3d = normalize(vec3(light_dir.x, light_dir.y, 0.5));
    float diffuse = max(dot(surface_normal, light_direction_3d), 0.0);
    return diffuse * intensity;
}

float calculate_specular(vec3 surface_normal, vec2 light_dir, float shininess) {
    vec3 light_direction_3d = normalize(vec3(light_dir.x, light_dir.y, 0.5));
    vec3 view_direction = vec3(0.0, 0.0, 1.0);
    
    vec3 half_vector = normalize(light_direction_3d + view_direction);
    float spec = pow(max(dot(surface_normal, half_vector), 0.0), shininess);
    
    return spec;
}

float calculate_shadow_factor(vec3 surface_normal, vec2 light_dir) {
    vec3 light_direction_3d = normalize(vec3(light_dir.x, light_dir.y, 0.5));
    float shadow_factor = 1.0 - max(dot(surface_normal, light_direction_3d), 0.0);
    shadow_factor = aasmoothstep(0.3, 0.8, shadow_factor);
    
    return shadow_factor;
}

// === RIM LIGHTING ===
float calculate_rim_light(vec3 surface_normal, vec2 light_dir, float falloff, float width) {
    vec3 light_direction_3d = normalize(vec3(light_dir.x, light_dir.y, 0.5));
    vec3 view_direction = vec3(0.0, 0.0, 1.0);
    
    float rim_factor = 1.0 - abs(dot(surface_normal, view_direction));
    float light_dot = dot(surface_normal, light_direction_3d);
    
    float light_bias = aasmoothstep(-1.0, 1.0, light_dot);
    light_bias = pow(light_bias, 2.0);
    
    rim_factor = pow(rim_factor, falloff);
    rim_factor *= aasmoothstep(1.0 - width, 1.0, rim_factor);
    rim_factor *= light_bias;
    
    return rim_factor;
}

// === EYE DRAWING FUNCTIONS ===

float ellipse_distance(vec2 p, vec2 size, float roundness) {
    vec2 scaled_p = p / size;
    float circle_dist = length(scaled_p);
    float box_dist = max(abs(scaled_p.x), abs(scaled_p.y));
    
    return mix(box_dist, circle_dist, roundness);
}

float draw_pupil(vec2 local_uv, vec2 pupil_pos, float size, int shape, float slit_width) {
    vec2 p = local_uv - pupil_pos;
    float mask = 0.0;
    
    if (shape == 0) {
        // Circle pupil - anti-aliased
        vec2 pupil_scale = vec2(pupil_width, pupil_height);
        float dist = ellipse_distance(p, pupil_scale * vec2(size), 1.0);
        mask = 1.0 - aasmoothstep(size * 0.9, size, dist);
    } else if (shape == 1) {
        // Vertical slit pupil - anti-aliased
        float slit_w = size * slit_width;
        float slit_h = size * pupil_height;
        mask = 1.0 - aastep(slit_w, abs(p.x));
        mask *= 1.0 - aastep(slit_h, abs(p.y));
    } else if (shape == 2) {
        // Horizontal slit pupil - anti-aliased
        float slit_w = size * slit_width;
        float slit_h = size * pupil_width;
        mask = 1.0 - aastep(slit_w, abs(p.y));
        mask *= 1.0 - aastep(slit_h, abs(p.x));
    } else if (shape == 3) {
        // Star pupil (4-pointed) - anti-aliased
        float angle = atan(p.y, p.x);
        float radius = length(p);
        float star_radius = size * (0.6 + 0.4 * abs(sin(angle * 2.0)));
        mask = 1.0 - aasmoothstep(star_radius * 0.9, star_radius, radius);
    }
    
    return clamp(mask, 0.0, 1.0);
}

vec4 draw_eye(vec2 local_uv, vec2 eye_pos, float size, vec2 look_dir) {
    vec2 p = local_uv - eye_pos;
    p = rotate_point(p, eye_rotation);
    
    vec2 eye_scale = vec2(eye_width, eye_height);
    float eye_dist = ellipse_distance(p, eye_scale * vec2(size), eye_roundness);
    
    // Anti-aliased eye outline and white
    float eye_outline = aasmoothstep(size, size + eye_outline_width, eye_dist);
    eye_outline *= 1.0 - aastep(size + eye_outline_width, eye_dist);
    
    float eye_white = 1.0 - aasmoothstep(size * 0.95, size, eye_dist);
    
    // Calculate pupil position
    vec2 clamped_look = look_dir * pupil_max_offset;
    float look_dist = length(clamped_look);
    if (look_dist > pupil_max_offset) {
        clamped_look = normalize(clamped_look) * pupil_max_offset;
    }
    
    vec2 pupil_pos = clamped_look;
    float pupil_base_size = size * pupil_size;
    
    float pupil_mask = draw_pupil(p, pupil_pos, pupil_base_size, pupil_shape, pupil_slit_width);
    
    // Highlights - anti-aliased
    float highlight1 = 0.0;
    float highlight2 = 0.0;
    
    if (eye_highlight_enabled) {
        vec2 hl1_pos = eye_highlight_offset * size;
        float hl1_size = eye_highlight_size * size;
        float hl_dist = length(p - hl1_pos);
        highlight1 = 1.0 - aasmoothstep(hl1_size - eye_highlight_softness, 
                                        hl1_size, 
                                        hl_dist);
        highlight1 *= eye_white;
    }
    
    if (eye_highlight2_enabled) {
        vec2 hl2_pos = eye_highlight2_offset * size;
        float hl2_size = eye_highlight2_size * size;
        float hl_dist = length(p - hl2_pos);
        highlight2 = 1.0 - aasmoothstep(hl2_size * 0.8, hl2_size, hl_dist);
        highlight2 *= eye_white;
    }
    
    // Combine eye layers
    vec3 eye_color = eye_white_color * eye_white;
    eye_color = mix(eye_color, eye_outline_color, eye_outline);
    eye_color = mix(eye_color, pupil_color, pupil_mask);
    eye_color = mix(eye_color, eye_highlight_color, highlight1 * 0.9);
    eye_color = mix(eye_color, eye_highlight_color, highlight2 * 0.7);
    
    float eye_alpha = max(eye_white, max(eye_outline, pupil_mask));
    eye_alpha = max(eye_alpha, max(highlight1, highlight2));
    
    return vec4(eye_color, eye_alpha);
}

// === MAIN FRAGMENT SHADER ===
void fragment() {
    vec2 original_uv = UV - 0.5;
    float original_distance = length(original_uv);
    
    // Get adaptive octaves for noise
    float shape_octaves_adaptive = get_adaptive_octaves(shape_noise_octaves, original_uv);
    float surface_octaves_adaptive = get_adaptive_octaves(surface_octaves, original_uv);
    
    // === SHAPE VARIATION ===
    float shape_noise = fractal_noise(original_uv * shape_noise_scale, 
                                     shape_octaves_adaptive, 
                                     0.5, 
                                     shape_seed);
    
    float varied_radius = orb_radius + (shape_noise - 0.5) * shape_noise_strength;
    
    vec2 warped_uv = sphere_warp(original_uv, sphere_strength, varied_radius);
    
    // Anti-aliased orb mask
    float orb_mask = 1.0 - aasmoothstep(varied_radius - edge_softness, 
                                        varied_radius, 
                                        original_distance);
    
    float hard_mask = aastep(varied_radius, original_distance);
    hard_mask = 1.0 - hard_mask;
    
    // === SURFACE TEXTURE ===
    float surface_detail = fractal_noise(warped_uv * surface_scale, 
                                        surface_octaves_adaptive, 
                                        0.6, 
                                        surface_seed);
    
    vec3 surface_color = mix(dark_color, base_color, 
                            surface_detail * surface_strength + (1.0 - surface_strength));
    
    float variation_noise = fractal_noise(warped_uv * surface_scale * 0.5, 
                                         3.0, 
                                         0.5, 
                                         surface_seed + 50.0);
    surface_color = mix(surface_color, base_color * 1.2, 
                       variation_noise * color_variation);
    
    // === LIGHTING ===
    vec3 surface_normal = calculate_surface_normal(original_uv, varied_radius);
    
    float diffuse = calculate_diffuse_lighting(surface_normal, 
                                               light_direction, 
                                               light_intensity);
    
    float specular = calculate_specular(surface_normal, 
                                       light_direction, 
                                       specular_shininess);
    
    float shadow_factor = calculate_shadow_factor(surface_normal, light_direction);
    
    vec3 diffuse_contribution = surface_color * light_color * diffuse;
    vec3 ambient_contribution = surface_color * ambient_color * ambient_light;
    vec3 specular_contribution = light_color * specular * specular_intensity;
    
    vec3 lit_color = diffuse_contribution + ambient_contribution + specular_contribution;
    
    lit_color = mix(lit_color, lit_color * shadow_tint, 
                   shadow_factor * shadow_tint_strength);
    
    // === RIM LIGHTING ===
    float rim = calculate_rim_light(surface_normal, 
                                    light_direction, 
                                    rim_light_falloff, 
                                    rim_light_width);
    
    vec3 rim_contribution = rim_light_color * rim * rim_light_intensity;
    
    vec3 base_final = lit_color + rim_contribution;
    base_final *= hard_mask;
    
    // === DRAW EYES ===
    vec4 final_result = vec4(base_final, orb_mask);
    
    if (eyes_enabled && hard_mask > 0.5) {
        vec2 eye_base = eye_center_offset + vec2(0.0, eye_vertical_pos);
        vec2 left_eye_pos = eye_base + vec2(-eye_spacing, 0.0);
        vec2 right_eye_pos = eye_base + vec2(eye_spacing, 0.0);
        
        vec4 left_eye = draw_eye(original_uv, left_eye_pos, eye_size, pupil_offset);
        vec4 right_eye = draw_eye(original_uv, right_eye_pos, eye_size, pupil_offset);
        
        vec4 combined_eyes = vec4(
            max(left_eye.rgb, right_eye.rgb),
            max(left_eye.a, right_eye.a)
        );
        
        final_result.rgb = mix(final_result.rgb, combined_eyes.rgb, combined_eyes.a);
        final_result.a = max(final_result.a, combined_eyes.a);
    }
    
    COLOR = final_result;
}
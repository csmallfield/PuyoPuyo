shader_type canvas_item;

// === BASIC SHAPE ===
uniform float orb_radius : hint_range(0.01, 0.5) = 0.45;
uniform float edge_softness : hint_range(0.0, 0.25) = 0.02;

// === SHAPE VARIATION ===
// Make the orb irregular like a rocky asteroid
uniform float shape_noise_scale : hint_range(0.1, 20.0) = 5.0;
uniform float shape_noise_strength : hint_range(0.0, 0.3) = 0.08;
uniform float shape_noise_octaves : hint_range(1, 6) = 3;
uniform float shape_seed : hint_range(0.0, 1000.0) = 42.0;

// === SPHERE WARPING ===
// Spherical distortion to simulate 3D curvature
uniform float sphere_strength : hint_range(-5.0, 5.0) = -1.25;

// === SURFACE DETAIL ===
// Rocky surface texture
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

// Ambient lighting
uniform float ambient_light : hint_range(0.0, 2.0) = 0.25;
uniform vec3 ambient_color : source_color = vec3(0.4, 0.5, 0.7);

// Shadow tinting
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
    shadow_factor = smoothstep(0.3, 0.8, shadow_factor);
    
    return shadow_factor;
}

// === RIM LIGHTING ===
float calculate_rim_light(vec3 surface_normal, vec2 light_dir, float falloff, float width) {
    vec3 light_direction_3d = normalize(vec3(light_dir.x, light_dir.y, 0.5));
    vec3 view_direction = vec3(0.0, 0.0, 1.0);
    
    float rim_factor = 1.0 - abs(dot(surface_normal, view_direction));
    float light_dot = dot(surface_normal, light_direction_3d);
    
    float light_bias = smoothstep(-1.0, 1.0, light_dot);
    light_bias = pow(light_bias, 2.0);
    
    rim_factor = pow(rim_factor, falloff);
    rim_factor *= smoothstep(1.0 - width, 1.0, rim_factor);
    rim_factor *= light_bias;
    
    return rim_factor;
}

// === MAIN FRAGMENT SHADER ===
void fragment() {
    // Center UV coordinates
    vec2 original_uv = UV - 0.5;
    float original_distance = length(original_uv);
    
    // === SHAPE VARIATION ===
    // Add irregular shape to the orb using noise
    float shape_noise = fractal_noise(original_uv * shape_noise_scale, 
                                     shape_noise_octaves, 
                                     0.5, 
                                     shape_seed);
    
    // Vary the radius based on noise
    float varied_radius = orb_radius + (shape_noise - 0.5) * shape_noise_strength;
    
    // Apply sphere warping
    vec2 warped_uv = sphere_warp(original_uv, sphere_strength, varied_radius);
    
    // Create orb mask with soft edges
    float orb_mask = 1.0 - smoothstep(varied_radius - edge_softness, 
                                     varied_radius, 
                                     original_distance);
    
    // Hard mask for surface details
    float hard_mask = step(original_distance, varied_radius);
    
    // === SURFACE TEXTURE ===
    // Generate rocky surface detail
    float surface_detail = fractal_noise(warped_uv * surface_scale, 
                                        surface_octaves, 
                                        0.6, 
                                        surface_seed);
    
    // Apply surface detail to color
    vec3 surface_color = mix(dark_color, base_color, 
                            surface_detail * surface_strength + (1.0 - surface_strength));
    
    // Add color variation
    float variation_noise = fractal_noise(warped_uv * surface_scale * 0.5, 
                                         3.0, 
                                         0.5, 
                                         surface_seed + 50.0);
    surface_color = mix(surface_color, base_color * 1.2, 
                       variation_noise * color_variation);
    
    // === LIGHTING ===
    // Calculate surface normal
    vec3 surface_normal = calculate_surface_normal(original_uv, varied_radius);
    
    // Diffuse lighting
    float diffuse = calculate_diffuse_lighting(surface_normal, 
                                               light_direction, 
                                               light_intensity);
    
    // Specular highlight
    float specular = calculate_specular(surface_normal, 
                                       light_direction, 
                                       specular_shininess);
    
    // Shadow factor for tinting
    float shadow_factor = calculate_shadow_factor(surface_normal, light_direction);
    
    // Combine lighting
    vec3 diffuse_contribution = surface_color * light_color * diffuse;
    vec3 ambient_contribution = surface_color * ambient_color * ambient_light;
    vec3 specular_contribution = light_color * specular * specular_intensity;
    
    vec3 lit_color = diffuse_contribution + ambient_contribution + specular_contribution;
    
    // Apply shadow tinting
    lit_color = mix(lit_color, lit_color * shadow_tint, 
                   shadow_factor * shadow_tint_strength);
    
    // === RIM LIGHTING ===
    float rim = calculate_rim_light(surface_normal, 
                                    light_direction, 
                                    rim_light_falloff, 
                                    rim_light_width);
    
    vec3 rim_contribution = rim_light_color * rim * rim_light_intensity;
    
    // Combine all lighting
    vec3 final_color = lit_color + rim_contribution;
    
    // Apply masks
    final_color *= hard_mask;
    
    // Output with alpha
    COLOR = vec4(final_color, orb_mask);
}
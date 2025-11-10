shader_type canvas_item;

// Resolution scaling
uniform float resolution_scale : hint_range(0.25, 1.0) = 0.5;

// Base Shape Controls
uniform float base_scale : hint_range(0.5, 8.0) = 3.0;
uniform float base_density : hint_range(0.0, 1.0) = 0.6;
uniform float base_softness : hint_range(0.0, 3.0) = 0.5;
uniform float base_octaves : hint_range(1.0, 6.0) = 6.0;
uniform float base_lacunarity : hint_range(0.1, 10.0) = 2.75;
uniform float base_gain : hint_range(0.1, 0.9) = 0.5;

// Internal Structure Controls
uniform float structure_scale : hint_range(0.5, 20.0) = 10.0;
uniform float structure_strength : hint_range(0.0, 2.0) = 0.75;
uniform float structure_contrast : hint_range(0.1, 10.0) = 1.25;
uniform float structure_octaves : hint_range(1.0, 6.0) = 3.0;
uniform float structure_lacunarity : hint_range(0.1, 10.0) = 2.0;
uniform float structure_gain : hint_range(0.1, 0.9) = 0.5;

// Wispy Details
uniform float wispy_scale : hint_range(0.0, 50.0) = 8.0;
uniform float wispy_strength : hint_range(0.0, 2.0) = 0.5;
uniform float wispy_octaves : hint_range(1.0, 6.0) = 6.0;
uniform float wispy_lacunarity : hint_range(0.1, 10.0) = 2.0;
uniform float wispy_gain : hint_range(0.1, 0.9) = 0.5;

// Edge Controls
uniform float edge_falloff : hint_range(0.1, 10.0) = 1.5;
uniform float edge_irregularity : hint_range(0.0, 10.0) = 4.0;
uniform float hard_edge_mix : hint_range(0.0, 1.0) = 0.0;

// Colors for different layers
uniform vec4 nebula_base_color : source_color = vec4(0.1, 0.2, 0.6, 1.0);
uniform vec4 structure_color : source_color = vec4(0.8, 0.3, 0.5, 1.0);
uniform vec4 wispy_color : source_color = vec4(0.3, 0.5, 0.9, 1.0);
uniform vec4 edge_color : source_color = vec4(0.2, 0.5, 0.8, 1.0);

// Color Blending
uniform float color_blend_smoothness : hint_range(0.1, 5.0) = 1.0;
uniform float overall_brightness : hint_range(0.0, 5.0) = 1.0;

// Basic noise function
vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(mix(dot(hash2(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
                   dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
               mix(dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
                   dot(hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x), u.y);
}

// Enhanced FBM with configurable parameters
float fbm_configurable(vec2 uv, float scale_mult, float oct, float lac, float g) {
    float value = 0.0;
    float amplitude = 0.5;
    vec2 p = uv * scale_mult;

    int max_octaves = int(oct);
    for (int i = 0; i < max_octaves; i++) {
        value += amplitude * noise(p);
        amplitude *= g;
        p *= lac;
    }

    return value * 0.5 + 0.5;
}

// Base nebula shape - irregular cloud
float get_base_shape(vec2 uv) {
    float base = fbm_configurable(uv, base_scale, base_octaves, base_lacunarity, base_gain);

    // Make it more cloud-like with soft threshold
    float shape = smoothstep(base_density - base_softness, base_density + base_softness, base);

    // Add some overall falloff from center
    vec2 center = uv - vec2(0.5);
    float dist_falloff = 1.0 - smoothstep(0.2, 0.8, length(center) * edge_falloff);

    return shape * dist_falloff;
}

// Internal structure - creates visible density variations
float get_internal_structure(vec2 uv) {
    float structure = fbm_configurable(uv + vec2(100.0, 50.0), structure_scale,
                                      structure_octaves, structure_lacunarity, structure_gain);

    // Apply contrast to make structure more visible
    structure = pow(structure, 1.0 / structure_contrast);

    return structure * structure_strength;
}

// Wispy details - fine tendrils and filaments
float get_wispy_details(vec2 uv) {
    float wispy = fbm_configurable(uv + vec2(200.0, 300.0), wispy_scale,
                                  wispy_octaves, wispy_lacunarity, wispy_gain);

    // Make wispy features more thread-like
    wispy = abs(wispy - 0.5) * 2.0;
    wispy = 1.0 - wispy;
    wispy = pow(wispy, 3.0);

    return wispy * wispy_strength;
}

// Edge irregularity
float get_edge_variation(vec2 uv) {
    if (edge_irregularity <= 0.0) return 1.0;

    float edge_noise = fbm_configurable(uv + vec2(400.0, 500.0), base_scale * 2.0, 3.0, 2.0, 0.5);
    edge_noise = (edge_noise - 0.5) * edge_irregularity + 1.0;

    return clamp(edge_noise, 0.0, 2.0);
}

// Color mixing based on noise layers
vec3 mix_nebula_colors(float base, float structure, float wispy, float edge_var) {
    vec3 color = nebula_base_color.rgb;

    float structure_mix = smoothstep(0.3, 0.7, structure) * color_blend_smoothness;
    color = mix(color, structure_color.rgb, structure_mix);

    float wispy_mix = smoothstep(0.4, 0.8, wispy) * color_blend_smoothness;
    color = mix(color, wispy_color.rgb, wispy_mix);

    float edge_mix = (1.0 - edge_var) * 0.3 * color_blend_smoothness;
    color = mix(color, edge_color.rgb, edge_mix);

    return color;
}

void fragment() {
    // Scale UV coordinates to effectively lower resolution
    vec2 uv = floor(UV * resolution_scale * 2048.0) / (resolution_scale * 2048.0);

    // Generate nebula
    float base_shape = get_base_shape(uv);
    float structure = get_internal_structure(uv);
    float wispy = get_wispy_details(uv);
    float edge_var = get_edge_variation(uv);

    float combined_density = base_shape + (structure * base_shape) + (wispy * base_shape);
    combined_density = clamp(combined_density, 0.0, 1.0);
    combined_density *= edge_var;

    float soft_alpha = combined_density;
    float hard_alpha = step(0.1, combined_density);
    float final_alpha = mix(soft_alpha, hard_alpha, hard_edge_mix);

    vec3 final_color = mix_nebula_colors(base_shape, structure, wispy, edge_var);

    // Apply brightness
    final_color *= overall_brightness * final_alpha;

    COLOR = vec4(final_color, final_alpha);
}
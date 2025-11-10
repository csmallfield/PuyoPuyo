// IMPROVED STARFIELD SHADER - Responsive density control
shader_type canvas_item;

uniform float star_density : hint_range(0.0001, 0.5) = 0.002;
uniform float star_brightness : hint_range(0.0, 2.0) = 1.0;
uniform float star_size : hint_range(0.1, 20.0) = 2.0;
uniform float twinkle_speed : hint_range(0.0, 2.0) = 0.5;
uniform vec2 world_offset = vec2(0.0, 0.0);
uniform float tile_size : hint_range(50.0, 500.0) = 200.0;

// Better hash function for more random distribution
float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.78));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y * 789.12);
}

// Multi-octave hash for better distribution
float hash21_multi(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    // Simple UV-based positioning - let ParallaxLayers handle movement
    vec2 world_pos = UV;

    // Create variable grid size based on density
    // Higher density = smaller grid cells = more potential star locations
    float grid_scale = mix(10.0, 200.0, sqrt(star_density * 1.0));
    vec2 grid_pos = floor(world_pos * grid_scale);
    vec2 cell_uv = fract(world_pos * grid_scale);

    float star_alpha = 0.0;

    // Check for star in current cell
    float star_chance = hash21_multi(grid_pos);

    // Much more direct density control
    // star_density of 0.001 = very sparse, 0.1 = very dense
    float density_threshold = star_density * 5.0;

    if (star_chance < density_threshold) {
        // Random position within cell
        vec2 star_local_pos = vec2(
            hash21(grid_pos + vec2(13.7, 27.1)),
            hash21(grid_pos + vec2(41.3, 67.9))
        );

        // Distance from current pixel to star center
        float dist = length(cell_uv - star_local_pos);

        // Adaptive star size based on grid scale
        float base_radius = star_size / grid_scale;

        if (dist < base_radius) {
            // Sharp star with soft edges
            float intensity = 1.0 - smoothstep(0.0, base_radius, dist);
            intensity = pow(intensity, 2.0);

            // Add twinkling if enabled
            if (twinkle_speed > 0.0) {
                float twinkle_seed = hash21(grid_pos + vec2(99.9, 11.1));
                float twinkle = sin(TIME * twinkle_speed + twinkle_seed * 6.28318) * 0.3 + 0.7;
                intensity *= twinkle;
            }

            star_alpha = intensity * star_brightness;
        }
    }

    COLOR = vec4(1.0, 1.0, 1.0, star_alpha);
}
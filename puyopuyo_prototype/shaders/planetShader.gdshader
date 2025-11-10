shader_type canvas_item;

// === PLANET PARAMETERS ===
// Basic shape and size
uniform float planet_radius : hint_range(0.01, 0.5) = 0.45;
uniform float edge_softness : hint_range(0.0, 0.25) = 0.0;

// === UV CONTROLS ===
// UV offset for planetary rotation/positioning
uniform float uv_offset_x : hint_range(-2.0, 2.0) = 0.0;
uniform float uv_offset_y : hint_range(-2.0, 2.0) = 0.0;

// === NOISE SEEDS ===
// Separate seeds for different noise systems
uniform float continent_seed : hint_range(0.0, 1000.0) = 42.0;
uniform float terrain_seed : hint_range(0.0, 1000.0) = 123.0;
uniform float river_seed : hint_range(0.0, 1000.0) = 456.0;
uniform float detail_seed : hint_range(0.0, 1000.0) = 789.0;
uniform float cloud_seed : hint_range(0.0, 1000.0) = 999.0;

// === OUTPUT CONTROL ===
// Choose what to output: 0=Color, 1=Specular, 2=Normal Map
uniform int output_mode : hint_range(0, 2) = 0;

// Normal map intensity control
uniform float normal_map_intensity : hint_range(0.0, 2.0) = 0.1;

// === SPHERE WARPING ===
// Spherical distortion to simulate 3D curvature
uniform float sphere_strength : hint_range(-5.0, 5.0) = -1.25;

// === LIGHTING SYSTEM ===
// Primary light direction and properties
uniform vec2 light_direction = vec2(0.3, 0.3);
uniform float light_intensity : hint_range(0.0, 5.0) = 1;
uniform vec3 light_color : source_color = vec3(1.0, 0.95, 0.8);

// Shadow color tinting
uniform vec3 shadow_tint : source_color = vec3(0.5, 0.6, 0.8);
uniform float shadow_tint_strength : hint_range(0.0, 1.0) = 0.2;

// Ambient lighting
uniform float ambient_light : hint_range(0, 3) = 0.3;
uniform vec3 ambient_color : source_color = vec3(0.4, 0.6, 1.0);

// Enhanced rim lighting for atmospheric edge glow
uniform float rim_light_intensity : hint_range(0.0, 10.0) = 0.0;
uniform vec3 rim_light_color : source_color = vec3(0.8, 0.9, 1.0);
uniform float rim_light_falloff : hint_range(0.0, 10) = 2.0;
uniform float rim_light_crescent_power : hint_range(0.1, 20.0) = 3.0;
uniform float rim_light_crescent_offset : hint_range(-1.0, 1.0) = 0.2;
uniform float rim_light_glow_intensity : hint_range(0.0, 10.0) = 1.0;
uniform float rim_light_glow_radius : hint_range(0.0, 1) = 0.1;
uniform bool rim_light_glow_enabled = false;

// === CONTINENTAL SYSTEM ===
// Continental generation
uniform float continent_scale : hint_range(0.1, 50) = 3;
uniform float continent_threshold : hint_range(0.0, 0.8) = 0.5;
uniform float continent_sharpness : hint_range(0.1, 1.0) = 0.25;
uniform float continent_octaves : hint_range(1, 8) = 3;
uniform float continent_persistence : hint_range(0.1, 1.0) = 0.6;
uniform float ocean_depth : hint_range(0.0, 1) = 0.4;

// Domain warping for realistic coastlines
uniform float warp_strength : hint_range(-5.0, 5.0) = 0.15;
uniform float warp_scale : hint_range(-20, 20) = 5;

// === TERRAIN SYSTEM ===
// Primary terrain noise (large features)
uniform float terrain_scale : hint_range(0.1, 50.0) = 5.0;
uniform float terrain_strength : hint_range(0.0, 3.0) = 0.75;
uniform float terrain_octaves : hint_range(1, 20) = 3;
uniform float terrain_persistence : hint_range(0.1, 20) = 0.5;
uniform float terrain_softness : hint_range(0.01, 0.5) = 0.1;

// Secondary detail noise (fine features)
uniform float detail_scale : hint_range(2.0, 20.0) = 8.0;
uniform float detail_strength : hint_range(0.0, 0.5) = 0.2;
uniform float detail_octaves : hint_range(1, 25) = 2;

// Terrain height thresholds for better mountain visibility
uniform float mountain_threshold : hint_range(0.3, 0.9) = 0.7;
uniform float highland_threshold : hint_range(0.1, 0.7) = 0.4;

// === CLOUD/ATMOSPHERE LAYER ===
// Cloud generation
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.4;
uniform float cloud_scale : hint_range(0.5, 20.0) = 4.0;
uniform float cloud_stretch_x : hint_range(0.1, 5.0) = 1.0;
uniform float cloud_stretch_y : hint_range(0.1, 5.0) = 1.0;
uniform float cloud_octaves : hint_range(1, 20) = 3;
uniform float cloud_persistence : hint_range(0.1, 1.0) = 0.5;
uniform float cloud_density : hint_range(0.0, 2.0) = 0.8;
uniform float cloud_sharpness : hint_range(0.01, 0.5) = 0.1;

// Cloud appearance
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shadow_color : source_color = vec3(0.7, 0.7, 0.8);
uniform float cloud_opacity : hint_range(0.0, 1.0) = 0.7;
uniform float cloud_shadow_strength : hint_range(0.0, 1.0) = 0.3;

// Cloud animation offset (for rotation)
uniform float cloud_offset_x : hint_range(-2.0, 2.0) = 0.0;
uniform float cloud_offset_y : hint_range(-2.0, 2.0) = 0.0;

// === GEOGRAPHIC FEATURES ===
// River system
uniform float river_scale : hint_range(0.1, 15.0) = 0.5;
uniform float river_strength : hint_range(0.0, 3) = 0.05;
uniform float river_width : hint_range(0.01, 2) = 0.05;
uniform float river_octaves : hint_range(1, 20) = 2;
uniform float river_persistence : hint_range(0.1, 1.0) = 0.5;

// River glow system
uniform bool river_glow_enabled = false;
uniform float river_glow_intensity : hint_range(0.0, 5.0) = 1.0;
uniform float river_glow_radius : hint_range(0.0, 0.1) = 0.02;
uniform vec3 river_glow_color : source_color = vec3(0.4, 0.8, 1.0);

// Polar ice caps
uniform float ice_cap_size : hint_range(0.0, 0.4) = 0.05;
uniform float ice_cap_softness : hint_range(0.01, 1) = 0.05;

// Desert zones
uniform float desert_latitude : hint_range(0.1, 0.8) = 0.4;
uniform float desert_width : hint_range(0, 3) = 0.15;
uniform float desert_intensity : hint_range(0.0, 5) = 0.7;

// === MATERIAL COLORS ===
// Ocean and water
uniform vec3 deep_ocean_color : source_color = vec3(0.1, 0.2, 0.4);
uniform vec3 shallow_water_color : source_color = vec3(0.2, 0.4, 0.6);
uniform vec3 river_color : source_color = vec3(0.3, 0.5, 0.7);

// Land biomes
uniform vec3 mountain_color : source_color = vec3(0.5, 0.4, 0.3);
uniform vec3 highland_color : source_color = vec3(0.3, 0.5, 0.2);
uniform vec3 lowland_color : source_color = vec3(0.2, 0.6, 0.3);
uniform vec3 desert_color : source_color = vec3(0.8, 0.6, 0.3);
uniform vec3 ice_color : source_color = vec3(0.9, 0.95, 1.0);

// Coastal transitions
uniform float coastal_blend : hint_range(0.01, 0.1) = 0.03;
uniform vec3 beach_color : source_color = vec3(0.7, 0.6, 0.4);

// === PLANETARY GRADIENT ===
// Core color system
uniform vec3 core_color : source_color = vec3(1.0, 0.8, 0.3);
uniform float core_size : hint_range(0.0, 5) = 0.5;

// Additional color variation
uniform float color_variation : hint_range(0.0, 10) = 0.2;
uniform vec3 variation_tint : source_color = vec3(0.2, 0.5, 0.8);

// === NOISE FUNCTIONS ===
// Hash function for better random distribution with seed support
vec2 hash22_seeded(vec2 p, float seed) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    p += seed;
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

// Improved noise function using gradients with seed
float improved_noise_seeded(vec2 p, float seed) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    
    // Get gradient vectors for each corner with seed
    vec2 ga = hash22_seeded(i + vec2(0.0, 0.0), seed);
    vec2 gb = hash22_seeded(i + vec2(1.0, 0.0), seed);
    vec2 gc = hash22_seeded(i + vec2(0.0, 1.0), seed);
    vec2 gd = hash22_seeded(i + vec2(1.0, 1.0), seed);
    
    // Calculate dot products with distance vectors
    float va = dot(ga, f - vec2(0.0, 0.0));
    float vb = dot(gb, f - vec2(1.0, 0.0));
    float vc = dot(gc, f - vec2(0.0, 1.0));
    float vd = dot(gd, f - vec2(1.0, 1.0));
    
    // Smooth interpolation (quintic for better results)
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    
    // Bilinear interpolation
    return mix(mix(va, vb, u.x), mix(vc, vd, u.x), u.y);
}

// Smooth noise interpolation using the improved noise with seed
float smooth_noise_seeded(vec2 p, float seed) {
    return improved_noise_seeded(p, seed) * 0.5 + 0.5; // Remap from [-1,1] to [0,1]
}

// Fractal noise with multiple octaves and seed
float fractal_noise_seeded(vec2 p, float octaves, float persistence, float seed) {
    float value = 0.0;
    float amplitude = 1.0;
    float frequency = 1.0;
    float max_value = 0.0;
    
    for (int i = 0; i < int(octaves); i++) {
        value += smooth_noise_seeded(p * frequency, seed) * amplitude;
        max_value += amplitude;
        amplitude *= persistence;
        frequency *= 2.0;
        seed += 100.0; // Offset seed for each octave
    }
    
    return value / max_value;
}

// Domain warping function for realistic coastlines with seed
vec2 domain_warp_seeded(vec2 p, float strength, float scale, float seed) {
    float warp_x = fractal_noise_seeded(p * scale, 3.0, 0.5, seed);
    float warp_y = fractal_noise_seeded(p * scale + vec2(100.0, 100.0), 3.0, 0.5, seed + 50.0);
    return p + vec2(warp_x, warp_y) * strength;
}

// Flow noise for river generation with seed and octaves
float flow_noise_seeded(vec2 p, float scale, float seed, float octaves, float persistence) {
    // Create flow field using multiple noise octaves
    vec2 flow_p = p * scale;
    
    // Generate multi-octave noise for more detailed rivers
    float n1 = fractal_noise_seeded(flow_p, octaves, persistence, seed);
    float n2 = fractal_noise_seeded(flow_p + vec2(100.0, 50.0), octaves, persistence, seed + 25.0);
    
    // Create ridged noise for river valleys
    float ridge = abs(n1 - 0.5) * 2.0;
    ridge = 1.0 - ridge;
    ridge = pow(ridge, 3.0); // Sharpen the ridges
    
    return ridge;
}

// Proper sphere warping function
vec2 sphere_warp(vec2 uv, float strength) {
    // Calculate distance from center
    float dist = length(uv);
    
    // Only apply warping within the planet radius
    if (dist > planet_radius) {
        return uv;
    }
    
    // Calculate the Z coordinate on the sphere
    float z = sqrt(max(0.0, planet_radius * planet_radius - dist * dist));
    
    // Project back to 2D with perspective scaling
    float scale_factor = mix(1.0, z / planet_radius, strength);
    
    return uv * scale_factor;
}

// Calculate cloud coverage
float calculate_clouds(vec2 uv, vec2 original_uv) {
    // Apply cloud offset for independent rotation
    vec2 cloud_uv = uv + vec2(cloud_offset_x, cloud_offset_y);
    
    // Apply cloud stretching
    cloud_uv.x *= cloud_stretch_x;
    cloud_uv.y *= cloud_stretch_y;
    
    // Generate base cloud noise
    float cloud_noise = fractal_noise_seeded(cloud_uv * cloud_scale, cloud_octaves, cloud_persistence, cloud_seed);
    
    // Apply coverage threshold with smooth transition
    float cloud_mask = smoothstep(1.0 - cloud_coverage - cloud_sharpness, 
                                 1.0 - cloud_coverage + cloud_sharpness, 
                                 cloud_noise);
    
    // Apply density multiplication
    cloud_mask *= cloud_density;
    
    // Fade clouds near planet edges
    float edge_distance = length(original_uv) / planet_radius;
    float edge_fade = 1.0 - smoothstep(0.8, 1.0, edge_distance);
    cloud_mask *= edge_fade;
    
    return clamp(cloud_mask, 0.0, 1.0);
}

// Calculate surface normal for lighting
vec3 calculate_surface_normal(vec2 uv, vec2 original_uv) {
    // For sphere lighting, we calculate the normal based on the spherical surface
    float dist = length(original_uv);
    
    // If outside planet radius, return flat normal
    if (dist > planet_radius) {
        return vec3(0.0, 0.0, 1.0);
    }
    
    // Calculate the 3D position on sphere surface
    float z = sqrt(max(0.0, planet_radius * planet_radius - dist * dist));
    
    // The normal of a sphere at any point is the normalized position vector
    vec3 sphere_pos = vec3(original_uv.x, original_uv.y, z);
    vec3 normal = normalize(sphere_pos);
    
    return normal;
}

// Calculate lighting based on surface normal and light direction
float calculate_lighting(vec3 surface_normal, vec2 light_dir) {
    // Convert 2D light direction to 3D (assuming light comes from in front)
    vec3 light_direction_3d = normalize(vec3(light_dir.x, light_dir.y, 0.5));
    
    // Calculate diffuse lighting (Lambertian)
    float diffuse = max(dot(surface_normal, light_direction_3d), 0.0);
    
    // Combine with ambient lighting
    float final_lighting = ambient_light + diffuse * light_intensity;
    
    // Clamp to reasonable range
    return clamp(final_lighting, 0.0, 2.0);
}

// Calculate shadow areas for tinting
float calculate_shadow_factor(vec3 surface_normal, vec2 light_dir) {
    // Convert 2D light direction to 3D
    vec3 light_direction_3d = normalize(vec3(light_dir.x, light_dir.y, 0.5));
    
    // Calculate how much the surface faces away from light (shadow factor)
    float shadow_factor = 1.0 - max(dot(surface_normal, light_direction_3d), 0.0);
    shadow_factor = smoothstep(0.3, 0.8, shadow_factor); // Smooth shadow transition
    
    return shadow_factor;
}

// Enhanced rim lighting calculation with crescent shaping
float calculate_rim_light(vec3 surface_normal, vec2 original_uv, vec2 light_dir) {
    // Convert 2D light direction to 3D
    vec3 light_direction_3d = normalize(vec3(light_dir.x, light_dir.y, 0.5));
    
    // Calculate view direction (looking straight down at planet)
    vec3 view_direction = vec3(0.0, 0.0, 1.0);
    
    // Calculate rim factor based on surface normal vs view direction
    float rim_factor = 1.0 - abs(dot(surface_normal, view_direction));
    
    // Calculate how much the surface faces the light for crescent shaping
    float light_dot = dot(surface_normal, light_direction_3d);
    
    // Create crescent shape by biasing towards lit side with offset
    float crescent_bias = smoothstep(-1.0, 1.0, light_dot + rim_light_crescent_offset);
    crescent_bias = pow(crescent_bias, rim_light_crescent_power);
    
    // Apply falloff curve to the rim effect
    rim_factor = pow(rim_factor, rim_light_falloff);
    
    // Combine rim factor with crescent bias for sharp crescent shape
    rim_factor *= crescent_bias;
    
    // NO edge fade - let rim light go to the very edge
    return rim_factor * rim_light_intensity;
}

// Calculate extended rim light that goes beyond planet boundary
float calculate_extended_rim_light(vec2 original_uv, vec2 light_dir) {
    // Calculate distance from planet center
    float edge_distance = length(original_uv) / planet_radius;
    
    // Work in the transition zone from inside planet to outside
    if (edge_distance < 0.95) {
        return 0.0;
    }
    
    // Calculate the rim effect for extended areas
    vec2 edge_direction = normalize(original_uv);
    
    // Calculate what the surface normal would be at the planet edge
    float z = sqrt(max(0.0, planet_radius * planet_radius - planet_radius * planet_radius * 0.96));
    vec3 edge_normal = normalize(vec3(edge_direction * planet_radius, z));
    
    // Calculate rim lighting at the edge
    vec3 light_direction_3d = normalize(vec3(light_dir.x, light_dir.y, 0.5));
    vec3 view_direction = vec3(0.0, 0.0, 1.0);
    
    float rim_factor = 1.0 - abs(dot(edge_normal, view_direction));
    rim_factor = pow(rim_factor, rim_light_falloff);
    
    // Calculate crescent bias
    float light_dot = dot(edge_normal, light_direction_3d);
    float crescent_bias = smoothstep(-1.0, 1.0, light_dot + rim_light_crescent_offset);
    crescent_bias = pow(crescent_bias, rim_light_crescent_power);
    
    // Combine factors
    float edge_rim = rim_factor * crescent_bias * rim_light_intensity;
    
    // Create smooth blend from planet edge to extended rim
    float blend_start = 0.95;
    float blend_end = 1.02;
    
    if (edge_distance < 1.0) {
        // Inside planet: fade in the extended rim toward the edge
        float inside_fade = smoothstep(blend_start, 1.0, edge_distance);
        edge_rim *= inside_fade * 0.5; // Reduce intensity inside
    } else {
        // Outside planet: fade out from edge
        float outside_fade = 1.0 - smoothstep(1.0, blend_end, edge_distance);
        outside_fade = pow(outside_fade, 1.2);
        edge_rim *= outside_fade;
    }
    
    return edge_rim;
}

// Calculate rim light glow effect extending beyond planet boundary
float calculate_rim_glow(vec2 original_uv, vec2 light_dir) {
    if (!rim_light_glow_enabled) {
        return 0.0;
    }
    
    // Calculate distance from planet center
    float edge_distance = length(original_uv) / planet_radius;
    
    // Only create glow outside the planet boundary
    if (edge_distance <= 1.0) {
        return 0.0;
    }
    
    // Calculate how far outside the planet we are
    float glow_distance = edge_distance - 1.0;
    
    if (glow_distance > rim_light_glow_radius) {
        return 0.0;
    }
    
    // Create smooth glow falloff from planet edge
    float glow_factor = 1.0 - smoothstep(0.0, rim_light_glow_radius, glow_distance);
    glow_factor = pow(glow_factor, 2.0); // Square for sharper falloff
    
    // Calculate the 3D surface normal at the planet edge for this direction
    vec2 edge_direction = normalize(original_uv);
    vec2 edge_point = edge_direction * planet_radius;
    
    // Calculate the sphere surface normal at the edge point
    float z = sqrt(max(0.0, planet_radius * planet_radius - planet_radius * planet_radius * 0.99));
    vec3 edge_normal = normalize(vec3(edge_point.x, edge_point.y, z));
    
    // Calculate rim lighting at the edge for crescent shaping
    vec3 light_direction_3d = normalize(vec3(light_dir.x, light_dir.y, 0.5));
    vec3 view_direction = vec3(0.0, 0.0, 1.0);
    
    // Calculate rim factor at edge
    float edge_rim_factor = 1.0 - abs(dot(edge_normal, view_direction));
    edge_rim_factor = pow(edge_rim_factor, rim_light_falloff);
    
    // Calculate crescent bias at edge
    float light_dot = dot(edge_normal, light_direction_3d);
    float crescent_bias = smoothstep(-1.0, 1.0, light_dot + rim_light_crescent_offset);
    crescent_bias = pow(crescent_bias, rim_light_crescent_power);
    
    // Combine rim and crescent factors
    float edge_intensity = edge_rim_factor * crescent_bias;
    
    // Apply the edge intensity to the glow
    glow_factor *= edge_intensity * rim_light_glow_intensity;
    
    return glow_factor;
}

// Calculate river glow effect
float calculate_river_glow(vec2 warped_uv, float continent_mask, float river_mask, vec2 uv_position, float planet_mask) {
    if (!river_glow_enabled || continent_mask < 0.5 || river_glow_radius <= 0.0 || planet_mask <= 0.0) {
        return 0.0;
    }
    
    // If there's already a river here, include it in the glow
    float glow_intensity = river_mask;
    
    // Sample nearby positions to find additional rivers for glow expansion
    float sample_step = river_glow_radius * 0.5;
    
    // Check a few key positions around this pixel
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            if (x == 0 && y == 0) continue; // Skip center (current position)
            
            vec2 offset = vec2(float(x), float(y)) * sample_step;
            vec2 sample_uv = warped_uv + offset;
            
            // Calculate river at this sample position
            float sample_river_noise = flow_noise_seeded(sample_uv, river_scale, river_seed, river_octaves, river_persistence);
            float sample_river_mask = smoothstep(1.0 - river_width, 1.0, sample_river_noise);
            
            // Apply continent mask
            vec2 sample_warped_uv = domain_warp_seeded(uv_position + offset, warp_strength, warp_scale, continent_seed);
            float sample_continent_noise = fractal_noise_seeded(sample_warped_uv * continent_scale, continent_octaves, continent_persistence, continent_seed);
            float sample_continent_mask = smoothstep(continent_threshold - continent_sharpness, 
                                                   continent_threshold + continent_sharpness, 
                                                   sample_continent_noise);
            
            sample_river_mask *= sample_continent_mask;
            sample_river_mask *= step(0.5, sample_continent_mask);
            sample_river_mask *= river_strength;
            
            // If we found a river, calculate glow contribution
            if (sample_river_mask > 0.0) {
                float distance = length(offset);
                float falloff = 1.0 - smoothstep(0.0, river_glow_radius, distance);
                falloff = pow(falloff, 1.5);
                
                float glow_contribution = sample_river_mask * falloff;
                glow_intensity = max(glow_intensity, glow_contribution);
            }
        }
    }
    
    // Scale by glow intensity and ensure it stays within planet bounds
    return glow_intensity * river_glow_intensity * planet_mask;
}

// Calculate specular map based on material types
float calculate_specular(float continent_mask, float river_mask, float ice_cap_mask) {
    float specular = 0.0;
    
    if (continent_mask > 0.5) {
        // LAND AREAS - low specularity
        specular = 0.1;
        
        // ICE - medium specularity
        specular = mix(specular, 0.4, ice_cap_mask);
        
        // RIVERS - high specularity (same as water) since they're water features
        specular = mix(specular, 0.9, river_mask);
    } else {
        // OCEAN AREAS - high specularity
        specular = 0.9;
        
        // SEA ICE - medium specularity
        specular = mix(specular, 0.4, ice_cap_mask * 0.7);
    }
    
    return specular;
}

// Calculate normal map from height data
vec3 calculate_normal_map(vec2 uv, vec2 original_uv, float continent_mask, float land_terrain) {
    // Sample height at neighboring points for gradient calculation
    float offset = 0.01;
    
    // Sample terrain heights at neighboring points
    vec2 warped_uv_right = domain_warp_seeded(uv + vec2(offset, 0.0), warp_strength, warp_scale, continent_seed);
    vec2 warped_uv_up = domain_warp_seeded(uv + vec2(0.0, offset), warp_strength, warp_scale, continent_seed);
    
    // Calculate terrain at neighboring points
    float terrain_right = fractal_noise_seeded(warped_uv_right * terrain_scale, terrain_octaves, terrain_persistence, terrain_seed) * terrain_strength;
    float terrain_up = fractal_noise_seeded(warped_uv_up * terrain_scale, terrain_octaves, terrain_persistence, terrain_seed) * terrain_strength;
    
    // Add detail noise
    float detail_right = fractal_noise_seeded(warped_uv_right * detail_scale, detail_octaves, 0.5, detail_seed) * detail_strength;
    float detail_up = fractal_noise_seeded(warped_uv_up * detail_scale, detail_octaves, 0.5, detail_seed) * detail_strength;
    
    terrain_right += detail_right;
    terrain_up += detail_up;
    
    // Apply continent mask (only show terrain on land)
    float continent_right = smoothstep(continent_threshold - continent_sharpness, continent_threshold + continent_sharpness, 
                                     fractal_noise_seeded(warped_uv_right * continent_scale, continent_octaves, continent_persistence, continent_seed));
    float continent_up = smoothstep(continent_threshold - continent_sharpness, continent_threshold + continent_sharpness, 
                                   fractal_noise_seeded(warped_uv_up * continent_scale, continent_octaves, continent_persistence, continent_seed));
    
    terrain_right *= continent_right;
    terrain_up *= continent_up;
    
    // Calculate gradients
    vec2 gradient = vec2(terrain_right - land_terrain, terrain_up - land_terrain) / offset;
    
    // Convert to normal map format (tangent space)
    vec3 normal = normalize(vec3(-gradient.x * normal_map_intensity, -gradient.y * normal_map_intensity, 1.0));
    
    // Convert from [-1,1] to [0,1] range for texture storage
    normal = normal * 0.5 + 0.5;
    
    return normal;
}

// === MAIN SHADER FUNCTION ===
void fragment() {
    // Get UV coordinates centered around (0.5, 0.5)
    vec2 original_uv = UV - 0.5;
    
    // Calculate original distance for planet mask
    float original_distance = length(original_uv);
    
    // Apply sphere warping for 3D effect
    vec2 uv = sphere_warp(original_uv, sphere_strength);
    
    // Apply UV offset
    uv += vec2(uv_offset_x, uv_offset_y);
    
    // Calculate distance from center and angle for polar features
    float distance = length(uv - vec2(uv_offset_x, uv_offset_y));
    
    // Create circular planet mask with soft edges (use original distance)
    float planet_mask = 1.0 - smoothstep(planet_radius - edge_softness, planet_radius, original_distance);
    
    // Create hard planet boundary for surface masking (no edge softness)
    float hard_planet_mask = step(original_distance, planet_radius);
    
    // === CONTINENTAL GENERATION ===
    // Apply domain warping for realistic coastlines
    vec2 warped_uv = domain_warp_seeded(uv, warp_strength, warp_scale, continent_seed);
    
    // Generate continental base using warped coordinates with octaves
    float continent_noise = fractal_noise_seeded(warped_uv * continent_scale, continent_octaves, continent_persistence, continent_seed);
    
    // Create sharp continent/ocean boundaries
    float continent_mask = smoothstep(continent_threshold - continent_sharpness, 
                                    continent_threshold + continent_sharpness, 
                                    continent_noise);
    
    // === TERRAIN GENERATION ===
    // Generate primary terrain (only on land)
    vec2 terrain_uv = warped_uv * terrain_scale;
    float primary_terrain = fractal_noise_seeded(terrain_uv, terrain_octaves, terrain_persistence, terrain_seed);
    
    // Generate secondary detail
    vec2 detail_uv = warped_uv * detail_scale;
    float secondary_detail = fractal_noise_seeded(detail_uv, detail_octaves, 0.5, detail_seed);
    
    // Combine terrain layers (only affect land areas)
    float land_terrain = primary_terrain * terrain_strength + 
                        secondary_detail * detail_strength;
    land_terrain *= continent_mask; // Only on continents
    
    // === RIVER SYSTEM ===
    // Generate rivers using improved flow noise with octaves
    float river_noise = flow_noise_seeded(warped_uv, river_scale, river_seed, river_octaves, river_persistence);
    float river_mask = smoothstep(1.0 - river_width, 1.0, river_noise);
    
    // Rivers should flow to coastlines - use original continent mask but ensure they're only on land
    river_mask *= continent_mask; // Use original mask so rivers can reach coastlines
    river_mask *= step(0.5, continent_mask); // But ensure they don't appear in ocean (hard cutoff)
    river_mask *= river_strength;
    
    // Calculate river glow
    float river_glow_mask = calculate_river_glow(warped_uv, continent_mask, river_mask, uv, planet_mask);
    
    // === POLAR ICE CAPS ===
    // Calculate latitude-based ice caps using spherical coordinates
    // Calculate 3D position on sphere surface for proper curvature
    float sphere_dist = length(original_uv);
    vec3 sphere_position = vec3(0.0, 0.0, 0.0);
    
    if (sphere_dist <= planet_radius) {
        float z = sqrt(max(0.0, planet_radius * planet_radius - sphere_dist * sphere_dist));
        sphere_position = vec3(original_uv.x, original_uv.y, z);
        sphere_position = normalize(sphere_position);
    }
    
    // Use the Y component of the normalized sphere position for latitude
    float spherical_latitude = abs(sphere_position.y);
    float ice_cap_mask = smoothstep(1.0 - ice_cap_size - ice_cap_softness, 
                                   1.0 - ice_cap_size + ice_cap_softness, 
                                   spherical_latitude);
    
    // === DESERT ZONES ===
    // Create desert bands at specific latitudes using spherical coordinates
    float spherical_desert_lat = abs(sphere_position.y);
    float desert_mask = 1.0 - smoothstep(desert_latitude - desert_width, 
                                        desert_latitude + desert_width, 
                                        abs(spherical_desert_lat - desert_latitude));
    desert_mask *= continent_mask; // Deserts only on land
    desert_mask *= desert_intensity;
    
    // === OCEAN DEPTH CALCULATION ===
    // Create ocean depth variation
    float ocean_depth_noise = fractal_noise_seeded(uv * 2.0, 3.0, 0.5, detail_seed + 200.0);
    float ocean_depth_factor = (1.0 - continent_mask) * (ocean_depth_noise * ocean_depth + ocean_depth);
    
    // === CLOUD CALCULATION ===
    // Calculate cloud coverage
    float cloud_mask = calculate_clouds(uv, original_uv);
    
    // === OUTPUT MODE SELECTION ===
    if (output_mode == 1) {
        // SPECULAR MAP OUTPUT
        float specular = calculate_specular(continent_mask, river_mask, ice_cap_mask);
        COLOR = vec4(vec3(specular), planet_mask);
    } else if (output_mode == 2) {
        // NORMAL MAP OUTPUT
        vec3 normal_map = calculate_normal_map(uv, original_uv, continent_mask, land_terrain);
        COLOR = vec4(normal_map, planet_mask);
    } else {
        // === COLOR MODE (DEFAULT) ===
        vec3 base_color;
        
        if (continent_mask > 0.5) {
            // LAND AREAS
            vec3 land_color;
            
            // Use the actual land_terrain value (which already includes continent masking)
            // Apply terrain softness to thresholds for smooth transitions
            float soft_mountain = mountain_threshold - terrain_softness;
            float soft_highland = highland_threshold - terrain_softness;
            
            // Determine base land color based on terrain height with smooth transitions
            if (land_terrain > soft_mountain) {
                // Mountain regions
                float mountain_blend = smoothstep(soft_mountain, mountain_threshold + terrain_softness, land_terrain);
                land_color = mix(highland_color, mountain_color, mountain_blend);
            } else if (land_terrain > soft_highland) {
                // Highland regions  
                float highland_blend = smoothstep(soft_highland, highland_threshold + terrain_softness, land_terrain);
                land_color = mix(lowland_color, highland_color, highland_blend);
            } else {
                // Lowland regions
                land_color = lowland_color;
            }
            
            // Apply desert coloring
            land_color = mix(land_color, desert_color, desert_mask);
            
            // Apply ice cap coloring
            land_color = mix(land_color, ice_color, ice_cap_mask);
            
            // Add coastal beaches near water
            float coast_distance = smoothstep(continent_threshold - coastal_blend, 
                                            continent_threshold, continent_noise);
            land_color = mix(beach_color, land_color, coast_distance);
            
            base_color = land_color;
        } else {
            // OCEAN AREAS
            vec3 ocean_color = mix(deep_ocean_color, shallow_water_color, 
                                  1.0 - ocean_depth_factor);
            
            // Apply ice cap coloring to ocean (sea ice)
            ocean_color = mix(ocean_color, ice_color, ice_cap_mask * 0.7);
            
            base_color = ocean_color;
        }
        
        // === RIVERS ===
        // Apply river coloring on top of land
        base_color = mix(base_color, river_color, river_mask);
        
        // === LIGHTING CALCULATION ===
        // Calculate surface normal for the current position
        vec3 surface_normal = calculate_surface_normal(uv, original_uv);
        
        // Calculate primary lighting factor
        float diffuse_lighting = calculate_lighting(surface_normal, light_direction);
        
        // Calculate shadow factor for tinting
        float shadow_factor = calculate_shadow_factor(surface_normal, light_direction);
        
        // Calculate enhanced rim lighting
        float rim_lighting = calculate_rim_light(surface_normal, original_uv, light_direction);
        
        // Calculate extended rim light (goes beyond planet edge)
        float extended_rim = calculate_extended_rim_light(original_uv, light_direction);
        
        // Calculate rim glow (extends beyond planet boundary) - now independent
        float rim_glow = calculate_rim_glow(original_uv, light_direction);
        
        // Apply primary lighting to the base color
        vec3 diffuse_contribution = base_color * light_color * diffuse_lighting;
        
        // Apply ambient lighting with color
        vec3 ambient_contribution = base_color * ambient_color * ambient_light;
        
        // Apply rim lighting contribution (inside planet) - blend with extended rim
        vec3 rim_contribution = rim_light_color * rim_lighting;
        
        // Apply rim glow contribution (outside planet)
        vec3 glow_contribution = rim_light_color * rim_glow;
        
        // Apply extended rim light contribution (smooth transition)
        vec3 extended_rim_contribution = rim_light_color * extended_rim;
        
        // Apply river glow contribution
        vec3 river_glow_contribution = river_glow_color * river_glow_mask;
        
        // Combine all lighting contributions
        vec3 lit_color = diffuse_contribution + ambient_contribution + rim_contribution;
        
        // Apply shadow tinting
        lit_color = mix(lit_color, lit_color * shadow_tint, shadow_factor * shadow_tint_strength);
        
        // === CLOUD SHADOWS ===
        // Apply cloud shadows to surface
        vec3 cloud_shadowed_color = mix(lit_color, lit_color * cloud_shadow_color, cloud_mask * cloud_shadow_strength);
        
        // === PLANETARY CORE GRADIENT ===
        // Create core glow effect
        float radial_gradient = distance / planet_radius;
        float core_influence = 1.0 - smoothstep(0.0, core_size, radial_gradient);
        vec3 core_glow = core_color * core_influence;
        
        // Blend core with surface features (subtle effect)
        cloud_shadowed_color = mix(cloud_shadowed_color, core_glow, core_influence * 0.15);
        
        // === COLOR VARIATION ===
        // Add subtle color variation
        float variation_noise = fractal_noise_seeded(uv * 4.0, 3.0, 0.6, detail_seed + 100.0);
        vec3 surface_final = mix(cloud_shadowed_color, cloud_shadowed_color * variation_tint, 
                                variation_noise * color_variation);
        
        // === CLOUD LAYER ===
        // Calculate cloud lighting (clouds are lit by the same light source)
        float cloud_lighting = calculate_lighting(surface_normal, light_direction);
        vec3 lit_cloud_color = cloud_color * light_color * cloud_lighting;
        
        // Blend clouds on top of surface
        vec3 final_color = mix(surface_final, lit_cloud_color, cloud_mask * cloud_opacity);
        
        // Calculate combined glow effects
        vec3 combined_glow = glow_contribution + extended_rim_contribution + river_glow_contribution;
        float combined_glow_alpha = max(max(rim_glow, extended_rim), river_glow_mask);
        
        // Calculate final alpha including planet and all glow effects
        float final_alpha = max(planet_mask, combined_glow_alpha);
        
        // Mask surface colors with HARD boundary, but preserve glow colors
        vec3 masked_surface = final_color * hard_planet_mask;
        
        // Combine masked surface with glow effects
        vec3 final_combined = masked_surface + combined_glow;
        
        // Set output color with proper alpha for transparency (uses soft planet_mask)
        COLOR = vec4(final_combined, final_alpha);
    }
}
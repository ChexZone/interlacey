#define MAX_LIGHTS 25

#ifdef GL_ES
precision mediump float;
#endif

extern vec4 lightRects[MAX_LIGHTS];  // (topleft_x, topleft_y, bottomright_x, bottomright_y)
extern float radii[MAX_LIGHTS];        // inset radius (for degenerate rectangle -> circle)
extern float sharpnesses[MAX_LIGHTS];  // per-light sharpness (0.0 = no gradient, >0 = gradient)
extern vec4 lightChannels[MAX_LIGHTS]; // vec4: rgb = color, a = brightness (0 = none, 1 = full)
extern vec4 lightTypes[MAX_LIGHTS];    // vec4: xy = light direction (compressed), z = spotlight cone angle, w = light type (0=point, 1=spotlight)
extern float blendRange;               // global blend range multiplier
extern int lightCount;                 // number of active lights
extern vec2 aspectRatio;               // e.g. {16, 9}
extern vec4 baseShadowColor;           // base dark color when no light is applied (rgb = color, a = shadow strength: 0.0 = no darkening, 1.0 = full shadow)
extern float normalStrength;           // multiplier for normal map effect (0.0 = disabled)
extern float specularPower;            // specular highlight power/shininess
extern vec3 viewDirection;             // normalized view direction for specular calculation
extern float lightingBands;            // number of discrete lighting bands for cel-shading (e.g., 3.0 for 3 bands)
extern float ambientWrap;              // ambient wrap lighting (0.0 = no wrap, 1.0 = full ambient, 0.5 = half-lambert)

uniform sampler2DArray MainTex;

// Signed distance function for an axis–aligned box.
float sdfBox(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
}

// Reconstruct normal from RG channels with optional rotation
vec3 reconstructNormal(vec2 normalRG, float rotation) {
    vec2 normal2D = normalRG * 2.0 - 1.0; // Convert from [0,1] to [-1,1]
    
    // Apply rotation for spinning objects (2D game viewed dead-on)
    float cosR = cos(rotation);
    float sinR = sin(rotation);
    normal2D = vec2(
        normal2D.x * cosR - normal2D.y * sinR,
        normal2D.x * sinR + normal2D.y * cosR
    );
    
    float normalZ = sqrt(max(0.0, 1.0 - dot(normal2D, normal2D)));
    vec3 normal = normalize(vec3(normal2D, normalZ));
    
    // Blend between flat normal and texture normal based on strength
    return normalize(mix(vec3(0.0, 0.0, 1.0), normal, normalStrength));
}

// Reconstruct light direction from compressed XY channels
vec3 reconstructLightDirection(vec2 lightXY) {
    vec2 dir2D = lightXY * 2.0 - 1.0; // Convert from [0,1] to [-1,1]
    float dirZ = sqrt(max(0.0, 1.0 - dot(dir2D, dir2D)));
    return normalize(vec3(dir2D, dirZ));
}
void effect()
{
    vec4 color = VaryingColor;
    vec2 texture_coords = VaryingTexCoord.xy;
    vec2 screen_coords = love_PixelCoord.xy;
    
    // Sample all 3 layers
    vec4 layer0 = Texel(MainTex, vec3(texture_coords, 0.0));
    vec4 layer1 = Texel(MainTex, vec3(texture_coords, 1.0));
    vec4 layer2 = Texel(MainTex, vec3(texture_coords, 2.0));
    
    // Apply lighting effect to layer 0
    vec4 texColor = layer0;
    
    // Extract material properties from layer1 and layer2
    vec4 materialSample1 = layer1; // RG = normal, B = specular, A = 1.0
    vec4 materialSample2 = layer2; // R = emission/occlusion, G = height, B = rotation, A = 1.0
    
    // Extract properties from new layout
    float specular = (materialSample1.b > 0.0) ? materialSample1.b : 0.0; // Specular from layer1.b
    float shadowEmission = materialSample2.r; // Emission/occlusion from layer2.r
    float height = (materialSample2.g > 0.0) ? materialSample2.g : 0.0; // Height from layer2.g
    float rotation = materialSample2.b * 6.283185307; // Rotation from layer2.b (0-1 mapped to 0-2π)
    
    // Check if normal mapping data exists (both RG channels must be > 0)
    bool hasNormalData = (materialSample1.r > 0.0 || materialSample1.g > 0.0);
    
    // Reconstruct normal with rotation applied (negated to counter-rotate with object)
    vec3 normal = (normalStrength > 0.0 && hasNormalData) ? reconstructNormal(materialSample1.rg, -rotation) : vec3(0.0, 0.0, 1.0);
    
    // Determine emission strength (values > 0.5 are emissive)
    float emissionStrength = (shadowEmission > 0.5) ? (shadowEmission - 0.5) * 2.0 : 0.0; // Map 0.5-1.0 to 0.0-1.0
    bool isEmissive = emissionStrength > 0.0;
    
    // Determine the base minimum color.
    vec3 minColor = mix(baseShadowColor.rgb, texColor.rgb, 1.0 - baseShadowColor.a);
    
    float totalIntensity = 0.0;
    vec3 weightedColor = vec3(0.0);
    vec3 totalSpecular = vec3(0.0);
    
    // Adjust coordinates for aspect ratio.
    vec2 aspectCorrectedCoords = texture_coords * aspectRatio;
    
    for (int i = 0; i < lightCount; i++) {
        // Convert the rectangle's corners to aspect–corrected space.
        vec2 tl = lightRects[i].xy * aspectRatio;
        vec2 br = lightRects[i].zw * aspectRatio;
        
        if (lightChannels[i].a <= 0.0) continue;

        // Compute center and half–size.
        vec2 center = (tl + br) * 0.5;
        vec2 halfSize = abs(br - tl) * 0.5;
        
        // Compute distance first
        float d = sdfBox(aspectCorrectedCoords - center, halfSize) - radii[i];
        
        // Early exit if too far from light (before doing expensive calculations)
        if (d > blendRange * 0.2) continue;
        


        float baseContribution;
        if (sharpnesses[i] == 1.0) {
            // Hard edge with no gradient: full contribution if inside, none if outside.
            baseContribution = (d <= 0.0) ? 1.0 : 0.0;
        } else {
            // Calculate fade width based on blendRange and sharpness.
            float fadeWidth = blendRange * mix(0.2, 0.01, sharpnesses[i]);
            baseContribution = 1.0 - smoothstep(0.0, fadeWidth, d);
        }
        
        // Calculate normal mapping and specular only if enabled (normalStrength > 0)
        float normalContribution = baseContribution;
        float specularContribution = 0.0;
        
        if (normalStrength > 0.0 && hasNormalData) {
            // Get light type and direction data
            float lightType = lightTypes[i].w;
            vec3 lightDir;
            float spotlightAttenuation = 1.0;
            
            if (lightType < 0.5) {
                // Point light: calculate direction from fragment to light source
                vec2 lightPos2D = center / aspectRatio; // Convert back to texture space
                vec2 lightOffset = lightPos2D - texture_coords;
                lightOffset.y = -lightOffset.y; // Flip Y to match lighting coordinate system
                lightDir = normalize(vec3(lightOffset, 0.1)); // Small Z offset for 2.5D effect
            } else {
                // Spotlight: use compressed directional data
                vec3 spotlightDir = reconstructLightDirection(lightTypes[i].xy);
                
                // Calculate direction from light source to fragment for cone calculation
                vec2 lightPos2D = center / aspectRatio;
                vec2 fragOffset = texture_coords - lightPos2D;
                fragOffset.y = -fragOffset.y; // Flip Y to match coordinate system
                vec3 fragDir = normalize(vec3(fragOffset, 0.1));
                
                // Calculate cone attenuation
                float coneAngle = lightTypes[i].z; // Cone angle in radians
                float spotDot = dot(spotlightDir, fragDir);
                float cosOuter = cos(coneAngle);
                float cosInner = cos(coneAngle * 0.5); // Inner cone is half the outer cone
                
                // Smooth falloff from inner to outer cone
                spotlightAttenuation = smoothstep(cosOuter, cosInner, spotDot);
                
                // Light direction for normal mapping is still from fragment toward light
                lightDir = -fragDir;
            }
            
            // Apply normal mapping to lighting calculation with hard edges
            float normalDot = max(0.0, dot(normal, lightDir));
            
            // Apply ambient wrap lighting to make surfaces brighter
            // This remaps the dot product so glancing angles receive more light
            float wrappedDot = (normalDot + ambientWrap) / (1.0 + ambientWrap);
            wrappedDot = clamp(wrappedDot, 0.0, 1.0);
            
            // Create discrete lighting bands (cel-shading)
            // Quantize the normal dot product into discrete bands based on lightingBands parameter
            float sharpenedDot;
            if (lightingBands > 1.0) {
                // Multiple bands: quantize into discrete steps
                sharpenedDot = floor(wrappedDot * lightingBands) / lightingBands;
            } else {
                // Single band or less: just use normalized value
                sharpenedDot = wrappedDot;
            }
            
            normalContribution = baseContribution * sharpenedDot * spotlightAttenuation;
            
            // Specular calculation (only if specular data exists)
            if (specular > 0.001) {
                vec3 halfVector = normalize(lightDir + viewDirection);
                float specularDot = max(0.0, dot(normal, halfVector));
                float specularValue = pow(specularDot, specularPower);
                
                // Apply toon/cel-shading banding to specular highlights
                // Create discrete bands for a stylized look
                if (lightingBands > 1.0) {
                    // Use fewer bands for specular (typically 2-3 bands work well)
                    float specularBands = max(2.0, lightingBands - 1.0);
                    specularValue = floor(specularValue * specularBands) / specularBands;
                }
                
                specularContribution = baseContribution * specularValue * specular * spotlightAttenuation;
            }
        }
        
        // Calculate shadow/emission effect
        // Map shadowEmission range [0.01, 0.5] to light blocking [1.0, 0.0]
        // where 0.01 = fully block light, 0.5 = allow full light
        float shadowMask = 1.0; // Default: normal lighting
        if (shadowEmission > 0.01 && shadowEmission < 0.5) {
            // Remap 0.01-0.5 range to 0.0-1.0 (how much light to allow)
            shadowMask = (shadowEmission - 0.01) / (0.5 - 0.01);
        } else if (shadowEmission > 0.0 && shadowEmission <= 0.01) {
            shadowMask = 0.0; // Fully block light
        }
        
        // Apply shadow effect - reduce contribution for shadow areas
        normalContribution *= shadowMask;
        specularContribution *= shadowMask;
        
        // Scale contribution by brightness.
        float brightness = lightChannels[i].a;
        float c = brightness * normalContribution;
        
        totalIntensity += c;
        weightedColor += c * lightChannels[i].rgb;
        totalSpecular += brightness * specularContribution * lightChannels[i].rgb;
    }
    
    // Clamp overall light intensity and compute composite tint.
    float intensity = clamp(totalIntensity, 0.0, 1.0);
    vec3 compositeTint = (totalIntensity > 0.0) ? (weightedColor / totalIntensity) : vec3(1.0);
    
    vec3 finalColor;
    
    // // Check if pixel is completely black
    // bool isCompletelyBlack = (texColor.r == 0.0 && texColor.g == 0.0 && texColor.b == 0.0);
    // if (isCompletelyBlack && !isEmissive) {
    //     // Invert lighting for black pixels: no light = white, full light = black
    //     // Scale from white to black based on light intensity
    //     float invertedIntensity = 1.0 - intensity;
    //     finalColor = vec3(invertedIntensity);
    // } else {
    //     // Start with normal lighting for all pixels
        vec3 litColor = mix(minColor, texColor.rgb * compositeTint, intensity);
        
        if (isEmissive) {
            // Emissive pixels: blend lit color toward full bright based on emission strength
            // Low emission = mostly lit by lights, high emission = fully bright self-lit
            finalColor = mix(litColor, texColor.rgb, emissionStrength);
        } else {
            finalColor = litColor;
        }
    // }
    

    // Add specular highlights (not added to emissive surfaces)
    if (!isEmissive) {
        finalColor += totalSpecular;
    }
    // finalColor = vec3(layer1.rgb);
    
    // Output lighting effect to canvas 0, and pass through layers 1 and 2
    love_Canvases[0] = vec4(finalColor, texColor.a);
    love_Canvases[1] = layer1;
    love_Canvases[2] = layer2;
}

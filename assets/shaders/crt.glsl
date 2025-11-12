// CRT Effect Parameters
uniform sampler2DArray MainTex;
extern float rotation;
extern float time;
extern vec2 resolution;
extern float curvature = 3.5;
extern float scanlineIntensity = 0.15;
extern float vignetteIntensity = 0.3;
extern float chromaticAberration = 0.0325;
extern float brightness = 1.5;
extern float interlaceIntensity = 0.03;
extern float interlaceSpeed = 60.0;
extern float staticIntensity = 0.05;

// Random noise function for static effect
float noise(vec2 uv, float seed) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233)) + seed) * 43758.5453);
}

// Generate colored TV static effect - creates RGB noise like analog TV
vec3 coloredStaticEffect(vec2 uv) {
    // High-frequency noise that changes every frame
    vec2 pixelUV = uv * resolution;
    
    // Generate separate noise values for each color channel
    float rNoise = noise(pixelUV, time * 100.0);
    float gNoise = noise(pixelUV, time * 100.0 + 13.7);
    float bNoise = noise(pixelUV, time * 100.0 + 27.3);
    
    // Add more variation with different frequencies
    float rNoise2 = noise(pixelUV * 1.3, time * 100.0 + 1.0);
    float gNoise2 = noise(pixelUV * 1.3, time * 100.0 + 14.7);
    float bNoise2 = noise(pixelUV * 1.3, time * 100.0 + 28.3);
    
    // Combine noises for each channel
    vec3 colorNoise;
    colorNoise.r = (rNoise + rNoise2) * 0.5;
    colorNoise.g = (gNoise + gNoise2) * 0.5;
    colorNoise.b = (bNoise + bNoise2) * 0.5;
    
    // Create intensity mask - some pixels will be brighter (white) while others show color
    float intensity = noise(pixelUV * 0.7, time * 100.0 + 50.0);
    
    // Mix between colored noise and white noise based on intensity
    // This creates the classic TV static look with white, colored, and dark pixels
    vec3 whiteNoise = vec3(intensity);
    colorNoise = mix(colorNoise, whiteNoise, intensity * 0.6);
    
    return colorNoise;
}

// Apply barrel distortion to simulate curved CRT screen
vec2 curveScreen(vec2 uv) {
    uv = uv * 2.0 - 1.0;
    vec2 offset = abs(uv.yx) / curvature;
    uv = uv + uv * offset * offset;
    uv = uv * 0.5 + 0.5;
    return uv;
}

// Scanline effect
float scanline(vec2 uv) {
    float line = sin(uv.y * resolution.y * 3.14159 * 0.25);  // 0.5 makes scanlines twice as wide
    return 1.0 - scanlineIntensity * (1.0 - line * line);
}

// Interlacing effect - alternates between even/odd lines
float interlace(vec2 uv) {
    float row = floor(uv.y * resolution.y);
    float field = mod(floor(time * interlaceSpeed), 2.0);
    float lineField = mod(row, 2.0);
    
    // Darken lines that don't match the current field
    float intensity = (lineField == field) ? 1.0 : (1.0 - interlaceIntensity);
    return intensity;
}

// Vignette effect
float vignette(vec2 uv) {
    uv *= 1.0 - uv.yx;
    float vig = uv.x * uv.y * 15.0;
    return pow(vig, vignetteIntensity);
}

// Apply CRT effects to a color
vec3 applyCRTEffects(vec3 color, vec2 uv) {
    // Apply interlacing
    color *= interlace(uv);
    
    // Apply scanlines
    color *= scanline(uv);
    
    // Apply vignette
    color *= vignette(uv);
    
    // Apply brightness boost
    color *= brightness;
    
    // Add subtle flicker
    color *= 0.95 + 0.05 * sin(time * 10.0 + uv.y * 100.0);
    
    // Add colored TV static - creates RGB noise with white/red/green/blue/purple pixels
    vec3 staticNoise = coloredStaticEffect(uv);
    // Map from [0,1] to [-1,1] for both darkening and brightening each channel
    color += (staticNoise - 0.5) * 2.0 * staticIntensity;
    
    return color;
}

void effect()
{
    vec2 uv = VaryingTexCoord.xy;
    
    // Apply screen curvature
    vec2 curvedUV = curveScreen(uv);
    
    // Check if we're outside the curved screen bounds
    if (curvedUV.x < 0.0 || curvedUV.x > 1.0 || curvedUV.y < 0.0 || curvedUV.y > 1.0) {
        love_Canvases[0] = vec4(0.0, 0.0, 0.0, 1.0);
        love_Canvases[1] = vec4(0.0, 0.0, 0.0, 0.0);
        love_Canvases[2] = vec4(0.0, 0.0, 0.0, 0.0);
        return;
    }
    
    // Sample the 3 layers from the texture array with chromatic aberration on layer 0
    vec2 offset = (curvedUV - 0.5) * chromaticAberration;
    vec4 layer0;
    layer0.r = Texel(MainTex, vec3(curvedUV - offset, 0.0)).r;
    layer0.g = Texel(MainTex, vec3(curvedUV, 0.0)).g;
    layer0.b = Texel(MainTex, vec3(curvedUV + offset, 0.0)).b;
    layer0.a = Texel(MainTex, vec3(curvedUV, 0.0)).a;
    
    vec4 layer1 = Texel(MainTex, vec3(curvedUV, 1.0));
    vec4 layer2 = Texel(MainTex, vec3(curvedUV, 2.0));
    
    // Set the blue component to the rotation extern only if it's 0.0
    layer2.b = mix(rotation, layer2.b, step(0.001, layer2.b));
    
    // Apply CRT effects to layer0 color
    layer0.rgb = applyCRTEffects(layer0.rgb, curvedUV);
    
    // Output each layer to its corresponding canvas
    love_Canvases[0] = layer0 * VaryingColor;
    love_Canvases[1] = layer1 * layer0.a;
    love_Canvases[2] = layer2 * layer0.a;
}
// CRT Effect Parameters
uniform sampler2DArray MainTex;
extern float rotation;
extern float time;
extern vec2 resolution;
extern float curvature = 3.0;
extern float scanlineIntensity = 0.15;
extern float vignetteIntensity = 0.3;
extern float chromaticAberration = 0.002;
extern float brightness = 1.5;

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
    float line = sin(uv.y * resolution.y * 3.14159);
    return 1.0 - scanlineIntensity * (1.0 - line * line);
}

// Vignette effect
float vignette(vec2 uv) {
    uv *= 1.0 - uv.yx;
    float vig = uv.x * uv.y * 15.0;
    return pow(vig, vignetteIntensity);
}

// Apply CRT effects to a color
vec3 applyCRTEffects(vec3 color, vec2 uv) {
    // Apply scanlines
    color *= scanline(uv);
    
    // Apply vignette
    color *= vignette(uv);
    
    // Apply brightness boost
    color *= brightness;
    
    // Add subtle flicker
    color *= 0.95 + 0.05 * sin(time * 10.0 + uv.y * 100.0);
    
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
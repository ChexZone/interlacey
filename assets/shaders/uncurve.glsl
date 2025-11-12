// Inverse CRT Curvature - Un-curves barrel distortion
uniform sampler2DArray MainTex;
extern float rotation;
extern float curvature = 2.0;

// Apply inverse barrel distortion to uncurve the screen
vec2 uncurveScreen(vec2 uv) {
    uv = uv * 2.0 - 1.0;
    vec2 offset = abs(uv.yx) / curvature;
    uv = uv - uv * offset * offset;  // Subtract instead of add to reverse the effect
    uv = uv * 0.5 + 0.5;
    return uv;
}

void effect()
{
    vec2 uv = VaryingTexCoord.xy;
    
    // Apply inverse screen curvature
    vec2 uncurvedUV = uncurveScreen(uv);
    
    // Sample the 3 layers from the texture array
    vec4 layer0 = Texel(MainTex, vec3(uncurvedUV, 0.0));
    vec4 layer1 = Texel(MainTex, vec3(uncurvedUV, 1.0));
    vec4 layer2 = Texel(MainTex, vec3(uncurvedUV, 2.0));
    
    // Set the blue component to the rotation extern only if it's 0.0
    layer2.b = mix(rotation, layer2.b, step(0.001, layer2.b));
    
    // Output each layer to its corresponding canvas
    love_Canvases[0] = layer0 * VaryingColor;
    love_Canvases[1] = layer1 * layer0.a;
    love_Canvases[2] = layer2 * layer0.a;
}

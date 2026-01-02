#ifndef INCLUDE_TEXTURE_SAMPLING
    #define INCLUDE_TEXTURE_SAMPLING
    
    vec4 texBilinearDepthReject (in sampler2D tex, in sampler2D normals, in vec3 normal, in vec2 uv, in vec2 texSize)
    {
        vec2 texel = uv * texSize - 0.5;

        vec4 samples = vec4(0.0);
        float weights = 0.0;

        for (int i = 0; i < 4; i++) {
            ivec2 offset = ivec2(i & 1, i >> 1);

            float sampleWeight = exp(-4.0 * length(texelFetch(normals, ivec2(texel) + offset, 0).xyz - normal)) * (1.0 - abs(texel.x - floor(texel.x + offset.x))) * (1.0 - abs(texel.y - floor(texel.y + offset.y)));
            samples += sampleWeight * texelFetch(tex, ivec2(texel) + offset, 0);
            weights += sampleWeight;
        }

        if (weights > 0.01 && !any(isnan(samples))) return vec4(samples.rgb / weights, max(1.0, samples.a + (1.0 - weights)));
        else return vec4(0.0, 0.0, 0.0, 1.0);
    }

#endif
#include "/include/uniforms.glsl"
#include "/include/checker.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"
#include "/include/heitz.glsl"
#include "/include/octree.glsl"
#include "/include/raytracing.glsl"
#include "/include/textureData.glsl"
#include "/include/brdf.glsl"
#include "/include/ircache.glsl"
#include "/include/spaceConversion.glsl"

layout (rgba16f) uniform image2D colorimg2;
layout (local_size_x = 8, local_size_y = 8) in;

#if TAA_UPSCALING_FACTOR == 100
    const vec2 workGroupsRender = vec2(1.0, 1.0);
#elif TAA_UPSCALING_FACTOR == 75
    const vec2 workGroupsRender = vec2(0.75, 0.75);
#elif TAA_UPSCALING_FACTOR == 50
    const vec2 workGroupsRender = vec2(0.5, 0.5);
#endif

void main ()
{
    uint state = gl_GlobalInvocationID.x + gl_GlobalInvocationID.y * uint(renderSize.x) + uint(renderSize.x) * uint(renderSize.y) * (frameCounter & 1023u);
    ivec2 texel = ivec2(gl_GlobalInvocationID.xy);

    float depth = texelFetch(depthtex1, texel, 0).x;

    if (depth == 1.0) {
        imageStore(colorimg2, ivec2(gl_GlobalInvocationID.xy), vec4(0.0, 0.0, 0.0, 1.0));
        return;
    }

    DeferredMaterial mat = unpackMaterialData(texel);

    if (dot(mat.geoNormal, shadowDir) > 0.0) {
        vec2 uv = (vec2(texel) + 0.5) * texelSize;
        vec4 playerPos = projectAndDivide(gbufferModelViewProjectionInverse, vec3(uv, depth) * 2.0 - 1.0 - vec3(taaOffset, 0.0));

        Ray shadowRay;

        shadowRay.origin = playerPos.xyz + mat.geoNormal * 0.005;
        vec3 shadowMask = vec3(0.0);

        for (int i = 0; i < SHADOW_SAMPLES; i++) {
            shadowRay.direction = sampleSunDir(shadowDir, 
                #if NOISE_METHOD == 1
                    vec2(heitzSample(ivec2(gl_GlobalInvocationID.xy), frameCounter, 2 * i), heitzSample(ivec2(gl_GlobalInvocationID.xy), frameCounter, 2 * i + 1))
                #else
                    vec2(randomValue(state), randomValue(state))
                #endif
            );
            shadowMask += TraceShadowRay(shadowRay, 1024.0, true).rgb;
        }

        shadowMask *= rcp(SHADOW_SAMPLES);

        imageStore(colorimg2, ivec2(gl_GlobalInvocationID.xy), vec4(shadowMask, 1.0));
    } else imageStore(colorimg2, ivec2(gl_GlobalInvocationID.xy), vec4(0.0, 0.0, 0.0, 1.0));
}
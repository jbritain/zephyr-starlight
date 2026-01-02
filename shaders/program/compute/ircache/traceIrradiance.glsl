#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"
#include "/include/octree.glsl"
#include "/include/raytracing.glsl"
#include "/include/textureData.glsl"
#include "/include/ircache.glsl"
#include "/include/brdf.glsl"
#include "/include/atmosphere.glsl"

layout (local_size_x = 64) in;

#if IRCACHE_UPDATE_INTERVAL == 1
    #if IRCACHE_VOXEL_ARRAY_SIZE == 32768
        const ivec3 workGroups = ivec3(512, 1, 1);
    #elif IRCACHE_VOXEL_ARRAY_SIZE == 49152
        const ivec3 workGroups = ivec3(768, 1, 1);
    #elif IRCACHE_VOXEL_ARRAY_SIZE == 65536
        const ivec3 workGroups = ivec3(1024, 1, 1);
    #elif IRCACHE_VOXEL_ARRAY_SIZE == 98304
        const ivec3 workGroups = ivec3(1536, 1, 1);
    #elif IRCACHE_VOXEL_ARRAY_SIZE == 131072
        const ivec3 workGroups = ivec3(2048, 1, 1);
    #elif IRCACHE_VOXEL_ARRAY_SIZE == 262144
        const ivec3 workGroups = ivec3(4096, 1, 1);
    #endif
#elif IRCACHE_UPDATE_INTERVAL == 2
    #if IRCACHE_VOXEL_ARRAY_SIZE == 32768
        const ivec3 workGroups = ivec3(256, 1, 1);
    #elif IRCACHE_VOXEL_ARRAY_SIZE == 49152
        const ivec3 workGroups = ivec3(384, 1, 1);
    #elif IRCACHE_VOXEL_ARRAY_SIZE == 65536
        const ivec3 workGroups = ivec3(512, 1, 1);
    #elif IRCACHE_VOXEL_ARRAY_SIZE == 98304
        const ivec3 workGroups = ivec3(768, 1, 1);
    #elif IRCACHE_VOXEL_ARRAY_SIZE == 131072
        const ivec3 workGroups = ivec3(1024, 1, 1);
    #elif IRCACHE_VOXEL_ARRAY_SIZE == 262144
        const ivec3 workGroups = ivec3(2048, 1, 1);
    #endif
#elif IRCACHE_UPDATE_INTERVAL == 4
    #if IRCACHE_VOXEL_ARRAY_SIZE == 32768
        const ivec3 workGroups = ivec3(128, 1, 1);
    #elif IRCACHE_VOXEL_ARRAY_SIZE == 49152
        const ivec3 workGroups = ivec3(192, 1, 1);
    #elif IRCACHE_VOXEL_ARRAY_SIZE == 65536
        const ivec3 workGroups = ivec3(256, 1, 1);
    #elif IRCACHE_VOXEL_ARRAY_SIZE == 98304
        const ivec3 workGroups = ivec3(384, 1, 1);
    #elif IRCACHE_VOXEL_ARRAY_SIZE == 131072
        const ivec3 workGroups = ivec3(512, 1, 1);
    #elif IRCACHE_VOXEL_ARRAY_SIZE == 262144
        const ivec3 workGroups = ivec3(1024, 1, 1);
    #endif
#elif IRCACHE_UPDATE_INTERVAL == 8
    #if IRCACHE_VOXEL_ARRAY_SIZE == 32768
        const ivec3 workGroups = ivec3(64, 1, 1);
    #elif IRCACHE_VOXEL_ARRAY_SIZE == 49152
        const ivec3 workGroups = ivec3(96, 1, 1);
    #elif IRCACHE_VOXEL_ARRAY_SIZE == 65536
        const ivec3 workGroups = ivec3(128, 1, 1);
    #elif IRCACHE_VOXEL_ARRAY_SIZE == 98304
        const ivec3 workGroups = ivec3(192, 1, 1);
    #elif IRCACHE_VOXEL_ARRAY_SIZE == 131072
        const ivec3 workGroups = ivec3(256, 1, 1);
    #elif IRCACHE_VOXEL_ARRAY_SIZE == 262144
        const ivec3 workGroups = ivec3(512, 1, 1);
    #endif
#elif IRCACHE_UPDATE_INTERVAL == 16
    #if IRCACHE_VOXEL_ARRAY_SIZE == 32768
        const ivec3 workGroups = ivec3(32, 1, 1);
    #elif IRCACHE_VOXEL_ARRAY_SIZE == 49152
        const ivec3 workGroups = ivec3(48, 1, 1);
    #elif IRCACHE_VOXEL_ARRAY_SIZE == 65536
        const ivec3 workGroups = ivec3(64, 1, 1);
    #elif IRCACHE_VOXEL_ARRAY_SIZE == 98304
        const ivec3 workGroups = ivec3(96, 1, 1);
    #elif IRCACHE_VOXEL_ARRAY_SIZE == 131072
        const ivec3 workGroups = ivec3(128, 1, 1);
    #elif IRCACHE_VOXEL_ARRAY_SIZE == 262144
        const ivec3 workGroups = ivec3(256, 1, 1);
    #endif
#endif

void main ()
{   
    uint index = gl_GlobalInvocationID.x + (frameCounter % IRCACHE_UPDATE_INTERVAL) * (IRCACHE_VOXEL_ARRAY_SIZE / IRCACHE_UPDATE_INTERVAL);

    IRCVoxel voxel = ircache.entries[index];
    uint state = gl_GlobalInvocationID.x + (frameCounter & 2047u) * IRCACHE_VOXEL_ARRAY_SIZE / IRCACHE_UPDATE_INTERVAL;

    if (voxel.packedPos == 0u) return;
    if (frameCounter - voxel.lastFrame > 32u || voxel.lastFrame > frameCounter) {
        ircache.entries[index].packedPos = 0u;
        ircache.entries[index].direct = 0u;
        ircache.entries[index].radiance = IRCACHE_INV_MARKER;
        return;
    }

    ivec3 voxelPos = unpackPosition(voxel.packedPos);

    vec3 playerPos = vec3(voxelPos - cameraPositionInt) - cameraPositionFract + 2.0 * (vec3(uvec3(voxel.traceOrigin >> 24u, voxel.traceOrigin >> 16u, voxel.traceOrigin >> 8u) & 255u) * rcp(256.0) + rcp(512.0)) - 0.5;
    vec3 normal = octDecode(vec2(uvec2(voxel.traceOrigin >> 4u, voxel.traceOrigin) & 15u) * rcp(14.0));

    Ray ircRay = Ray(playerPos, randomHemisphereDir(normal, state));
    vec4 radiance = vec4(0.0);

    RayHitInfo rt = TraceRay(ircRay, IRCACHE_MAX_RT_DISTANCE, true, true);

    if (rt.dist != IRCACHE_MAX_RT_DISTANCE) {
        IRCResult query = irradianceCache(ircRay.origin + ircRay.direction * rt.dist, rt.normal, voxel.rank);
        radiance.rgb += rt.albedo.rgb * (rt.emission + query.diffuseIrradiance) + getLightTransmittance(sunDir) * lightBrightness * query.directIrradiance * evalCookBRDF(sunDir, ircRay.direction, max(0.2, rt.roughness), rt.normal, rt.albedo.rgb, rt.F0);
    } else {
        radiance.rgb += calcSkyColor(ircRay.direction, sunDir, randomValue(state));
    }

    radiance.rgb *= dot(normal, ircRay.direction);

    vec3 direct;

    if (dot(normal, shadowDir) > 0.0) direct = TraceShadowRay(Ray(ircRay.origin, sampleSunDir(shadowDir, vec2(randomValue(state), randomValue(state)))), 1024.0, true).rgb;
    else direct = voxel.radiance == IRCACHE_INV_MARKER ? vec3(0.0) : unpack3x10(voxel.direct);

    vec4 r = unpackHalf4x16(voxel.radiance);

    ircache.entries[index].direct = pack3x10(mix(unpack3x10(voxel.direct), direct, (r == vec4(-1.0)) ? 1.0 : 0.1));
    ircache.entries[index].radiance = packHalf4x16(any(isnan(r)) ? vec4(0.0) : (r == vec4(-1.0)) ? radiance : mix(r, radiance, 0.015));
}
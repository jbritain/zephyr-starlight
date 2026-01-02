#include "/include/uniforms.glsl"
#include "/include/checker.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"
#include "/include/octree.glsl"
#include "/include/raytracing.glsl"
#include "/include/textureData.glsl"
#include "/include/brdf.glsl"
#include "/include/ircache.glsl"
#include "/include/atmosphere.glsl"

layout (local_size_x = 8, local_size_y = 8) in;
const ivec3 workGroups = ivec3(4, 4, 1);

void main ()
{
    vec2 uv = (gl_GlobalInvocationID.xy + 0.5) * rcp(32.0);
    vec3 rayDir = octDecode(uv);

    imageStore(imgSkyView, ivec2(gl_GlobalInvocationID.xy), vec4(calcSkyColor(rayDir, sunDir, 0.5), 1.0));
}

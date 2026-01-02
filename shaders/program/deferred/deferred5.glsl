#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"
#include "/include/textureSampling.glsl"

#include "/include/text.glsl"

/* RENDERTARGETS: 0 */
layout (location = 0) out vec4 normal;

void main () 
{   
    normal = vec4(0.0, 0.0, 0.0, 1.0);
    float depth = texelFetch(depthtex1, ivec2(gl_FragCoord.xy), 0).r;
    
    if (depth == 1.0) return;

    vec4 pos = gbufferModelViewProjectionInverse * vec4(vec3(gl_FragCoord.xy * texelSize, depth) * 2.0 - 1.0 - vec3(taaOffset, 0.0), 1.0);
    pos.xyz /= pos.w;

    vec3 geoNormal = octDecode(unpack2x8(texelFetch(colortex9, ivec2(gl_FragCoord.xy), 0).x >> 16u));

    normal = vec4(geoNormal * dot(pos.xyz, geoNormal), 1.0);
}
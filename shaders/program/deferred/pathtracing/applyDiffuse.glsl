#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"
#include "/include/textureSampling.glsl"
#include "/include/ircache.glsl"
#include "/include/atmosphere.glsl"
#include "/include/brdf.glsl"
#include "/include/spaceConversion.glsl"

#include "/include/text.glsl"

/* RENDERTARGETS: 7 */
layout (location = 0) out vec4 color;

void main ()
{   
    ivec2 texel = ivec2(gl_FragCoord.xy);
    float depth = texelFetch(depthtex1, texel, 0).r;
    
    color = vec4(0.0);

    if (depth == 1.0) return;

    DeferredMaterial mat = unpackMaterialData(texel);
    #ifdef DEBUG_IRC
        vec3 diffuseIrradiance = readIRC(screenToPlayerPos(vec3(gl_FragCoord.xy * texelSize, depth)).xyz, mat.geoNormal).diffuseIrradiance;
    #else
        vec3 diffuseIrradiance = texelFetch(colortex2, texel, 0).rgb;
    #endif

    if (mat.roughness <= REFLECTION_ROUGHNESS_THRESHOLD) diffuseIrradiance *= 1.0 - schlickFresnel(mat.F0, dot(mat.textureNormal, normalize(screenToPlayerPos(vec3(gl_FragCoord.xy * texelSize, 0.0)).xyz - screenToPlayerPos(vec3(gl_FragCoord.xy * texelSize, depth)).xyz)));

    color.rgb += mat.albedo.rgb * diffuseIrradiance;
}
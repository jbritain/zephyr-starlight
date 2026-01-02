#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"
#include "/include/textureSampling.glsl"
#include "/include/text.glsl"

/* RENDERTARGETS: 10 */
layout (location = 0) out vec4 color;

void main ()
{   
    vec2 start = gl_FragCoord.xy;
    vec2 end = mix(screenSize / 2.0, gl_FragCoord.xy, 500.0 / (500.0 + CHROMATIC_ABERRATION));

    vec3 integratedData = vec3(0.0);
    vec2 sampleDir = (end - start) * rcp(CHROMATIC_ABERRATION_SAMPLES);
    vec2 samplePos = start + sampleDir * blueNoise(gl_FragCoord.xy).r;

    for (int i = 0; i < CHROMATIC_ABERRATION_SAMPLES; i++, samplePos += sampleDir)
    {
        integratedData += texelFetch(colortex10, ivec2(samplePos), 0).rgb;
    }
    
    color = vec4(integratedData * rcp(CHROMATIC_ABERRATION_SAMPLES), 1.0);
}
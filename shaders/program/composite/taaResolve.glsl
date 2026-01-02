#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"
#include "/include/textureSampling.glsl"
#include "/include/spaceConversion.glsl"

#include "/include/text.glsl"

/* RENDERTARGETS: 6 */
layout (location = 0) out vec4 history;

void main ()
{   
    ivec2 srcTexel = ivec2(floor(TAAU_RENDER_SCALE * (gl_FragCoord.xy + R2(frameCounter & 255u) - 0.5)));
    vec2 dstTexel = floor(texelSize * screenSize * (vec2(srcTexel) + 0.5 - 0.5 * renderSize * taaOffset));

    vec4 currData = texelFetch(colortex7, srcTexel, 0);
    vec2 uv = gl_FragCoord.xy / screenSize;

    float depth = 1.0;

    for (int x = -1; x <= 1; x++) 
		for (int y = -1; y <= 1; y++)
			depth = min(depth, texelFetch(depthtex1, clamp(srcTexel + ivec2(x, y), ivec2(0), ivec2(renderSize) - 1), 0).r);

    vec4 currPos = screenToPlayerPos(vec3(uv, depth));
    vec4 prevPos = gbufferPreviousModelViewProjection * vec4(depth == 1.0 ? currPos.xyz : (currPos.xyz + cameraVelocity), 1.0);
    prevPos.xyz /= prevPos.w;

    vec3 prevUv = (prevPos.xyz + vec3(taaOffset, 0.0)) * 0.5 + 0.5;
    ivec2 prevTexel = ivec2(screenSize * prevUv.xy + 0.95 * (R2(frameCounter & 15) - 0.5));
    vec4 color = currData;

    if (saturate(prevUv.xyz) == prevUv.xyz && prevPos.w > 0.0) 
    {
        vec4 prevData = texelFetch(colortex6, prevTexel, 0);
        vec3 colorMin = vec3(INFINITY);
        vec3 colorMax = vec3(-INFINITY);

        for (int x = -1; x <= 1; x++) 
			for (int y = -1; y <= 1; y++) {
                vec3 sampleData = texelFetch(colortex7, clamp(srcTexel + ivec2(x, y), ivec2(0), ivec2(renderSize) - 1), 0).rgb;

				colorMin = min(colorMin, sampleData);
				colorMax = max(colorMax, sampleData);
            }

        if (!any(isnan(prevData)))
        {
            float sampleWeight = exp(-2.5 * lengthSquared(dstTexel - floor(gl_FragCoord.xy)));

            //exp(-(TAA_VARIANCE_WEIGHT * length(clamp(prevData.rgb, colorMin, colorMax) - prevData.rgb) + TAA_OFFCENTER_WEIGHT * length(fract(prevUv.xy * screenSize) - 0.5))) * 

            color = vec4(mix(currData.rgb, clamp(prevData.rgb, colorMin, colorMax), exp(-(TAA_VARIANCE_WEIGHT * length(clamp(prevData.rgb, colorMin, colorMax) - prevData.rgb) + TAA_OFFCENTER_WEIGHT * length(fract(prevUv.xy * screenSize) - 0.5))) * prevData.a / (prevData.a + sampleWeight)), 1.0);
            history = vec4(color.rgb, min(prevData.a + sampleWeight, TAA_ACCUMULATION_LIMIT));
        } else history = vec4(currData.rgb, TAA_ACCUMULATION_LIMIT);
    } else history = vec4(currData.rgb, 1.0);
}
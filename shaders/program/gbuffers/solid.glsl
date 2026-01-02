#ifdef fsh

#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"

in VSOUT
{
    vec2 texcoord;
    vec3 vertexColor;

    #ifdef NORMAL_MAPPING
        vec4 vertexTangent;
    #endif

    flat uint vertexNormal;
    flat uint blockId;
} vsout;

/* RENDERTARGETS: 8,9 */
layout (location = 0) out uvec4 colortex8Out;
layout (location = 1) out uvec4 colortex9Out;

void main ()
{
    if (any(greaterThan(gl_FragCoord.xy, screenSize))) discard;

    vec2 atlasTexCoord = vec2(textureSize(gtexture, 0)) * vsout.texcoord;

    float mipLevel = vsout.blockId == 6 ? 0.0 : max(0.0, TAA_MIP_BIAS * 0.5 * log2(max(lengthSquared(dFdx(atlasTexCoord)), lengthSquared(dFdy(atlasTexCoord)))));

    vec4 albedo = textureLod(gtexture, vsout.texcoord, mipLevel) * vec4(vsout.vertexColor, 1.0);

    #ifdef SPECULAR_MAPPING
        vec4 specularData = textureLod(specular, vsout.texcoord, 0.0);
    #else
        vec4 specularData = vec4(0.0, 0.0, 0.0, 1.0);
    #endif

    #ifdef NORMAL_MAPPING
        vec4 normalData = textureLod(normals, vsout.texcoord, mipLevel);
    #endif

    vec3 geoNormal = octDecode(unpack2x16(vsout.vertexNormal));

    if (!gl_FrontFacing) geoNormal *= -1.0;

    #ifdef NORMAL_MAPPING
        vec3 textureNormal = vec3(normalData.rg * 2.0 - 1.0, 1.0);
        textureNormal.z = sqrt(max(0.0, 1.0 - lengthSquared(textureNormal.xy)));
        textureNormal = tbnNormalTangent(geoNormal, vsout.vertexTangent) * textureNormal;
    #else
        vec3 textureNormal = geoNormal;
    #endif

    #ifdef IPBR
        applyIntegratedSpecular(albedo.rgb, specularData, ivec2(atlasSize * vsout.texcoord) & 15, vsout.blockId);
    #endif

    uvec4 packedData = packMaterialData(albedo.rgb, geoNormal, textureNormal, specularData, vsout.blockId, 
        #ifdef STAGE_HAND
            true
        #else
            false
        #endif
    );

    colortex8Out = packedData;
    colortex9Out = packedData.zwxy;

    if (albedo.a < 0.1) discard;
}

#endif

#ifdef vsh

attribute vec2 mc_Entity;
attribute vec4 at_tangent;

#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"
#include "/include/textureData.glsl"

out VSOUT
{
    vec2 texcoord;
    vec3 vertexColor;

    #ifdef NORMAL_MAPPING
        vec4 vertexTangent;
    #endif

    flat uint vertexNormal;
    flat uint blockId;
} vsout;

void main ()
{   
    gl_Position = ftransform();

    #ifdef STAGE_HAND   
        gl_Position.xy *= handScale / gl_ProjectionMatrix[1].y;
    #endif

    gl_Position.xy = mix(-gl_Position.ww, gl_Position.xy, TAAU_RENDER_SCALE);
    gl_Position.xy += gl_Position.w * taaOffset;

    vsout.texcoord = mat4x2(gl_TextureMatrix[0]) * gl_MultiTexCoord0;
    vsout.vertexColor = gl_Color.rgb;
    vsout.vertexNormal = pack2x16(octEncode(alignNormal(transpose(mat3(gbufferModelView)) * gl_NormalMatrix * gl_Normal, 0.008)));

    #ifdef NORMAL_MAPPING
        vsout.vertexTangent = vec4(alignNormal(mat3(gbufferModelViewInverse) * mat3(gl_ModelViewMatrix) * at_tangent.xyz, 0.025), at_tangent.w);
    #endif

    #ifdef STAGE_TERRAIN
        vsout.blockId = uint(mc_Entity.x);
    #else
        vsout.blockId = uint(currentRenderedItemId);
    #endif
}

#endif
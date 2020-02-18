// Toon Standard Shader
// Adrian Biagioli (github.com/Flafla2)
// See LICENSE.txt

#if defined(TOON_STANDARD_FWD_COMMON)
#error "Tried to define two toon fragment shaders at once"
#endif

#if !defined(TOON_TERRAIN_FWD_COMMON)
#define TOON_TERRAIN_FWD_COMMON

#define TOON_TERRAIN

#include "UnityCG.cginc"
#include "UnityPBSLighting.cginc"
#include "UnityShaderVariables.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"

#define SHOULD_USE_LIGHTMAPUV (defined(LIGHTMAP_ON) || ADDITIONAL_MASKED_DIRECTIONAL_SHADOWS)

struct v2f {
    float2 uv : TEXCOORD0;
    float3 normal : TEXCOORD1;
    float3 worldPos : TEXCOORD2;
    float4 pos : TEXCOORD3;
    #if defined(VERTEXLIGHT_ON)
        float3 vertexLightColor : TEXCOORD4;
    #endif
    UNITY_SHADOW_COORDS(5)
    UNITY_FOG_COORDS(6)
    #if SHOULD_USE_LIGHTMAPUV
        float2 lightmapUV : TEXCOORD7;
    #endif
    float3 tangent : TEXCOORD8;
    float3 binormal : TEXCOORD9;
};

// Include vertex shader
#include "../ToonStandardVertex.cginc"
// Include lighting utilities (brdf, etc)
#include "../ToonLighting.cginc"

sampler2D _Control;
float4 _Control_ST;
float4 _Control_TexelSize;
// Unity has a strict 16 sampler limit for all shaders. We run into this with the mask textures, so
// we need to use "Sampler states" to declare 4 samplers for the splat textures, and then share
// those samplers for each of the mask textures.
UNITY_DECLARE_TEX2D(_Splat0);
UNITY_DECLARE_TEX2D(_Splat1);
UNITY_DECLARE_TEX2D(_Splat2);
UNITY_DECLARE_TEX2D(_Splat3);
float4 _Splat0_ST, _Splat1_ST, _Splat2_ST, _Splat3_ST;
UNITY_DECLARE_TEX2D_NOSAMPLER(_Mask0);
UNITY_DECLARE_TEX2D_NOSAMPLER(_Mask1);
UNITY_DECLARE_TEX2D_NOSAMPLER(_Mask2);
UNITY_DECLARE_TEX2D_NOSAMPLER(_Mask3);
float4 _RimLighting;

#ifdef _NORMALMAP
    sampler2D _Normal0, _Normal1, _Normal2, _Normal3;
    float _NormalScale0, _NormalScale1, _NormalScale2, _NormalScale3;
#endif

half _Metallic0;
half _Metallic1;
half _Metallic2;
half _Metallic3;

half _Smoothness0;
half _Smoothness1;
half _Smoothness2;
half _Smoothness3;

void SplatmapMix(float2 uv, half4 defaultAlpha, out half4 splat_control, out half weight, 
                 out fixed4 mixedDiffuse, out fixed3 mixedNormal, out fixed4 mixedMask)
{
    // adjust splatUVs so the edges of the terrain tile lie on pixel centers
    float2 splatUV = (uv * (_Control_TexelSize.zw - 1.0f) + 0.5f) * _Control_TexelSize.xy;
    splat_control = tex2D(_Control, splatUV);
    weight = dot(splat_control, half4(1,1,1,1));

    #if defined(TERRAIN_SPLAT_ADDPASS)
        clip(weight == 0.0f ? -1 : 1);
    #endif

    // Normalize weights before lighting and restore weights in final modifier functions so
    // that the overall lighting result can be correctly weighted.
    splat_control /= (weight + 1e-3f);

    float2 uvSplat0 = TRANSFORM_TEX(uv.xy, _Splat0);
    float2 uvSplat1 = TRANSFORM_TEX(uv.xy, _Splat1);
    float2 uvSplat2 = TRANSFORM_TEX(uv.xy, _Splat2);
    float2 uvSplat3 = TRANSFORM_TEX(uv.xy, _Splat3);

    mixedDiffuse = 0.0f;
    mixedDiffuse += splat_control.r * UNITY_SAMPLE_TEX2D(_Splat0, uvSplat0) 
                                    * half4(1.0, 1.0, 1.0, defaultAlpha.r);
    mixedDiffuse += splat_control.g * UNITY_SAMPLE_TEX2D(_Splat1, uvSplat1) 
                                    * half4(1.0, 1.0, 1.0, defaultAlpha.g);
    mixedDiffuse += splat_control.b * UNITY_SAMPLE_TEX2D(_Splat2, uvSplat2) 
                                    * half4(1.0, 1.0, 1.0, defaultAlpha.b);
    mixedDiffuse += splat_control.a * UNITY_SAMPLE_TEX2D(_Splat3, uvSplat3) 
                                    * half4(1.0, 1.0, 1.0, defaultAlpha.a);

    mixedMask = 0.0f;
    mixedMask += splat_control.r * UNITY_SAMPLE_TEX2D_SAMPLER(_Mask0, _Splat0, uvSplat0);
    mixedMask += splat_control.g * UNITY_SAMPLE_TEX2D_SAMPLER(_Mask1, _Splat1, uvSplat1);
    mixedMask += splat_control.b * UNITY_SAMPLE_TEX2D_SAMPLER(_Mask2, _Splat2, uvSplat2);
    mixedMask += splat_control.a * UNITY_SAMPLE_TEX2D_SAMPLER(_Mask3, _Splat3, uvSplat3);

    mixedNormal = 0;
    #ifdef _NORMALMAP
        mixedNormal  = UnpackNormalWithScale(tex2D(_Normal0, uvSplat0), _NormalScale0) 
                        * splat_control.r;
        mixedNormal += UnpackNormalWithScale(tex2D(_Normal1, uvSplat1), _NormalScale1) 
                        * splat_control.g;
        mixedNormal += UnpackNormalWithScale(tex2D(_Normal2, uvSplat2), _NormalScale2) 
                        * splat_control.b;
        mixedNormal += UnpackNormalWithScale(tex2D(_Normal3, uvSplat3), _NormalScale3) 
                        * splat_control.a;
        mixedNormal.z += 1e-5f; // to avoid nan after normalizing
    #endif

}

fixed4 frag (
    v2f i,
    UNITY_VPOS_TYPE screenPos : VPOS
) : SV_Target {
    // These are the values passed in by the Terrain Layer system.  Note that we are forced
    // to use the interface given by Terrain Layers, namely "Diffuse, Normals" textures and
    // a "Mask" texture.  Then there is also a global "Specular" color, and sliders for 
    // "Metallic" and "Smoothness"

    float3 normals;
    half4 splat_control;
    half weight;
    fixed4 mixedDiffuse;
    half4 mixedMask;
    half4 defaultSmoothness = half4(_Smoothness0, _Smoothness1, _Smoothness2, _Smoothness3);
    SplatmapMix(i.uv, defaultSmoothness, splat_control, weight, mixedDiffuse, normals, mixedMask);
    half metallic = dot(splat_control, half4(_Metallic0, _Metallic1, _Metallic2, _Metallic3));
    ToonPixelData data;
    data.albedo.rgb = mixedDiffuse.rgb;
    //data.albedo.a = weight;
    data.albedo.a = mixedDiffuse.a;
    data.specular = mixedMask.rgb;
    data.worldPos = i.worldPos;

    data.worldNormal = normalize(
        normals.x * i.tangent  +
        normals.y * i.binormal +
        normals.z * i.normal
    );

    data.specGloss = metallic;
    data.specPower = mixedMask.a;
    data.rimLighting = _RimLighting;
    data.pos = i.pos;
    #if defined(VERTEXLIGHT_ON)
    data.vertexLightColor = i.vertexLightColor;
    #endif
    #if SHOULD_USE_SHADOWCOORD
    data._ShadowCoord = i._ShadowCoord;
    #endif
    #if SHOULD_USE_LIGHTMAPUV
    data.lightmapUV = i.lightmapUV;
    #endif
    
    fixed4 col = shadeToon(data);
    
    UNITY_APPLY_FOG(i.fogCoord, col);
    return col;
}

#endif // TOON_TERRAIN_FWD_COMMON
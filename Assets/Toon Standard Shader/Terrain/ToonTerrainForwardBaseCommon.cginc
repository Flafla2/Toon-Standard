// Toon Standard Shader
// Adrian Biagioli (github.com/Flafla2)
// See LICENSE.txt

#if defined(TOON_STANDARD_FWD_COMMON) || defined(TOON_TERRAIN_FWD_COMMON)
#error "Tried to define two toon fragment shaders at once"
#endif

#if !defined(TOON_TERRAIN_BASE_FWD_COMMON)
#define TOON_TERRAIN_BASE_FWD_COMMON

#define TOON_TERRAIN

#include "UnityCG.cginc"
#include "UnityPBSLighting.cginc"
#include "UnityShaderVariables.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"

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

sampler2D _MainTex;
sampler2D _MetallicTex;
sampler2D _MaskTex;
float4 _RimLighting;

fixed4 frag (
    v2f i,
    UNITY_VPOS_TYPE screenPos : VPOS
) : SV_Target {
    half4 diffuse = tex2D (_MainTex, i.uv);
    half metallic = tex2D (_MetallicTex, i.uv).r;
    half4 mask = tex2D (_MaskTex, i.uv);

    ToonPixelData data;
    data.albedo = diffuse;
    data.specular = mask.rgb;
    data.worldPos = i.worldPos;

    data.worldNormal = i.normal;

    data.specGloss = metallic;
    data.specPower = mask.a;
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

#endif // TOON_TERRAIN_BASE_FWD_COMMON
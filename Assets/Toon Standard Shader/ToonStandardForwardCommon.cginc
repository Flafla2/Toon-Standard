// Toon Standard Shader
// Adrian Biagioli (github.com/Flafla2)
// See LICENSE.txt

#if defined(TOON_TERRAIN_FWD_COMMON)
#error "Tried to define two toon fragment shaders at once"
#endif

#if !defined(TOON_STANDARD_FWD_COMMON)
#define TOON_STANDARD_FWD_COMMON

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
    float2 uv2 : TEXCOORD8;
    float3 tangent : TEXCOORD9;
    float3 binormal : TEXCOORD10;
};

// Include vertex shader
#include "ToonStandardVertex.cginc"
// Include lighting utilities (brdf, etc)
#include "ToonLighting.cginc"
// Include Uniforms
#include "ToonStandardUniforms.cginc"

fixed4 frag (
    v2f i,
    UNITY_VPOS_TYPE screenPos : VPOS
) : SV_Target {
    fixed4 mainColor = tex2D(_MainTex, i.uv) * _Color;
    fixed3 normals = UnpackScaleNormal(tex2D(_NormalMap, i.uv), _BumpScale);
    fixed4 specColor = tex2D(_SpecularTex, i.uv) * _SpecularColor;
        
    ToonPixelData data;
    data.albedo = mainColor;
    data.specular = specColor;
    data.worldPos = i.worldPos;

    data.worldNormal = normalize(
        normals.x * i.tangent  +
        normals.y * i.binormal +
        normals.z * i.normal
    );

    data.specGloss = _SpecularGloss;
    data.specPower = specColor.a;
    data.rimLighting = _RimLighting;
    data.pos = i.pos;
    #if DIFFUSE_WRAP_ON
        data.wrapAmount = _DiffuseWrapAmount;
    #endif
    #if defined(VERTEXLIGHT_ON)
        data.vertexLightColor = i.vertexLightColor;
    #endif
    #if SHOULD_USE_SHADOWCOORD
        data._ShadowCoord = i._ShadowCoord;
    #endif
    #if SHOULD_USE_LIGHTMAPUV
        data.lightmapUV = i.lightmapUV;
    #endif
    #if DAB_COORDS_UV2
        data.uv2 = i.uv2 * _DabsScale.xy;
    #endif
    data.uv = i.uv * _DabsScale.xy;
    
    fixed4 col = shadeToon(data);
    
    #if defined(FORWARD_BASE_PASS)
        fixed4 emission = tex2D(_EmissionTex, i.uv) * _EmissionColor;
        col += emission;
    #endif
    
    UNITY_APPLY_FOG(i.fogCoord, col);
    return col;
}

#endif // TOON_STANDARD_FWD_COMMON
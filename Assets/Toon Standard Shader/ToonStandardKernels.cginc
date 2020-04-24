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
    float2 uv2 : TEXCOORD8;
    float3 tangent : TEXCOORD9;
    float3 binormal : TEXCOORD10;
};

struct FragmentOutput {
    #if defined(DEFERRED_PASS)
        float4 gBuffer0 : SV_Target0;
        float4 gBuffer1 : SV_Target1;
        float4 gBuffer2 : SV_Target2;
        float4 gBuffer3 : SV_Target3;
    #else
        float4 color : SV_Target;
    #endif
};

// Include vertex shader
#include "ToonStandardVertex.cginc"
// Include lighting utilities (brdf, etc)
#include "ToonLighting.cginc"
// Include Uniforms
#include "ToonStandardUniforms.cginc"

FragmentOutput frag (
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
    #if DAB_COORDS_UV
        data.uv = i.uv * _DabsScale.xy;
    #elif DAB_COORDS_UV2
        data.uv2 = i.uv2 * _DabsScale.xy;
    #endif
    
    #if defined(FORWARD_BASE_PASS) || defined(DEFERRED_PASS)
        fixed4 emission = tex2D(_EmissionTex, i.uv) * _EmissionColor;
    #else
        fixed4 emission = 0;
    #endif
    
    FragmentOutput output;
    #if defined(DEFERRED_PASS)
        // Add fresnel term to deferred pass via emission channel
        float3 viewDir = normalize(_WorldSpaceCameraPos - data.worldPos);
        UnityIndirect indLight = CreateIndirectLight(data, viewDir);
        float fresnel = FRESNEL(viewDir, data.worldNormal, data.rimLighting.a);
        emission += float4(fresnel * data.rimLighting.rgb, 0);
        // Include diffuse ambient light in emission term.
        emission += float4(data.albedo.rgb * indLight.diffuse, 0);
        #if !defined(UNITY_HDR_ON)
			emission.rgb = exp2(-emission.rgb);
		#endif
    
        output.gBuffer0.rgb = data.albedo.rgb;
        output.gBuffer0.a = data.specGloss / 50;
        output.gBuffer1.rgb = data.specular.rgb;
        output.gBuffer1.a = data.specPower / 50;
        output.gBuffer2 = float4(data.worldNormal.xyz * 0.5 + 0.5, 1);
        output.gBuffer3 = emission;
    #else
        fixed4 col = shadeToon(data) + emission;
        UNITY_APPLY_FOG(i.fogCoord, col);
        output.color = col;
    #endif
    return output;
}

#endif // TOON_STANDARD_FWD_COMMON
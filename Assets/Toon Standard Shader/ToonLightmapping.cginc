// Toon Standard Shader
// Adrian Biagioli (github.com/Flafla2)
// See LICENSE.txt

#if !defined(TOON_LIGHTMAPPING_DEFINED)
#define TOON_LIGHTMAPPING_DEFINED

// Adapted from
// https://catlikecoding.com/unity/tutorials/rendering/part-16/

#include "UnityCG.cginc"
#include "UnityPBSLighting.cginc"
#include "UnityMetaPass.cginc"

struct appdata {
    float4 vertex : POSITION;
    float2 uv : TEXCOORD0;
    float2 uv1 : TEXCOORD1;
};

struct v2f {
    float4 pos : SV_POSITION;
    float4 uv : TEXCOORD0;
};

sampler2D _MainTex;
float4 _MainTex_ST;
float4 _Color;
sampler2D _SpecularTex;
float4 _SpecularTex_ST;
float4 _SpecularColor;
float _SpecularPower;
float _SpecularGloss;
float4 _EmissionTex_ST;
sampler2D _EmissionTex;
float4 _EmissionColor;

v2f vert (appdata v) {
    v2f i;
    v.vertex.xy = v.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;
    v.vertex.z = v.vertex.z > 0 ? 0.0001 : 0;
    
    i.pos = UnityObjectToClipPos(v.vertex);

    i.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
    return i;
}

float4 frag (v2f i) : SV_TARGET {
    UnityMetaInput surfaceData;
    
    fixed4 mainColor = tex2D(_MainTex, i.uv) * _Color;
    fixed4 specColor = tex2D(_SpecularTex, i.uv) * _SpecularColor;
    fixed4 emission = tex2D(_EmissionTex, i.uv) * _EmissionColor;
    
    #if ENERGY_CONSERVATION_ON
    float oneMinusReflectivity;
    mainColor.xyz = EnergyConservationBetweenDiffuseAndSpecular(
        mainColor.rgb, specColor.rgb, oneMinusReflectivity
    );
    #endif
    
    surfaceData.Emission = emission.rgb;
    surfaceData.Albedo = mainColor.rgb;
    surfaceData.SpecularColor = specColor.rgb;
    return UnityMetaFragment(surfaceData);
}

#endif // TOON_LIGHTMAPPING_DEFINED
// Toon Standard Shader
// Adrian Biagioli (github.com/Flafla2)
// See LICENSE.txt

#if !defined(TOON_SHADOWS_DEFINED)
#define TOON_SHADOWS_DEFINED

#include "UnityCG.cginc"

sampler2D   _MainTex;
float4      _MainTex_ST;

struct appdata {
    float4 position : POSITION;
    float3 normal : NORMAL;
};

// Adapted from
// https://catlikecoding.com/unity/tutorials/rendering/part-7/
#if defined(SHADOWS_CUBE) && !defined(SHADOWS_CUBE_IN_DEPTH_TEX)
struct v2f {
    float4 position : SV_POSITION;
    float3 lightVec : TEXCOORD0;
    float2 tex : TEXCOORD1;
};

v2f vert (appdata v) {
    v2f i;
    i.position = UnityObjectToClipPos(v.position);
    i.lightVec =
        mul(unity_ObjectToWorld, v.position).xyz - _LightPositionRange.xyz;
    return i;
}

float4 frag (v2f i) : SV_TARGET {
    float depth = length(i.lightVec) + unity_LightShadowBias.x;
    depth *= _LightPositionRange.w;
    return UnityEncodeCubeShadowDepth(depth);
}
#else
float4 vert (appdata i) : SV_POSITION {
    float4 pos = UnityClipSpaceShadowCasterPos(i.position.xyz, i.normal);
    return UnityApplyLinearShadowBias(pos);
}

half4 frag (float4 pos : SV_POSITION) : SV_TARGET {
    return 0;
}
#endif // SHADOWS_CUBE

#endif // TOON_SHADOWS_DEFINED
#if !defined(TOON_STANDARD_DEF_COMMON)
#define TOON_STANDARD_DEF_COMMON

#include "UnityPBSLighting.cginc"
#include "ToonLighting.cginc"

struct VertexData {
	float4 vertex : POSITION;
	float3 normal : NORMAL;
};

struct Interpolators {
	float4 pos : SV_POSITION;
	float4 uv : TEXCOORD0;
	float3 ray : TEXCOORD1;
};

float _LightAsQuad;

Interpolators vert_deferred (VertexData v) {
	Interpolators i;
	i.pos = UnityObjectToClipPos(v.vertex);
	i.uv = ComputeScreenPos(i.pos);
	i.ray = lerp(
		UnityObjectToViewPos(v.vertex) * float3(-1, -1, 1),
		v.normal,
		_LightAsQuad
	);
	return i;
}

UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

sampler2D _CameraGBufferTexture0;
sampler2D _CameraGBufferTexture1;
sampler2D _CameraGBufferTexture2;

float4 frag_deferred (Interpolators i) : SV_Target {
	float2 uv = i.uv.xy / i.uv.w;

	//return tex2D(_LightRamp, uv);

	float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv);
	depth = Linear01Depth(depth);

	float3 rayToFarPlane = i.ray * _ProjectionParams.z / i.ray.z;
	float3 viewPos = rayToFarPlane * depth;
	float3 worldPos = mul(unity_CameraToWorld, float4(viewPos, 1)).xyz;

	float3 albedo = tex2D(_CameraGBufferTexture0, uv).rgb;
	float3 specular = tex2D(_CameraGBufferTexture1, uv).rgb;
	float3 specPower = tex2D(_CameraGBufferTexture1, uv).a;
	float3 specGloss = tex2D(_CameraGBufferTexture0, uv).a;
	float3 normal = tex2D(_CameraGBufferTexture2, uv).rgb * 2 - 1;

	ToonPixelData data;
	data.albedo = float4(albedo, 1);
	data.specular = float4(specular, 1);
	data.worldPos = worldPos;
	data.worldNormal = normal;
	data.specGloss = specGloss * 50;
	data.specPower = specPower * 50;
	data.uv = uv;

	float3 color = shadeToon(data, viewPos);
	
	#if !defined(UNITY_HDR_ON)
        color.rgb = exp2(-color.rgb);
    #endif

	return float4(color, 1);
	//return float4(emission, 1);
}

#endif // TOON_STANDARD_DEF_COMMON

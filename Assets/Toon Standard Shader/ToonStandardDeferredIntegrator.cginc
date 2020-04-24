#if !defined(TOON_STANDARD_DEF_COMMON)
#define TOON_STANDARD_DEF_COMMON

#include "UnityPBSLighting.cginc"

struct VertexData {
	float4 vertex : POSITION;
	float3 normal : NORMAL;
};

struct Interpolators {
	float4 pos : SV_POSITION;
	float4 uv : TEXCOORD0;
	float3 ray : TEXCOORD1;
};

struct ToonPixelData {
    fixed4 albedo;
    fixed4 specular;
    float4 pos;
    float3 worldPos;
    float3 worldNormal;
    
    float specGloss;
    float specPower;

    float2 uv;
};

float4 _LightColor, _LightDir, _LightPos;
float _LightAsQuad;

#if defined(POINT_COOKIE)
	samplerCUBE _LightTexture0;
#else
	sampler2D _LightTexture0;
#endif
sampler2D _LightTextureB0;

#if defined (SHADOWS_SCREEN)
	sampler2D _ShadowMapTexture;
#endif

// Light Ramp Logic //

sampler2D _LightRamp;

sampler2D _SpecularDabsTex;
float4 _SpecularDabsTex_TexelSize;
float4x4 _InvSpecularDabsTransform;
float4 _RampIntegral;

float lightingRamp(in float inLight) {
    return tex2Dlod(_LightRamp, float4(inLight, 0.0, 0.0, 0.0));
}

float3 colorLightingRamp(in float3 inColor) {
    //float luminance = dot(inColor, unity_ColorSpaceLuminance);
    float luminance = max(inColor.x, max(inColor.y, inColor.z));
    float ramp = lightingRamp(luminance);
    
    if (luminance < 0.001) {
        return ramp.xxx;
    }
    
    float scale = ramp / luminance;
    return inColor * scale;
}


UnityLight CreateLight (float2 uv, float3 worldPos, float viewZ) {
	UnityLight light;
	float attenuation = 1;
	float shadowAttenuation = 1;
	bool shadowed = false;

	#if defined(DIRECTIONAL) || defined(DIRECTIONAL_COOKIE)
		light.dir = -_LightDir;

		#if defined(DIRECTIONAL_COOKIE)
			float2 uvCookie = mul(unity_WorldToLight, float4(worldPos, 1)).xy;
			attenuation *= tex2Dbias(_LightTexture0, float4(uvCookie, 0, -8)).w;
		#endif

		#if defined(SHADOWS_SCREEN)
			shadowed = true;
			shadowAttenuation = tex2D(_ShadowMapTexture, uv).r;
		#endif
	#else
		float3 lightVec = _LightPos.xyz - worldPos;
		light.dir = normalize(lightVec);

		attenuation *= tex2D(
			_LightTextureB0,
			(dot(lightVec, lightVec) * _LightPos.w).rr
		).UNITY_ATTEN_CHANNEL;

		#if defined(SPOT)
			float4 uvCookie = mul(unity_WorldToLight, float4(worldPos, 1));
			uvCookie.xy /= uvCookie.w;
			attenuation *=
				tex2Dbias(_LightTexture0, float4(uvCookie.xy, 0, -8)).w;
			attenuation *= uvCookie.w < 0;

			#if defined(SHADOWS_DEPTH)
				shadowed = true;
				shadowAttenuation = UnitySampleShadowmap(
					mul(unity_WorldToShadow[0], float4(worldPos, 1))
				);
			#endif
		#else
			#if defined(POINT_COOKIE)
				float3 uvCookie =
					mul(unity_WorldToLight, float4(worldPos, 1)).xyz;
				attenuation *=
					texCUBEbias(_LightTexture0, float4(uvCookie, -8)).w;
			#endif
			
			#if defined(SHADOWS_CUBE)
				shadowed = true;
				shadowAttenuation = UnitySampleShadowmap(-lightVec);
			#endif
		#endif
	#endif

	if (shadowed) {
		float shadowFadeDistance =
			UnityComputeShadowFadeDistance(worldPos, viewZ);
		float shadowFade = UnityComputeShadowFade(shadowFadeDistance);
		shadowAttenuation = saturate(shadowAttenuation + shadowFade);

		#if defined(UNITY_FAST_COHERENT_DYNAMIC_BRANCHING) && defined(SHADOWS_SOFT)
			UNITY_BRANCH
			if (shadowFade > 0.99) {
				shadowAttenuation = 1;
			}
		#endif
	}

	light.color = _LightColor.rgb * (attenuation * shadowAttenuation);
	return light;
}

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

fixed4 shadeToon ( ToonPixelData d, float3 viewPos ) {
    float reflectivity = SpecularStrength(d.specular);
    float oneMinusReflectivity = 1 - reflectivity;
    d.albedo.rgb = min(d.albedo.rgb, oneMinusReflectivity);
    
    UnityLight light = CreateLight(d.uv, d.worldPos, viewPos.z);
    
    // Diffuse + optional half diffuse for base color
    // Blinn/Phong for Specular
    // https://www.jordanstevenstechart.com/lighting-models
    float3 viewDir = normalize(_WorldSpaceCameraPos - d.worldPos);
    float3 halfDir = normalize(viewDir + light.dir);
    
    float ndotl = saturate(dot(light.dir, d.worldNormal));
    
    float ndotv = saturate(dot(halfDir, d.worldNormal));
    
    float3 basisPos = d.worldPos;
    float plateau = 0.0;
    float3 nblend = saturate(abs(d.worldNormal) - plateau.xxx);
    nblend = normalize(pow(nblend, 5));
    float2 coord1 = mul(_InvSpecularDabsTransform, float4(basisPos.yz, 0, 0)).xy;
    float2 coord2 = mul(_InvSpecularDabsTransform, float4(basisPos.zx, 0, 0)).xy;
    float2 coord3 = mul(_InvSpecularDabsTransform, float4(basisPos.xy, 0, 0)).xy;
    float col1 = tex2D(_SpecularDabsTex, coord1).a;
    float col2 = tex2D(_SpecularDabsTex, coord2).a;
    float col3 = tex2D(_SpecularDabsTex, coord3).a;
    float specDabs = 
        col1 * nblend.x +
        col2 * nblend.y +
        col3 * nblend.z;
    
    float specPow = d.specGloss * 100;
    fixed3 specular = saturate(pow(ndotv, specPow)) * d.specPower * light.color * d.specular * specDabs;
    
    // http://www.rorydriscoll.com/2009/01/25/energy-conservation-in-games/
    // Note: technically we would have to divide by pi as well, but since Unity
    //       omits the constant pi term in its shaders I do this as well to stay
    //       consistent with the Standard shader.
    specular = specular * (specPow + 8.0) / 8.0;

    ndotl = lightingRamp(saturate(ndotl));
    
    float3 reflectionDir = reflect(-viewDir, d.worldNormal);
    Unity_GlossyEnvironmentData envData;
    envData.roughness = 1 - d.albedo.a;
    envData.reflUVW = reflectionDir;
    fixed3 indirectSpecular = Unity_GlossyEnvironment(
        UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, envData
    );
    
    // Note: Rim lighting is added in the emission term
    specular += indirectSpecular * (d.specular.rgb * reflectivity);
    // Obey energy conservation in the diffuse term (integral of brdf = 1)
    ndotl /= _RampIntegral;

    //float3 diffuse = d.albedo.rgb * (light.color * ndotl + indLight.diffuse);
    float3 diffuse = d.albedo.rgb * (light.color * ndotl);
    
    return fixed4(specular + diffuse, 1.0);
}

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

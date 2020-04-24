// Toon Standard Shader
// Adrian Biagioli (github.com/Flafla2)
// See LICENSE.txt

#if !defined(TOON_LIGHTING_DEFINED)
#define TOON_LIGHTING_DEFINED

#include "UnityCG.cginc"
#include "UnityPBSLighting.cginc"
#include "UnityShaderVariables.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"

// Macro Management //

// https://catlikecoding.com/unity/tutorials/rendering/part-17/
#if !defined(LIGHTMAP_ON) && defined(SHADOWS_SCREEN)
    #if defined(SHADOWS_SHADOWMASK) && !defined(UNITY_NO_SCREENSPACE_SHADOWS)
        //#define ADDITIONAL_MASKED_DIRECTIONAL_SHADOWS 1
    #endif
#endif

#if defined(DEFERRED_PASS)
    #undef DIFFUSE_WRAP_ON
    #undef DAB_COORDS_UV
    #undef DAB_COORDS_UV2
    #define DAB_COORDS_TRIPLANAR
#endif

// Derived from unity shader source
// AutoLight.cginc:123
#define SHOULD_USE_SHADOWCOORD (defined(SHADOWS_SCREEN) || defined(SHADOWS_SHADOWMASK))
#define SHOULD_USE_LIGHTMAPUV (defined(LIGHTMAP_ON) || ADDITIONAL_MASKED_DIRECTIONAL_SHADOWS)

struct ToonPixelData {
    fixed4 albedo;
    fixed3 specular;
    float4 pos;
    float3 worldPos;
    float3 worldNormal;
    
    float specGloss;
    float specPower;
    fixed4 rimLighting;
    
    #if defined(DEFERRED_PASS)
        float2 uv;
    #else
        #if DIFFUSE_WRAP_ON
            float wrapAmount;
        #endif
        #if defined(VERTEXLIGHT_ON)
            float3 vertexLightColor;
        #endif
        #if SHOULD_USE_SHADOWCOORD
            unityShadowCoord4 _ShadowCoord;
        #endif
        #if SHOULD_USE_LIGHTMAPUV
            float2 lightmapUV;
        #endif
        #if DAB_COORDS_UV
            float2 uv;
        #elif DAB_COORDS_UV2
            float2 uv2;
        #endif
    #endif // DEFERRED_PASS
};

// Light Ramp Logic //

#if defined(DEFERRED_PASS)
    float4 _LightColor, _LightDir, _LightPos;
    
    sampler2D _LightTextureB0;
#endif

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

// Lighting Utils //

// https://catlikecoding.com/unity/tutorials/rendering/part-5/
#if defined(DEFERRED_PASS)
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
#else
UnityLight CreateLight (in ToonPixelData i) {
    UnityLight light;
    
    #if defined(DEFERRED_PASS)
        light.dir = float3(0, 1, 0);
        light.color = 0;
    #else
        #if defined(POINT) || defined(POINT_COOKIE) || defined(SPOT)
            light.dir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos);
        #else
            light.dir = _WorldSpaceLightPos0.xyz;
        #endif
        
        UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos);
        light.color = _LightColor0.rgb * attenuation;
    #endif
    return light;
}
#endif // DEFERRED_PASS

// https://catlikecoding.com/unity/tutorials/rendering/part-5/
UnityIndirect CreateIndirectLight (in ToonPixelData i, in float3 viewDir) {
    UnityIndirect indirectLight;
    indirectLight.diffuse = 0;
    indirectLight.specular = 0;
    
    #if defined(VERTEXLIGHT_ON)
        indirectLight.diffuse = i.vertexLightColor;
    #endif
        
    #if defined(FORWARD_BASE_PASS) || defined(DEFERRED_PASS)
        #if defined(LIGHTMAP_ON)
            float3 lightmap = DecodeLightmap(
                UNITY_SAMPLE_TEX2D(unity_Lightmap, i.lightmapUV)
            );
            indirectLight.diffuse += colorLightingRamp(lightmap);
        #endif
        
        // TODO: maybe shouldn't apply shadesh9 in deferred?
        indirectLight.diffuse += max(0, ShadeSH9(float4(i.worldNormal, 1)));

        float3 reflectionDir = reflect(-viewDir, i.worldNormal);
        Unity_GlossyEnvironmentData envData;
        envData.roughness = 1 - i.albedo.a;
        envData.reflUVW = reflectionDir;
        indirectLight.specular = Unity_GlossyEnvironment(
            UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, envData
        );
    #endif
    return indirectLight;
}


// Shading Logic //

#define FRESNEL(VIEW_DIR, WORLD_NORMAL, RIM_POWER) (1 - saturate(pow(saturate(dot(VIEW_DIR, WORLD_NORMAL) /3 ), RIM_POWER / 10)))

#if defined(DEFERRED_PASS)
fixed4 shadeToon ( ToonPixelData d, float3 viewPos ) {
#else
fixed4 shadeToon ( ToonPixelData d ) {
#endif
    // float oneMinusReflectivity;
    // d.albedo.rgb = EnergyConservationBetweenDiffuseAndSpecular(
    //     d.albedo, d.specular, oneMinusReflectivity
    // );
    //d.specPower = 1.0; // specular power breaks energy conservation
    float reflectivity = SpecularStrength(d.specular);
    float oneMinusReflectivity = 1 - reflectivity;
    d.albedo.rgb = min(d.albedo.rgb, oneMinusReflectivity);
    
    #if defined(DEFERRED_PASS)
        UnityLight light = CreateLight(d.uv, d.worldPos, viewPos.z);
    #else
        UnityLight light = CreateLight(d);
    #endif
    
    float3 viewDir = normalize(_WorldSpaceCameraPos - d.worldPos);
    UnityIndirect indLight = CreateIndirectLight(d, viewDir);
    
    // Diffuse + optional half diffuse for base color
    // Blinn/Phong for Specular
    // https://www.jordanstevenstechart.com/lighting-models
    float3 halfDir = normalize(viewDir + light.dir);
    
    float ndotl = saturate(dot(light.dir, d.worldNormal));
    #if DIFFUSE_WRAP_ON && !defined(DEFERRED_PASS)
        ndotl = pow(ndotl * d.wrapAmount + (1.0 - d.wrapAmount), 2);
    #endif
    
    float ndotv = saturate(dot(halfDir, d.worldNormal));
    
    #if DAB_COORDS_UV
    float specDabs = tex2D(_SpecularDabsTex, d.uv).a;
    #elif DAB_COORDS_UV2
    float specDabs = tex2D(_SpecularDabsTex, d.uv2).a;
    #else // DAB_COORDS_TRIPLANAR
    // Triplanar must be used in deferred rendering
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
    #endif

    float specPow = d.specGloss * 100;
    fixed3 specular = saturate(pow(ndotv, specPow)) * d.specPower * light.color * d.specular * specDabs;

    // http://www.rorydriscoll.com/2009/01/25/energy-conservation-in-games/
    // Note: technically we would have to divide by pi as well, but since Unity
    //       omits the constant pi term in its shaders I do this as well to stay
    //       consistent with the Standard shader.
    specular = specular * (specPow + 8.0) / 8.0;
    
    ndotl = lightingRamp(ndotl);
    // Obey energy conservation in the diffuse term (integral of brdf = 1)
    ndotl /= _RampIntegral;
    
    specular += indLight.specular * d.specular.rgb * reflectivity;

    #if defined(DEFERRED_PASS)
        // Note: Rim lighting is added in the emission term
        float3 diffuse = d.albedo.rgb * (light.color * ndotl);
        return fixed4(specular + diffuse, 1.0);
    #else
        float fresnel = FRESNEL(viewDir, d.worldNormal, d.rimLighting.a);
        fixed3 diffuse = d.albedo.rgb * (light.color * ndotl + indLight.diffuse);
        return fixed4(specular + diffuse + d.rimLighting.rgb * fresnel, 1.0);
    #endif
}

#endif // TOON_LIGHTING_DEFINED
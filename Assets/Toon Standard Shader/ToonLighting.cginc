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

// Derived from unity shader source
// AutoLight.cginc:123
#define SHOULD_USE_SHADOWCOORD (defined(SHADOWS_SCREEN) || defined(SHADOWS_SHADOWMASK))
#define SHOULD_USE_LIGHTMAPUV (defined(LIGHTMAP_ON) || ADDITIONAL_MASKED_DIRECTIONAL_SHADOWS)

struct ToonPixelData {
    fixed4 albedo;
    fixed3 specular;
    fixed4 rimLighting;
    float4 pos;
    float3 worldPos;
    float3 worldNormal;
    
    float specGloss;
    float specPower;
    
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
};

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

// Lighting Utils //

// https://catlikecoding.com/unity/tutorials/rendering/part-5/
UnityLight CreateLight (in ToonPixelData i) {
    UnityLight light;
    
    #if defined(POINT) || defined(POINT_COOKIE) || defined(SPOT)
        light.dir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos);
    #else
        light.dir = _WorldSpaceLightPos0.xyz;
    #endif
    
    UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos);
    light.color = _LightColor0.rgb * attenuation;
    return light;
}

// https://catlikecoding.com/unity/tutorials/rendering/part-5/
UnityIndirect CreateIndirectLight (in ToonPixelData i, in float3 viewDir) {
    UnityIndirect indirectLight;
    indirectLight.diffuse = 0;
    indirectLight.specular = 0;

    #if defined(VERTEXLIGHT_ON)
        indirectLight.diffuse = i.vertexLightColor;
    #endif
    
    #if defined(FORWARD_BASE_PASS)
        #if defined(LIGHTMAP_ON)
            float3 lightmap = DecodeLightmap(
                UNITY_SAMPLE_TEX2D(unity_Lightmap, i.lightmapUV)
            );
            indirectLight.diffuse += colorLightingRamp(lightmap);
        #endif
        
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

fixed4 shadeToon ( ToonPixelData d ) {
    // float oneMinusReflectivity;
    // d.albedo.rgb = EnergyConservationBetweenDiffuseAndSpecular(
    //     d.albedo, d.specular, oneMinusReflectivity
    // );
    //d.specPower = 1.0; // specular power breaks energy conservation
    float reflectivity = SpecularStrength(d.specular);
    float oneMinusReflectivity = 1 - reflectivity;
    d.albedo.rgb = min(d.albedo.rgb, oneMinusReflectivity);

    float3 viewDir = normalize(_WorldSpaceCameraPos - d.worldPos);
    
    UnityLight light = CreateLight(d);
    UnityIndirect indLight = CreateIndirectLight(d, viewDir);
    
    // Diffuse + optional half diffuse for base color
    // Blinn/Phong for Specular
    // https://www.jordanstevenstechart.com/lighting-models
    float3 halfDir = normalize(viewDir + light.dir);
    
    float ndotl = saturate(dot(light.dir, d.worldNormal));
    #if DIFFUSE_WRAP_ON
    //ndotl = pow(ndotl * 0.5 + 0.5, 2.0);
    ndotl = pow(ndotl * d.wrapAmount + (1.0 - d.wrapAmount), 2);
    #endif
    
    float ndotv = saturate(dot(halfDir, d.worldNormal));
    
    #if DAB_COORDS_UV
    float specDabs = tex2D(_SpecularDabsTex, d.uv).a;
    #elif DAB_COORDS_UV2
    float specDabs = tex2D(_SpecularDabsTex, d.uv2).a;
    #else // DAB_COORDS_TRIPLANAR
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
    float3 specular = pow(ndotv, specPow) * d.specPower * light.color * d.specular * specDabs;
    
    ndotl = lightingRamp(ndotl);

    // http://www.rorydriscoll.com/2009/01/25/energy-conservation-in-games/
    // Note: technically we would have to divide by pi as well, but since Unity
    //       omits the constant pi term in its shaders I do this as well to stay
    //       consistent with the Standard shader.
    specular = specular * (specPow + 8.0) / 8.0;

    float grazing = saturate(d.albedo.a + (1 - oneMinusReflectivity));
    float fresnel = saturate(1 - pow(dot(viewDir, d.worldNormal), 1/((1-0.9*d.rimLighting.a) * 10)));

    specular += indLight.specular * (d.specular.rgb * reflectivity + d.rimLighting * fresnel);

    // Obey energy conservation in the diffuse term (integral of brdf = 1)
    ndotl /= _RampIntegral;

    float3 diffuse = d.albedo.rgb * (light.color * ndotl + indLight.diffuse);
    
    return fixed4(specular + diffuse, 1.0);
}

#endif // TOON_LIGHTING_DEFINED
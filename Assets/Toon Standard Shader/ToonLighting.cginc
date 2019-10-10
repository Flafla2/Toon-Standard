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
#define SHOULD_USE_SHADOWCOORD defined(SHADOWS_SCREEN) || defined(SHADOWS_SHADOWMASK)
#define SHOULD_USE_LIGHTMAPUV defined(LIGHTMAP_ON) || ADDITIONAL_MASKED_DIRECTIONAL_SHADOWS


// Shader Structs //

struct appdata {
    float4 vertex : POSITION;
    float4 normal : NORMAL;
    float4 tangent : TANGENT;
    float2 uv : TEXCOORD0;
    float2 uv2 : TEXCOORD1;
};

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

struct ToonPixelData {
    fixed4 albedo;
    fixed4 specular;
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
    float2 uv;
    #if DAB_COORDS_UV2
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
UnityIndirect CreateIndirectLight (in ToonPixelData i) {
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
    #endif
    
    return indirectLight;
}


// Shading Logic //

fixed4 shadeToon ( ToonPixelData d ) {
    #if ENERGY_CONSERVATION_ON
    float oneMinusReflectivity;
    d.albedo.xyz = EnergyConservationBetweenDiffuseAndSpecular(
        d.albedo, d.specular, oneMinusReflectivity
    );
    d.specPower = 1.0; // specular power breaks energy conservation
    #endif
    
    UnityLight light = CreateLight(d);
    UnityIndirect indLight = CreateIndirectLight(d);
    
    // Diffuse + optional half diffuse for base color
    // Blinn/Phong for Specular
    // https://www.jordanstevenstechart.com/lighting-models
    float3 viewDir = normalize(_WorldSpaceCameraPos - d.worldPos);
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

    #if ENERGY_CONSERVATION_ON
    // http://www.rorydriscoll.com/2009/01/25/energy-conservation-in-games/
    // Note: technically we would have to divide by pi as well, but since Unity
    //       omits the constant pi term in its shaders I do this as well to stay
    //       consistent with the Standard shader.
    specular = specular * (specPow + 8.0) / 8.0;
    ndotl /= _RampIntegral;
    #endif

    float3 diffuse = d.albedo.rgb * (light.color * ndotl + indLight.diffuse);
    
    return fixed4(specular + diffuse, 1.0);
}

// Shader Imports //

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
float4 _DabsScale;
sampler2D _NormalMap;
float _BumpScale;

#if DIFFUSE_WRAP_ON
float _DiffuseWrapAmount = 0.5;
#endif

// Vertex / Fragment Shader //

// https://catlikecoding.com/unity/tutorials/rendering/part-5/
void ComputeVertexLightColor (v2f i) {
    #if defined(VERTEXLIGHT_ON)
        i.vertexLightColor = Shade4PointLights(
            unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
            unity_LightColor[0].rgb, unity_LightColor[1].rgb,
            unity_LightColor[2].rgb, unity_LightColor[3].rgb,
            unity_4LightAtten0, i.worldPos, i.normal
        );
    #endif
}

v2f vert (
    appdata v,
    out float4 outworldPos : SV_POSITION
) {
    v2f o;
    UNITY_INITIALIZE_OUTPUT(v2f, o);
    
    outworldPos = UnityObjectToClipPos(v.vertex);
    o.uv = TRANSFORM_TEX(v.uv, _MainTex);
    #if SHOULD_USE_LIGHTMAPUV
        o.lightmapUV = v.uv2 * unity_LightmapST.xy + unity_LightmapST.zw;
    #endif

    // https://catlikecoding.com/unity/tutorials/rendering/part-6/
    o.normal = UnityObjectToWorldNormal(v.normal);
    o.tangent = UnityObjectToWorldDir(v.tangent.xyz);
    o.binormal = cross(o.normal.xyz, o.tangent.xyz) * (v.tangent.w * unity_WorldTransformParams.w);

    o.worldPos = mul(unity_ObjectToWorld, v.vertex);
    o.pos = UnityObjectToClipPos(v.vertex);
    ComputeVertexLightColor(o);
    UNITY_TRANSFER_FOG(o,outworldPos);
    UNITY_TRANSFER_SHADOW(o, v.uv2);
    #if DAB_COORDS_UV2
    o.uv2 = v.uv2;
    #endif
    return o;
}

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
    data.specPower = _SpecularPower;
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

#endif // TOON_LIGHTING_DEFINED
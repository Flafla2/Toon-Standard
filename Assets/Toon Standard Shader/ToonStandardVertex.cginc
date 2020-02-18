// Toon Standard Shader
// Adrian Biagioli (github.com/Flafla2)
// See LICENSE.txt

#if !defined(TOON_STANDARD_VERTEX)
#define TOON_STANDARD_VERTEX

/* Toon Standard Vertex shader.
 * Interface:
 * v2f vert(...);
 *      Vertex shader as consumed by Unity.
 * 
 * Expected defines:
 * TOON_TERRAIN:
 *      Define if this is the terrain shader and we are dealing with a terrain mesh
 * VERTEXLIGHT_ON:
 *      Define if vertex lighting is enabled
 * SHOULD_USE_LIGHTMAPUV:
 *      Set to 1 if the lightmap UVs are needed in the fragment shader.  In this case, expects a
 *      field `lightmapUV` in the v2f struct.
 */

#include "UnityCG.cginc"
// Need _MainTex_ST variable in vertex shader for non-terrain
#if !defined(TOON_TERRAIN)
    #include "ToonStandardUniforms.cginc"
#endif

// https://catlikecoding.com/unity/tutorials/rendering/part-5/
void ComputeVertexLightColor (inout v2f i) {
    #if defined(VERTEXLIGHT_ON)
        i.vertexLightColor = Shade4PointLights(
            unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
            unity_LightColor[0].rgb, unity_LightColor[1].rgb,
            unity_LightColor[2].rgb, unity_LightColor[3].rgb,
            unity_4LightAtten0, i.worldPos, i.normal
        );
    #endif
}

struct appdata {
    float4 vertex : POSITION;
    float4 normal : NORMAL;
    float2 uv : TEXCOORD0;
    #if !defined(TOON_TERRAIN)
        float4 tangent : TANGENT;
    #endif
    float2 uv2 : TEXCOORD1;
};

v2f vert (
    appdata v,
    out float4 outworldPos : SV_POSITION
) {
    v2f o;
    UNITY_INITIALIZE_OUTPUT(v2f, o);
    
    outworldPos = UnityObjectToClipPos(v.vertex);
    #if defined(TOON_TERRAIN)
        o.uv = v.uv;
    #else
        o.uv = TRANSFORM_TEX(v.uv, _MainTex);
    #endif
    #if SHOULD_USE_LIGHTMAPUV
        o.lightmapUV = v.uv2 * unity_LightmapST.xy + unity_LightmapST.zw;
    #endif

    // https://catlikecoding.com/unity/tutorials/rendering/part-6/
    o.normal = UnityObjectToWorldNormal(v.normal);
    #if defined(TOON_TERRAIN)
        o.tangent = cross(o.normal, float3(0,0,1));
        o.binormal = cross(o.normal.xyz, o.tangent.xyz) 
                        * (-1 * unity_WorldTransformParams.w);
    #else
        o.tangent = UnityObjectToWorldDir(v.tangent.xyz);
        o.binormal = cross(o.normal.xyz, o.tangent.xyz) 
                        * (v.tangent.w * unity_WorldTransformParams.w);
    #endif
    
    o.worldPos = mul(unity_ObjectToWorld, v.vertex);
    o.pos = UnityObjectToClipPos(v.vertex);
    
    ComputeVertexLightColor(o);
    UNITY_TRANSFER_FOG(o,outworldPos);
    UNITY_TRANSFER_SHADOW(o, v.uv2);
    
    #if DAB_COORDS_UV2 && !defined(TOON_TERRAIN)
        o.uv2 = v.uv2;
    #endif
    return o;
}

#endif // TOON_STANDARD_VERTEX

// Toon Standard Shader
// Adrian Biagioli (github.com/Flafla2)
// See LICENSE.txt

#if !defined(TOON_STANDARD_UNIFORMS)
#define TOON_STANDARD_UNIFORMS

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
float4 _RimLighting;
sampler2D _NormalMap;
float _BumpScale;

#if DIFFUSE_WRAP_ON
    float _DiffuseWrapAmount = 0.5;
#endif

#endif // TOON_STANDARD_UNIFORMS
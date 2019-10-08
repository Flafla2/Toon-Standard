// Toon Standard Shader
// Adrian Biagioli (github.com/Flafla2)
// See LICENSE.txt

Shader "Toon Standard"
{
    Properties
    {
        _MainTex ("Main Color", 2D) = "white" {}
        [NoScaleOffset] _NormalMap ("Normal Map", 2D) = "bump" {}
        _Color ("Tint", Color) = (1,1,1,1)
        
        _SpecularTex ("Specular Color", 2D) = "white" {}
        _SpecularColor ("Specular Tint", Color) = (1,1,1,1)
        _SpecularGloss ("Specular Gloss", Range(0.1, 1.0)) = 0.1
        _SpecularPower ("Specular Power", Float) = 1.0
                
        _EmissionTex ("Emission", 2D) = "white" {}
        _EmissionColor ("Emission Tint", Color) = (0,0,0)

        _DabsScale ("Specular Dabs Scale", Vector) = (1,1,1,1)
        _BumpScale ("Normal Map Scale", Float) = 1.0
    }
    CustomEditor "ToonStandardEditor"
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200
        
        Pass {
            Tags {
                "LightMode" = "ForwardBase"
            }
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0
            
            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog
            #pragma multi_compile _ VERTEXLIGHT_ON
            #pragma multi_compile _ SHADOWS_SCREEN
            #pragma multi_compile _ LIGHTMAP_ON
            
            // Use "Half Lambert" / Valve shading for the diffuse map
            #pragma multi_compile DIFFUSE_WRAP_ON DIFFUSE_WRAP_OFF
            // Conserve energy for specular surfaces (more specular => darker albedo)
            #pragma multi_compile ENERGY_CONSERVATION_ON ENERGY_CONSERVATION_OFF
            #pragma multi_compile DAB_COORDS_TRIPLANAR DAB_COORDS_UV DAB_COORDS_UV2
            
            #include "ToonMultiCompiles.cginc"
            
            #define FORWARD_BASE_PASS
            
            #include "ToonLighting.cginc"
            
            ENDCG
        }
        
        Pass {
            Tags {
                "LightMode" = "ForwardAdd"
            }
            
            Blend One One
            ZWrite Off
            Fog { Color (0,0,0,0) } // in additive pass fog should be black
            ZTest LEqual
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0
            
            #pragma multi_compile_fog
            #pragma multi_compile_fwdadd_fullshadows
            
            #pragma multi_compile DIFFUSE_WRAP_ON DIFFUSE_WRAP_OFF
            #pragma multi_compile ENERGY_CONSERVATION_ON ENERGY_CONSERVATION_OFF
            #pragma multi_compile DAB_COORDS_TRIPLANAR DAB_COORDS_UV DAB_COORDS_UV2
            
            #include "ToonMultiCompiles.cginc"
            
            #include "ToonLighting.cginc"
            
            ENDCG
        }
        
        Pass {
            Tags {
                "LightMode" = "ShadowCaster"
            }
            
            ZWrite On ZTest LEqual Cull Off
            Offset 1,1

            CGPROGRAM
            
            #pragma target 3.0
            
            #pragma multi_compile_shadowcaster

            #pragma vertex vert
            #pragma fragment frag

            #include "ToonShadows.cginc"
           
            ENDCG
        }
        
        Pass {
            Tags {
                "LightMode" = "Meta"
            }

            Cull Off

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "ToonLightmapping.cginc"
            
            
            ENDCG
        }
        
    }
    FallBack "Diffuse"
}

// Toon Standard Shader
// Adrian Biagioli (github.com/Flafla2)
// See LICENSE.txt

// Derived from:
// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license

Shader "Hidden/TerrainEngine/Splatmap/ToonStandard-Base" {
    Properties {
        _MainTex ("Base (RGB) Smoothness (A)", 2D) = "white" {}
        _MetallicTex ("Metallic (R)", 2D) = "white" {}
        _MaskTex ("Mask (RGB)", 2D) = "black" {}

        // used in fallback on old cards
        _Color ("Main Color", Color) = (1,1,1,1)
    }

    SubShader {
        Tags {
            "RenderType" = "Opaque"
            "Queue" = "Geometry-100"
        }
        
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

            #define DAB_COORDS_TRIPLANAR
            #define DIFFUSE_WRAP_OFF
            #define FORWARD_BASE_PASS

            #include "ToonTerrainForwardBaseCommon.cginc"
            
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
            
            #define DAB_COORDS_TRIPLANAR
            #define DIFFUSE_WRAP_OFF

            #include "ToonTerrainForwardBaseCommon.cginc"
            
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

            #include "../ToonShadows.cginc"
           
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

            #include "../ToonLightmapping.cginc"
            
            
            ENDCG
        }

        UsePass "Hidden/Nature/Terrain/Utilities/PICKING"
        UsePass "Hidden/Nature/Terrain/Utilities/SELECTION"
    }

    FallBack "Diffuse"
}

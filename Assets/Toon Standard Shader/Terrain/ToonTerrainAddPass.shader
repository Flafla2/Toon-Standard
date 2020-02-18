Shader "Hidden/TerrainEngine/Splatmap/ToonStandard-AddPass" {
    SubShader {
        Tags {
            "Queue" = "Geometry-99"
            "IgnoreProjector" = "True"
            "RenderType" = "Opaque"
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
            
            #pragma multi_compile_local __ _NORMALMAP

            #define DAB_COORDS_TRIPLANAR
            #define DIFFUSE_WRAP_OFF
            #define TERRAIN_SPLAT_ADDPASS

            #include "ToonTerrainForwardCommon.cginc"
            
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
            
            #pragma multi_compile_local __ _NORMALMAP
            
            #define DAB_COORDS_TRIPLANAR
            #define DIFFUSE_WRAP_OFF
            #define TERRAIN_SPLAT_ADDPASS
            
            #include "ToonTerrainForwardCommon.cginc"
            
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
    }

    Fallback "Hidden/TerrainEngine/Splatmap/Diffuse-AddPass"
}

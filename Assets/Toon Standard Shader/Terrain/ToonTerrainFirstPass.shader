Shader "Nature/Terrain/Toon Standard" {
    Properties {
        // used in fallback on old cards & base map
        [HideInInspector] _MainTex ("BaseMap (RGB)", 2D) = "white" {}
        [HideInInspector] _Color ("Main Color", Color) = (1,1,1,1)

        _RimLighting ("Rim Lighting (RGB) Power (A)", Color) = (1,1,1,1)
        _DabsScale ("Specular Dabs Scale", Vector) = (1,1,1,1)
    }

    SubShader {
        Tags {
            "Queue" = "Geometry-100"
            "RenderType" = "Opaque"
            "SplatCount" = "4"
            "MaskMapR" = "Specular (R)"
            "MaskMapG" = "Specular (G)"
            "MaskMapB" = "Specular (B)"
            "MaskMapA" = "Specular Power"
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

            #pragma multi_compile_local __ _NORMALMAP

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
            
            #define DAB_COORDS_TRIPLANAR
            #define DIFFUSE_WRAP_OFF

            #pragma multi_compile_local __ _NORMALMAP

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

        UsePass "Hidden/Nature/Terrain/Utilities/PICKING"
        UsePass "Hidden/Nature/Terrain/Utilities/SELECTION"
    }

    Dependency "AddPassShader"    = "Hidden/TerrainEngine/Splatmap/ToonStandard-AddPass"
    Dependency "BaseMapShader"    = "Hidden/TerrainEngine/Splatmap/Standard-Base"
    Dependency "BaseMapGenShader" = "Hidden/TerrainEngine/Splatmap/Standard-BaseGen"
    // Dependency "BaseMapShader"    = "Hidden/TerrainEngine/Splatmap/ToonStandard-Base"
    // Dependency "BaseMapGenShader" = "Hidden/TerrainEngine/Splatmap/ToonStandard-BaseGen"

    Fallback "Nature/Terrain/Diffuse"
}

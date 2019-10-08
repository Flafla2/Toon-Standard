// Toon Standard Shader
// Adrian Biagioli (github.com/Flafla2)
// See LICENSE.txt

#if UNITY_EDITOR
using System;
using UnityEngine;
using UnityEditor;

public class ToonStandardEditor : ShaderGUI
{
    private static GUIContent labelInstance = new GUIContent();
    private static GUIContent MakeLabel(string text, string tooltip = null)
    {
        labelInstance.text = text;
        labelInstance.tooltip = tooltip == null ? tooltip : "";
        return labelInstance;

    }

    private bool _ShowEnergyConservationWarning = false;
    private bool _ShowNoConfigWarning = false;

    private bool _ExpandedEnergyConservationWarning = false;
    private bool _ExpandedNoConfigWarning = false;

    private bool _ShowNoResourceWarning = false;
    private string _CurrentGCPath = "";

    enum SpecDabCoordinates
    {
        Triplanar, UV, UV2
    };
    
    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        var config = ToonStandardConfiguration.Instance;
        if (!config.IsDefaultInstance)
        {
            if (Event.current.type == EventType.Layout)
            {
                var path = AssetDatabase.GetAssetPath(config);
                var pathSplit = path.Split('/');
                _ShowNoResourceWarning = (pathSplit.Length < 3) || !pathSplit[pathSplit.Length - 2].ToLower().Equals("resources");
                _CurrentGCPath = path;
            }

            if (_ShowNoResourceWarning)
            {
                GUIStyle areaStyle = GUI.skin.GetStyle("HelpBox");
                areaStyle.richText = true;

                EditorGUILayout.LabelField("<b><size=16><color=#cc3333>Shader will not work when building</color></size></b>\n" +
                                        "The Toon Standard Configuration can not be loaded at runtime if it is " +
                                        "not located in the a Resources folder.  Ensure that this asset is a direct " +
                                        "member of a Resources/ folder (i.e. it must not be a subfolder of a Resources " +
                                        "folder).  So the path must be of the form <b>/Assets/.../Resources/<name>.asset</b>.\n\n" +
                                        "<b><size=12>Current path:</size></b>:\n" + _CurrentGCPath, areaStyle);
            }
        }

        GUILayout.Label("Local Properties", EditorStyles.boldLabel);

        Func<string, MaterialProperty> property = (s) => FindProperty(s, properties);

        var mainTex = property("_MainTex");
        var mainTexName = MakeLabel(mainTex.displayName, "Main Color (RGB)");

        materialEditor.TexturePropertySingleLine(mainTexName, mainTex, property("_Color"));
        materialEditor.TextureScaleOffsetProperty(mainTex);

        GUILayout.Space(12);

        var specTex = property("_SpecularTex");
        var specTexName = MakeLabel(specTex.displayName, "Specular (RGB)");

        var specColor = property("_SpecularColor");
        materialEditor.TexturePropertySingleLine(specTexName, specTex, specColor);

        EditorGUI.indentLevel += 2;
        var specGloss = property("_SpecularGloss");
        materialEditor.RangeProperty(specGloss, specGloss.displayName);
        if (!ToonStandardConfiguration.Instance.EnergyConservationEnabled)
        {
            // Specular power breaks energy conservation, so disable it if energy conservation is enabled
            var specPower = property("_SpecularPower");
            materialEditor.FloatProperty(specPower, specPower.displayName);
        }
        EditorGUI.indentLevel -= 2;

        materialEditor.TextureScaleOffsetProperty(specTex);

        GUILayout.Space(12);

        var normTex = property("_NormalMap");
        var normTexName = MakeLabel(normTex.displayName, "Normal Map");

        materialEditor.TexturePropertySingleLine(normTexName, normTex);
        EditorGUI.indentLevel += 2;
        var normScale = property("_BumpScale");
        materialEditor.FloatProperty(normScale, normScale.displayName);
        EditorGUI.indentLevel -= 2;

        GUILayout.Space(12);

        var emissionTex = property("_EmissionTex");
        var emissionCol = property("_EmissionColor");

        EditorGUI.BeginChangeCheck();
        materialEditor.TexturePropertyWithHDRColor(
            MakeLabel(emissionTex.displayName, "Emission (RGB)"),
            emissionTex, emissionCol, false);
        if (EditorGUI.EndChangeCheck())
        {
            var col = emissionCol.colorValue;
            bool hasEmission = col.maxColorComponent > 0.0001f;
            foreach (Material m in materialEditor.targets)
            {
                m.globalIlluminationFlags = hasEmission ?
                    MaterialGlobalIlluminationFlags.BakedEmissive :
                    MaterialGlobalIlluminationFlags.None;
            }
        }

        materialEditor.TextureScaleOffsetProperty(emissionTex);

        var miniStyle = EditorStyles.miniLabel;
        miniStyle.wordWrap = true;

        Material mat = materialEditor.target as Material;
        if (mat != null)
        {
            Func<SpecDabCoordinates, string> coord2name = (SpecDabCoordinates c) => "DAB_COORDS_" + c.ToString().ToUpper();
            SpecDabCoordinates cur;
            if (mat.IsKeywordEnabled("DAB_COORDS_UV2"))
                cur = SpecDabCoordinates.UV2;
            else if (mat.IsKeywordEnabled("DAB_COORDS_UV"))
                cur = SpecDabCoordinates.UV;
            else
                cur = SpecDabCoordinates.Triplanar;
            SpecDabCoordinates nxt = (SpecDabCoordinates)EditorGUILayout.EnumPopup("Specular Dabs Coordinates", cur);
            mat.DisableKeyword(coord2name(cur));
            mat.EnableKeyword(coord2name(nxt));

            if (nxt != SpecDabCoordinates.Triplanar)
            {
                var dabsScale = property("_DabsScale");
                var scale = dabsScale.vectorValue;
                Vector2 scale2 = new Vector2(scale.x, scale.y);
                EditorGUI.indentLevel += 2;
                scale2 = EditorGUILayout.Vector2Field("UV Scale", scale2);
                if (!Mathf.Approximately(scale.x, scale2.x) || !Mathf.Approximately(scale.y, scale2.y))
                {
                    scale.x = scale2.x; scale.y = scale2.y;
                    dabsScale.vectorValue = scale;
                }

                EditorGUILayout.LabelField("For consistency, you should do your best to scale the " +
                                "Specular Dab UV Coordinates to match the scale of Triplanar mapping.  " +
                                "To change the scale of Triplanar mapping globally, see the Toon " +
                                "Standard configuration.", miniStyle);
            }
        }

        if (Event.current.type == EventType.Layout)
            _ShowEnergyConservationWarning = specColor.colorValue.grayscale > 0.5 && config.EnergyConservationEnabled;
        if (_ShowEnergyConservationWarning)
        {
            _ExpandedEnergyConservationWarning = EditorGUILayout.BeginFoldoutHeaderGroup(_ExpandedEnergyConservationWarning, "Warning: Energy conservation is enabled...");
            if(_ExpandedEnergyConservationWarning)
            {
                GUILayout.Label("Warning: Energy conservation is enabled and this material has a " +
                                "high specular component.  So this material may appear to have a " +
                                "black Albedo, because with energy conservation Albedo + Specular ≤ 1.  " +
                                "To make the albedo appear brighter, disable energy conservation in " +
                                "the global Toon Standard Configuration, or reduce the specular term.",
                                miniStyle);
            }
            EditorGUILayout.EndFoldoutHeaderGroup();
        }

        if (Event.current.type == EventType.Layout)
            _ShowNoConfigWarning = config.IsDefaultInstance;
        if (_ShowNoConfigWarning)
        {
            _ExpandedNoConfigWarning = EditorGUILayout.BeginFoldoutHeaderGroup(_ExpandedNoConfigWarning, "Warning: No configuration...");
            if (_ShowNoConfigWarning)
            {
                GUILayout.Label("Warning: There is no Toon Standard Configuration Asset, so " +
                                "the global color ramp and other important properties have been " +
                                "left to their default values.  Create a configuration asset by " +
                                "navigating to Assets > Create > Toon Standard Configuration.",
                                miniStyle);
            }
            EditorGUILayout.EndFoldoutHeaderGroup();
        }
    }

    public override void AssignNewShaderToMaterial(Material material, Shader oldShader, Shader newShader)
    {
        base.AssignNewShaderToMaterial(material, oldShader, newShader);
        ToonStandardConfiguration.Instance.RefreshShaderDefines();
    }

    public override void OnMaterialPreviewGUI(MaterialEditor materialEditor, Rect r, GUIStyle background)
    {
        ToonStandardConfiguration.Instance.RefreshShaderDefines();
        base.OnMaterialPreviewGUI(materialEditor, r, background);
    }

    public override void OnMaterialInteractivePreviewGUI(MaterialEditor materialEditor, Rect r, GUIStyle background)
    {
        ToonStandardConfiguration.Instance.RefreshShaderDefines();
        base.OnMaterialInteractivePreviewGUI(materialEditor, r, background);
    }
}
#endif
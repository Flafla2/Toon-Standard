// Toon Standard Shader
// Adrian Biagioli (github.com/Flafla2)
// See LICENSE.txt

#if UNITY_EDITOR
using UnityEngine;
using UnityEditor;

[CustomEditor(typeof(ToonStandardConfiguration))]
public class ToonStandardConfigurationEditor : Editor
{
    public override void OnInspectorGUI()
    {
        base.OnInspectorGUI();

        var gc = target as ToonStandardConfiguration;

        if (GUILayout.Button("Apply Toon Ramp Gradient"))
        {
            Undo.RecordObject(gc, "Apply Toon Ramp Gradient");
            gc.ApplyToonGradient();
        }

        GUILayout.Label("Current Ramp:", EditorStyles.boldLabel);


        if (gc.ToonGradientRasterized != null)
        {
            var tex = gc.ToonGradientRasterized;
            GUIStyle cs = new GUIStyle();
            cs.stretchWidth = true;
            Rect r = (Rect)EditorGUILayout.BeginVertical(cs);
            GUILayout.Space(40);
            GUI.DrawTexture(r, tex, ScaleMode.StretchToFill);
            EditorGUILayout.EndVertical();

            GUILayout.Label(tex.width + "x" + tex.height);
        }
            
    }
}
#endif
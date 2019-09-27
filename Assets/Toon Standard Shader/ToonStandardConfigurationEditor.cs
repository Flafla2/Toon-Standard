// Toon Standard Shader
// Adrian Biagioli (github.com/Flafla2)
// See LICENSE.txt

#if UNITY_EDITOR
using UnityEngine;
using UnityEditor;

[CustomEditor(typeof(ToonStandardConfiguration))]
public class ToonStandardConfigurationEditor : Editor
{
    private bool _ShowNoResourceWarning = false;
    private string _CurrentPath = "";

    public override void OnInspectorGUI()
    {
        var gc = target as ToonStandardConfiguration;

        if (Event.current.type == EventType.Layout)
        {
            var path = AssetDatabase.GetAssetPath(gc);
            var pathSplit = path.Split('/');
            _ShowNoResourceWarning = (pathSplit.Length < 3) || !pathSplit[pathSplit.Length - 2].ToLower().Equals("resources");
            _CurrentPath = path;
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
                                        "<b><size=12>Current path:</size></b>:\n" + _CurrentPath, areaStyle);
        }

        base.OnInspectorGUI();

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
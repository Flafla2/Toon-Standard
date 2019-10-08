// Toon Standard Shader
// Adrian Biagioli (github.com/Flafla2)
// See LICENSE.txt

using UnityEngine;

#if UNITY_EDITOR
[UnityEditor.InitializeOnLoad]
#endif
[CreateAssetMenu(fileName = "ToonStandardConfiguration", menuName = "Toon Standard Configuration", order = 750)]
public class ToonStandardConfiguration : ScriptableObject
{
    private static bool _IsStaticLoading = false;
    public static ToonStandardConfiguration Instance
    {
        get
        {
            if (!_Instance)
            {
#if UNITY_EDITOR
                // Try to load a ToonStandardConfiguration from the editor
                if (_IsStaticLoading || !Application.isPlaying)
                {
                    var assetPaths = UnityEditor.AssetDatabase.FindAssets("t:ToonStandardConfiguration");
                    foreach (string path in assetPaths)
                    {
                        var asset = UnityEditor.AssetDatabase.LoadAssetAtPath<ToonStandardConfiguration>(path);
                        if (asset != null)
                        {
                            _Instance = asset;
                            return _Instance;
                        }
                    }
                }
#endif
                var res = Resources.LoadAll<ToonStandardConfiguration>("");
                if (res.Length > 0)
                {
                    _Instance = res[0];
                    return _Instance;
                }

				_Instance = CreateInstance<ToonStandardConfiguration>();
                _Instance._IsDefaultInstance = true;
            }

            return _Instance;
        }
    }
    private static ToonStandardConfiguration _Instance;

    private static void InitStatic()
    {
        _IsStaticLoading = true;
        var c = Instance;
        if (c._IsDefaultInstance)
        {
            Debug.LogWarning("No Toon Standard Configuration included in build!");
        }
        _IsStaticLoading = false;
    }

#if UNITY_EDITOR
    private static void StaticUpdateCallback()
    {
        // Hack to load the toon configuration in the editor on editor load
        // Simply adds itself to the UnityEditor update callback, then removes after running once.
        InitStatic();
        UnityEditor.EditorApplication.update -= StaticUpdateCallback;
    }
    static ToonStandardConfiguration()
    {
        UnityEditor.EditorApplication.update += StaticUpdateCallback;
    }
#endif

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
    static void RuntimeLoad()
    {
        InitStatic();
    }

    [Header("Diffuse Wrap")]
    [SerializeField]
    public bool DiffuseWrapEnabled = true;
    [SerializeField]
    [Range(0.0f, 1.0f)]
    public float DiffuseWrapAmount = 1.0f;
    [SerializeField]
    public bool EnergyConservationEnabled = false;
    [Header("Specular Dabs")]
    [SerializeField]
    public Texture2D SpecularDabs = default;
    [SerializeField]
    public float DabsRotation = 30.0f;
    [SerializeField]
    public float DabsScale = 1.0f;
    [Header("Color Ramp")]
    [SerializeField]
    public Gradient ToonGradientTestbed = default;
    [SerializeField]
    [HideInInspector]
    public Texture2D ToonGradientRasterized = default;
    [SerializeField]
    [HideInInspector]
    public Color RampIntegral = default;

    public bool IsDefaultInstance
    {
        get { return _IsDefaultInstance; }
    }
    private bool _IsDefaultInstance = false;

    private void OnEnable()
    {
        if((_Instance == null || _Instance._IsDefaultInstance) && _Instance != this)
        {
            if (_Instance != null)
            {
                if (Application.isPlaying)
                    Destroy(_Instance);
                else
                    DestroyImmediate(_Instance);
            }

            _Instance = this;
            RefreshShaderDefines();
            return;
        }

        if(_Instance != null && _Instance != this)
        {
            Debug.LogWarning("Only one ToonStandardConfiguration allowed at a time.  Deleting one of them");
            if (Application.isPlaying)
                Destroy(this);
            else
                DestroyImmediate(this);
            return;
        }
    }

    private void OnDisable()
    {
        if (_Instance == this)
            _Instance = null;
    }

    private void Awake()
    {
        RefreshShaderDefines();
        Shader.SetGlobalTexture("_LightRamp", ToonGradientRasterized);
    }

#if UNITY_EDITOR
    private void OnValidate()
    {
        RefreshShaderDefines();
    }

    private void Reset()
    {
        ToonGradientTestbed = new Gradient
        {
            colorKeys = new GradientColorKey[]
            {
                new GradientColorKey(Color.black, 0.0f),
                new GradientColorKey(Color.white, 1.0f)
            }
        };
        SpecularDabs = Texture2D.whiteTexture;
        ApplyToonGradient();
        RefreshShaderDefines();
    }
#endif

    public void ApplyToonGradient(int samples = 512)
    {
        ToonGradientRasterized = new Texture2D(samples, 1);
        ToonGradientRasterized.filterMode = FilterMode.Bilinear;
        ToonGradientRasterized.wrapMode = TextureWrapMode.Clamp;
        Color[] Colors = new Color[samples];
        // Integral of toon BRDF across the hemisphere is equivalent to the average
        // of each entry on the ramp times 2π.  This is used by the shader for energy
        // conservation.  We omit π because it is generally omitted by all unity
        // shaders when considering normalization factors.
        RampIntegral = new Color(0.0f, 0.0f, 0.0f, 0.0f);
        for(int x = 0; x < samples; ++x)
        {
            float a = ((float)x) / (samples - 1);
            Colors[x] = ToonGradientTestbed.Evaluate(a);
            RampIntegral += Colors[x];
        }
        RampIntegral /= samples / 2;
        ToonGradientRasterized.SetPixels(Colors);
        ToonGradientRasterized.Apply();
        Shader.SetGlobalTexture("_LightRamp", ToonGradientRasterized);
        Shader.SetGlobalColor("_RampIntegral", RampIntegral);
    }

    // Should only be called by editor scripts
    public void RefreshShaderDefines()
    {
        if (DiffuseWrapEnabled)
        {
            Shader.EnableKeyword("DIFFUSE_WRAP_ON");
            Shader.DisableKeyword("DIFFUSE_WRAP_OFF");
            float amnt = 1.0f - DiffuseWrapAmount * 0.5f;
            Shader.SetGlobalFloat("_DiffuseWrapAmount", amnt);
        }
        else
        {
            Shader.EnableKeyword("DIFFUSE_WRAP_OFF");
            Shader.DisableKeyword("DIFFUSE_WRAP_ON");
        }

        if (EnergyConservationEnabled)
        {
            Shader.EnableKeyword("ENERGY_CONSERVATION_ON");
            Shader.DisableKeyword("ENERGY_CONSERVATION_OFF");
        }
        else
        {
            Shader.EnableKeyword("ENERGY_CONSERVATION_OFF");
            Shader.DisableKeyword("ENERGY_CONSERVATION_ON");
        }

        if (ToonGradientRasterized == null)
            ApplyToonGradient();
        else
        {
            Shader.SetGlobalTexture("_LightRamp", ToonGradientRasterized);
            Shader.SetGlobalColor("_LightRampIntegral", RampIntegral);
        }

        Shader.SetGlobalTexture(Shader.PropertyToID("_SpecularDabsTex"), SpecularDabs);

        float c = Mathf.Cos(Mathf.Deg2Rad * DabsRotation);
        float s = Mathf.Sin(Mathf.Deg2Rad * DabsRotation);
        Matrix4x4 tr = Matrix4x4.zero;
        tr.m00 =  c / DabsScale;
        tr.m10 = -s / DabsScale;
        tr.m01 =  s / DabsScale;
        tr.m11 =  c / DabsScale;
        Shader.SetGlobalMatrix(Shader.PropertyToID("_InvSpecularDabsTransform"), tr);
    }
}

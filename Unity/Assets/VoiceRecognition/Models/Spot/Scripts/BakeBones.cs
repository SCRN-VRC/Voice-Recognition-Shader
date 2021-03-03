#if UNITY_EDITOR

using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

public class BakeBones : EditorWindow
{
    public Animator source;

    [MenuItem("Tools/SCRN/Bake Bones")]
    static void Init()
    {
        var window = GetWindowWithRect<BakeBones>(new Rect(0, 0, 265, 100));
        window.Show();
    }

    void OnGUI()
    {
        GUILayout.Label("Animator", EditorStyles.boldLabel);
        EditorGUILayout.BeginHorizontal();
        source = (Animator) EditorGUILayout.ObjectField(source, typeof(Animator), true);
        EditorGUILayout.EndHorizontal();

        if (GUILayout.Button("Bake!")) {
            OnGenerateTexture();
        }
    }

    void OnGenerateTexture()
    {

        const int width = 160;
        const int height = 160;
        const int blockWidth = 40;
        const int blockColumns = 3;

        Texture2D tex = new Texture2D(width, height, TextureFormat.RGBAFloat, false);
        tex.wrapMode = TextureWrapMode.Clamp;
        tex.filterMode = FilterMode.Point;
        tex.anisoLevel = 1;

        float scale = source.transform.localScale[0];
        AnimationClip[] animationClips = source.runtimeAnimatorController.animationClips;
        
        int animCount = 0;
        foreach(AnimationClip animClip in animationClips)
        {
            Debug.Log(animClip.name + ": " + animClip.length);
            EditorCurveBinding[] editorCurveBindings = AnimationUtility.GetCurveBindings(animClip);
            
            int editorCurveCount = 0;
            foreach (EditorCurveBinding ecb in editorCurveBindings)
            {
                //Debug.Log();
                string channel = ecb.propertyName.Substring(ecb.propertyName.Length - 2);
                
                int chanInt = string.Compare(channel, ".x") == 0 ? 0 :
                    string.Compare(channel, ".y") == 0 ? 1 :
                    string.Compare(channel, ".z") == 0 ? 2 : -1;
                if (chanInt < 0) continue;

                bool rotationAnim = ecb.propertyName.Contains("localEulerAnglesRaw");
                float convertToRad = rotationAnim ? 0.0174532925f : scale;

                // Bake rotations first then positions, this fixes order
                int moddedCurve = editorCurveCount;
                if (rotationAnim && (editorCurveCount / 3) % 2 == 1)
                {
                    moddedCurve -= 3;
                }
                else if (!rotationAnim && (editorCurveCount / 3) % 2 == 0)
                {
                    moddedCurve += 3;
                }

                AnimationCurve curve = AnimationUtility.GetEditorCurve(animClip, ecb);

                int frameCount = 0;
                foreach (Keyframe frame in curve.keys)
                {
                    // each anim gets baked in a 40x40 square
                    int offX = (animCount % blockColumns) * blockWidth + frameCount;
                    int offY = (animCount / blockColumns) * blockWidth + moddedCurve / blockColumns;

                    Color oldColor = tex.GetPixel(offX, offY);
                    oldColor[chanInt] = frame.value * convertToRad;
                    oldColor[3] = 0;
                    //Debug.Log(oldColor);
                    tex.SetPixel(offX, offY, oldColor);
                    frameCount++;
                }

                //Debug.Log(ecb.path + " " + ecb.propertyName);

                tex.Apply();
                editorCurveCount++;
            }

            animCount++;
        }

        string path = AssetDatabase.GetAssetPath(animationClips[0]);
        int fileDir = path.LastIndexOf("/");
        path = path.Substring(0, fileDir);
        path = path + "/BakedAnims.asset";

        AssetDatabase.CreateAsset(tex, path);
        AssetDatabase.SaveAssets();
    }
}

#endif
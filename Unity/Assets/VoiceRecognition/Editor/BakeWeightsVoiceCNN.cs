#if UNITY_EDITOR

using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System.IO;
using UnityEngine.UI;

[ExecuteInEditMode]
public class VoiceCNNWeights : EditorWindow
{
    public TextAsset source0;

    string SavePath = "Assets/VoiceRecognition/Weights/WeightsTex.asset";

    [MenuItem("Tools/SCRN/Bake VoiceCNN")]
    static void Init()
    {
        var window = GetWindowWithRect<VoiceCNNWeights>(new Rect(0, 0, 400, 250));
        window.Show();
    }
    
    void OnGUI()
    {
        GUILayout.Label("Bake VoiceCNN", EditorStyles.boldLabel);
        EditorGUILayout.BeginVertical();
        source0 = (TextAsset) EditorGUILayout.ObjectField("VoiceCNN Weights (.bytes):", source0, typeof(TextAsset), false);
        EditorGUILayout.EndVertical();

        if (GUILayout.Button("Bake!")) {
            OnGenerateTexture();
        }
    }

    void OnGenerateTexture()
    {
        if (source0 != null)
        {
            const int width = 1024;
            const int height = 1024;
            Texture2D tex = new Texture2D(width, height, TextureFormat.RFloat, false);
            tex.wrapMode = TextureWrapMode.Clamp;
            tex.filterMode = FilterMode.Point;
            tex.anisoLevel = 1;
            
            ExtractFromBin(tex, source0);
            AssetDatabase.CreateAsset(tex, SavePath);
            AssetDatabase.SaveAssets();

            ShowNotification(new GUIContent("Done"));
        }
    }

    void writeBlock(Texture2D tex, BinaryReader br0, int totalFloats, int destX, int destY, int width)
    {
        for (int i = 0; i < totalFloats; i++)
        {
            int x = i % width;
            int y = i / width;
            tex.SetPixel(x + destX, y + destY,
                new Color(br0.ReadSingle(), 0, 0, 0)); //br0.ReadSingle()
        }
    }

    void ExtractFromBin(Texture2D tex, TextAsset srcIn0)
    {
        Stream s0 = new MemoryStream(srcIn0.bytes);
        BinaryReader br0 = new BinaryReader(s0);

        writeBlock(tex, br0, 3 * 3 * 32,      100, 960, 32);    //wL1
        writeBlock(tex, br0, 32,              961, 288, 1);     //bL1

        writeBlock(tex, br0, 32 * 4,            0, 971, 32);    //nL1

        writeBlock(tex, br0, 3 * 3 * 32 * 64, 960, 0,   64);    //wL2
        writeBlock(tex, br0, 64,              960, 288, 1);     //bL2
        for (int i = 0; i < 96; i++)
        {
            for (int j = 0; j < 96; j++)
            {
                writeBlock(tex, br0, 100, 10 * j, 10 * i, 10);  //wFC1
            }
        }
        writeBlock(tex, br0, 100,             0,   970, 100);   //bFC1
        writeBlock(tex, br0, 100 * 10,        0,   960, 100);   //wOut
        writeBlock(tex, br0, 10,              962, 288, 1);     //bOut
    }
}

#endif
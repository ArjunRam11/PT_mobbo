using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using MoBBoLibrary_WIFI;
using UnityEngine.SceneManagement;


public class force : MonoBehaviour
{
    public GameObject cop;
    public GameObject board;
    public Text force_1;
    public Text force_2;
    public Text force_3;
    public Text force_4;
    public Text weight;
    public float minforce = 0;
    public float maxforce = 150f;
    public int minFontSize = 30; // Minimum font size
    public int maxFontSize = 70;
    public float normalisedforce_1;
    public float normalisedforce_2;
    public float normalisedforce_3;
    public float normalisedforce_4;
    public int fontsize_1;
    public int fontsize_2;
    public int fontsize_3;
    public int fontsize_4;
    public RectTransform board_transform;
    public Vector3 board_position;
    _SetUp_ScnHndlr_WIFI data_fetcher = new _SetUp_ScnHndlr_WIFI();
    public float[] forceValues = new float[4];
    public Button go_back;
    public InputField lengthInput;
    public InputField breadthInput;
    public Button drawButton;
    private GameObject rectangle;
    public float real_board_width = 57f;
    public float real_board_height = 42.5f;
    private LineRenderer lineRenderer;
    private List<Vector3> copPositions = new List<Vector3>();
    public float minDistance = 0.05f;
    // Start is called before the first frame update
    void Start()
    {
        drawButton.onClick.AddListener(DrawBox);
        go_back.onClick.AddListener(btnGoBack_Click);
        //lineRenderer = cop.AddComponent<LineRenderer>();
        //lineRenderer.startWidth = 5f;
        //lineRenderer.endWidth = 2f;
        //lineRenderer.positionCount = 0; // Initial path length

        //// Set LineRenderer material and color
        //lineRenderer.material = new Material(Shader.Find("Sprites/Default"));
        //lineRenderer.startColor = Color.green;
        //lineRenderer.endColor = Color.green;
        //lineRenderer.sortingLayerName = "Foreground"; // Create a custom sorting layer in Unity and name it 'Foreground'
        //lineRenderer.sortingOrder = 10;

    }
    public void btnGoBack_Click()
    {
        SceneManager.LoadScene("2mb");
    }
    void DrawBox()
    {
        if (rectangle != null)
        {
            Destroy(rectangle); // Remove previous rectangle if it exists
        }

        // Parse length and breadth from the input (assumed in centimeters)
        float length = float.Parse(lengthInput.text);
        float breadth = float.Parse(breadthInput.text);

        // Get current board dimensions from Unity (using RectTransform)
        board_transform = board.GetComponent<RectTransform>();
        float unity_board_width = board_transform.rect.width;
        float unity_board_height = board_transform.rect.height;

        // Scale length and breadth proportionally based on real-world board size
        float scaled_length = (length / real_board_width) * unity_board_width;
        float scaled_breadth = (breadth / real_board_height) * unity_board_height;

        // Create a new GameObject for the rectangle
        rectangle = new GameObject("Rectangle");

        // Add a RectTransform to position and size the rectangle
        RectTransform rectTransform = rectangle.AddComponent<RectTransform>();
        rectTransform.sizeDelta = new Vector2(scaled_length, scaled_breadth); // Set size in Unity units

        // Add an Image component to visualize the rectangle
        Image rectangleImage = rectangle.AddComponent<Image>();
        rectangleImage.color = new Color(1f, 0f, 0f, 0.5f); ;  // You can change the color as needed
     

        // Set the rectangle as a child of the Canvas
        rectangle.transform.SetParent(GameObject.Find("Canvas").transform, false);

        // Optionally, set the rectangle's position relative to the board
        rectTransform.anchoredPosition = new Vector2(0, 0); // Position centered on the screen
    }

    void cop_control()
    {
     

        board_transform = board.GetComponent<RectTransform>();
        board_position = board.transform.position;

        float unity_board_width = board_transform.rect.width;
        float unity_board_height = board_transform.rect.height;

        float x_cap = MoBBoServer.COP.x + 0f;
        float y_cap = MoBBoServer.COP.y + 0f;

        float x_vec = (x_cap * (unity_board_width / real_board_width)) - (unity_board_width / 2f) + board_position.x;
        float y_vec = (y_cap * (unity_board_height / real_board_height)) + (unity_board_height / 2f) + board_position.y;

        //Debug.Log("board_pos" + board_pos.x);

        {
            //cop.transform.position = new Vector3(Mathf.Clamp(x_vec, 407f, 646f), Mathf.Clamp(y_vec, 146f, 292f), 0f);
            cop.transform.position = Vector3.Lerp(cop.transform.position, new Vector3(x_vec, y_vec, 0f), 0.5f);


        }

    }
    void DrawCopPath()
    {
        Vector3 currentCopPosition = cop.transform.position;

        // Add the position to the path if the distance from the last point exceeds the minimum distance
        if (copPositions.Count == 0 || Vector3.Distance(copPositions[copPositions.Count - 1], currentCopPosition) > minDistance)
        {
            copPositions.Add(currentCopPosition);
            lineRenderer.positionCount = copPositions.Count;

            // Update the line's position based on Lerp to smoothen the path drawing
            for (int i = 0; i < copPositions.Count; i++)
            {
                Vector3 smoothPosition = Vector3.Lerp(lineRenderer.GetPosition(i), copPositions[i], 0.5f); // Apply Lerp to the line points
                lineRenderer.SetPosition(i, smoothPosition);
            }
        }
    }


        float[] CalculateColorIntensities(float[] forces)
    {
        float[] intensities = new float[4];
        // Normalize forces (optional)
        float maxForce = Mathf.Max(forces);
        for (int i = 0; i < 4; i++)
        {
            intensities[i] = forces[i] / maxForce;
        }
        return intensities;
    }

    // Function to map intensity to color
    Color MapIntensityToColor(float intensity)
    {
        // Example mapping: higher intensity -> brighter color
        return new Color(intensity, intensity, intensity);
    }

    // Function to apply colors to the rectangular board
    void ApplyColorsToBoard(Color[] colors)
    {
        // Get mesh renderer of the board
        MeshRenderer renderer = board.GetComponent<MeshRenderer>();
        if (renderer != null)
        {
            // Assign colors to the material
            Material material = renderer.material;
            material.SetColor("_TopLeftColor", colors[0]);
            material.SetColor("_TopRightColor", colors[1]);
            material.SetColor("_BottomRightColor", colors[2]);
            material.SetColor("_BottomLeftColor", colors[3]);
        }
    }

    public void fontscaler()
    {


        // Map the normalized force value to the font size range
        int fontSize = (int)Mathf.Lerp(minFontSize, maxFontSize, normalisedforce_4);
    }
    // Update is called once per frame
    void Update()
    {
        forceValues[0] = MoBBoServer.server.mobboDevs[0].F1;
        forceValues[1] = MoBBoServer.server.mobboDevs[0].F2;
        forceValues[2] = MoBBoServer.server.mobboDevs[0].F3;
        forceValues[3] = MoBBoServer.server.mobboDevs[0].F4;

        float[] colorIntensities = CalculateColorIntensities(forceValues);
        Color[] cornerColors = new Color[4];
        for (int i = 0; i < 4; i++)
        {
            cornerColors[i] = MapIntensityToColor(colorIntensities[i]);
            Debug.Log(cornerColors[i]);
        }

        // Apply colors to the rectangular board
        ApplyColorsToBoard(cornerColors);

        normalisedforce_1 = Mathf.Clamp01((forceValues[0] - minforce) / (maxforce - minforce));
        normalisedforce_2 = Mathf.Clamp01((forceValues[1] - minforce) / (maxforce - minforce));
        normalisedforce_3 = Mathf.Clamp01((forceValues[2] - minforce) / (maxforce - minforce));
        normalisedforce_4 = Mathf.Clamp01((forceValues[3] - minforce) / (maxforce - minforce));

        fontsize_1 = (int)Mathf.Lerp(minFontSize, maxFontSize, normalisedforce_1);
        fontsize_2 = (int)Mathf.Lerp(minFontSize, maxFontSize, normalisedforce_2);
        fontsize_3 = (int)Mathf.Lerp(minFontSize, maxFontSize, normalisedforce_3);
        fontsize_4 = (int)Mathf.Lerp(minFontSize, maxFontSize, normalisedforce_4);





        force_1.text = (Mathf.RoundToInt(MoBBoServer.server.mobboDevs[0].F1)).ToString();
        force_2.text = (Mathf.RoundToInt(MoBBoServer.server.mobboDevs[0].F2)).ToString();
        force_3.text = (Mathf.RoundToInt(MoBBoServer.server.mobboDevs[0].F3)).ToString();
        force_4.text = (Mathf.RoundToInt(MoBBoServer.server.mobboDevs[0].F4)).ToString();
        weight.text = (Mathf.RoundToInt(MoBBoServer.server.mobboDevs[0].F1 + MoBBoServer.server.mobboDevs[0].F2 + MoBBoServer.server.mobboDevs[0].F3 + MoBBoServer.server.mobboDevs[0].F4)).ToString();
        Debug.Log("force_4:" + force_4.text);
        cop_control();
        //DrawCopPath();

        force_1.fontSize = fontsize_1;
        force_2.fontSize = fontsize_2;
        force_3.fontSize = fontsize_3;
        force_4.fontSize = fontsize_4;



    }
}


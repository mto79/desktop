// Hands the fragment shaders what they need to tell the edge of the sphere from its middle.
VARYING vec3 worldNormal;
VARYING vec3 worldPosition;

void MAIN()
{
    worldNormal = normalize(NORMAL_MATRIX * NORMAL);
    worldPosition = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    POSITION = MODELVIEWPROJECTION_MATRIX * vec4(VERTEX, 1.0);
}

// The planet's own edge catching the light, drawn over the earth.
VARYING vec3 worldNormal;
VARYING vec3 worldPosition;

void MAIN()
{
    vec3 normal = normalize(worldNormal);
    vec3 view = normalize(CAMERA_POSITION - worldPosition);
    float rim = pow(1.0 - abs(dot(normal, view)), 3.5);
    FRAGCOLOR = vec4(0.32, 0.55, 1.0, 1.0) * rim * 0.9;
}

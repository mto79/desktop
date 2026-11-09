// The glow around the planet: a shell a little larger than the earth, with its near side
// culled, so what is drawn is the far side seen past the limb. Brightest against the
// planet and gone by the shell's own edge.
VARYING vec3 worldNormal;
VARYING vec3 worldPosition;

void MAIN()
{
    vec3 normal = normalize(worldNormal);
    vec3 view = normalize(CAMERA_POSITION - worldPosition);
    float glow = pow(abs(dot(normal, view)), 5.0);
    FRAGCOLOR = vec4(0.30, 0.52, 1.0, 1.0) * glow * 0.85;
}

// Ghostty-compatible GLSL custom shader
// Black hole with thin accretion disk (bottom-right corner)
// Gargantua inspired — Black + Orange theme
//
// - Flat horizontal accretion disk (wider) with animated turbulence
// - Relativistic Doppler beaming (one limb brighter)
// - Subtle photon ring around the event horizon shadow
// - Strong central shadow, undistorted terminal background sampling
// - Positioned deep in bottom-right corner

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    if (iFocus == 0) {
        fragColor = texture(iChannel0, uv);
        return;
    }

    const float RS = 0.27;
    const float DISK_R0 = 1.48 * RS;
    const float DISK_R  = 5.2 * RS;
    const float DISK_FADE = 0.10;
    const float DISK_INTENSITY = 0.55;
    const float TIME_SPEED = 0.15;

    vec2 center = vec2(1.0, 1.0);

    vec2 p = uv - center;
    p.x *= iResolution.x / iResolution.y;
    float r = length(p);
    float ang = atan(p.y, p.x);

    vec4 terminalColor = texture(iChannel0, uv);
    vec3 color = terminalColor.rgb;

    // Flat horizontal accretion disk (wider version)
    float inclination = -0.76;
    vec2 diskP = p;
    diskP.y *= (1.0 - inclination);

    float dl = length(diskP);
    float dAng = atan(diskP.y, diskP.x);

    float t = iTime * TIME_SPEED;

    float angle = dAng + t * 0.52;
    float radial = log(dl + 0.02) * 2.6;

    vec2 noiseUV = vec2(sin(angle) * 0.95, cos(angle) * 0.78)
                 + vec2(radial * 0.25, t * 0.08);

    float n = sin(noiseUV.x * 4.9 + noiseUV.y * 2.95) * 0.46
            + sin(noiseUV.x * 10.2 + noiseUV.y * 5.9 + t * 0.65) * 0.31
            + sin(noiseUV.x * 19.8 + noiseUV.y * 8.3) * 0.17;
    n = n * 0.5 + 0.5;

    float inner = smoothstep(DISK_R0 - 0.01, DISK_R0 + DISK_FADE, dl);
    float outer = max(1.0 - dl / DISK_R, 0.0);
    float d0 = pow(outer * inner, 1.28);

    float diskDens = d0 * (n + max(0.0, n - 0.54) * 1.6) * 2.4;

    // Doppler beaming
    float doppler = cos(dAng + 0.82);
    diskDens *= (1.0 + 0.55 * doppler);

    vec3 diskCol = vec3(3.2, 0.62, 0.04) * 1.42;
    diskCol *= (0.92 + 0.30 * sin(dAng * 2.25 + t * 1.8)
                     + 0.14 * (1.0 - dl / (DISK_R * 0.75)));

    vec3 diskEmission = diskDens * diskCol * DISK_INTENSITY;

    // Event horizon shadow + subtle photon ring
    float shadowR = RS * 1.06;
    float horizonFactor = clamp((shadowR - r) / 0.028 + 1.0, 0.0, 1.0);

    float pr = r / RS;
    float photonRing = smoothstep(1.38, 1.45, pr) * (1.0 - smoothstep(1.48, 1.58, pr));
    photonRing = pow(photonRing, 0.7) * 1.35;

    vec3 photonEmission = photonRing * vec3(3.5, 1.7, 0.6) * 0.26;

    color *= (1.0 - diskDens * 0.36 - horizonFactor * 0.80);
    color += diskEmission * 0.58 + photonEmission;

    float vignette = 1.0 - smoothstep(0.42, 1.25, r);
    color *= (0.96 + 0.04 * vignette);

    color = clamp(color, 0.0, 1.35);

    fragColor = vec4(color, 1.0);
}

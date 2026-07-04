// Hermes Caduceus
// Subtle animated caduceus with heaven light rays and cursor glow.
// Warm gold tones. Focus-aware effects.

const float CADUCEUS_OPACITY = 0.115;
const float CURSOR_WING      = 0.33;

float caduceus(vec2 uv, float t) {
    vec2 p = uv - vec2(0.5, 0.515);
    p.x *= iResolution.x / iResolution.y;

    float d = 1e6;

    float staff = abs(p.x) - 0.002;
    d = min(d, staff);

    float basePhase = 2.0944;
    float dynamicPhase = basePhase + sin(t * 0.55) * 0.75 + cos(t * 0.35) * 0.45;

    float amp = 0.031;
    float xOff = 0.015;
    float freq = 10.8;
    float spd = 0.36;

    float s1 = abs((p.x - xOff) - amp * sin(p.y * freq + t * spd)) - 0.0025;
    d = min(d, s1);

    float s2 = abs((p.x + xOff) + amp * sin(p.y * freq + t * spd + dynamicPhase)) - 0.0025;
    d = min(d, s2);

    return smoothstep(0.0085, 0.0, d);
}

float heavenLight(vec2 uv, float t) {
    float y = uv.y;
    float cx = 0.5 + sin(t * 0.12) * 0.028;
    float dist = length(vec2((uv.x - cx) * 1.15, y * 0.62));
    float core = exp(-dist * 4.0) * 0.18;

    float ray1 = sin(uv.x * 19.0 + t * 0.65) * 0.5 + 0.5;
    float ray2 = sin(uv.x * 34.0 - t * 0.48) * 0.5 + 0.5;
    float rays = ray1 * 0.6 + ray2 * 0.4;

    float falloff = smoothstep(0.88, 0.03, y);
    float pulse = 0.68 + 0.32 * sin(t * 0.42);

    return core * falloff * (0.55 + 0.45 * rays) * pulse;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 term = texture(iChannel0, uv);

    bool focused = (iFocus == 1);
    float t = iTime;

    vec3 col = term.rgb;
    if (focused) {
        col = mix(col, vec3(1.0, 0.965, 0.90), 0.028);
    } else {
        col *= vec3(1.012, 0.998, 0.975);
    }

    float cad = caduceus(uv, t) * CADUCEUS_OPACITY;
    if (!focused) cad *= 0.35;

    vec3 cadColor = vec3(1.0, 0.89, 0.52);
    vec3 bg = cadColor * cad;

    float hl = heavenLight(uv, t);
    if (!focused) hl *= 0.32;
    vec3 heavenCol = vec3(1.0, 0.945, 0.68) * hl;
    bg += heavenCol;

    vec3 cursorCol = vec3(0.0);
    if (focused) {
        vec2 c = iCurrentCursor.xy + iCurrentCursor.zw * 0.5;
        float cd = length(fragCoord - c);
        float cr = max(iCurrentCursor.z, iCurrentCursor.w) * 2.45;
        float tc = t - iTimeCursorChange;

        float cGlow = 0.0;
        if (cd < cr * 1.18) {
            float nd = cd / cr;
            float fall = exp(-nd * 2.05) * (1.0 - smoothstep(0.32, 0.80, nd));
            float ang = atan(fragCoord.y - c.y, fragCoord.x - c.x);
            float feather = 0.77 + 0.23 * sin(ang * 2.05 + t * 3.7);
            cGlow = fall * feather * CURSOR_WING * (1.0 - min(tc / 0.92, 1.0));
        }
        cursorCol = mix(iCurrentCursorColor.rgb, vec3(1.0, 0.935, 0.62), 0.68) * cGlow;
    }

    vec3 final = col + bg + cursorCol;
    fragColor = vec4(final, term.a);
}

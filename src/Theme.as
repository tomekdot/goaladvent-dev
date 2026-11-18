// One shared layout, two colour schemes. The palette holds every colour,
// transparency and corner radius used by the dashboard; UI.as reads only from
// g_palette, so switching themes never touches the layout code.

class ThemePalette {
    vec4 windowBg;
    vec4 childBg;
    vec4 containerBg;   // columns / workspace: transparent in glass theme
    vec4 innerBg;
    vec4 headerBg;
    vec4 frameBg;
    vec4 border;
    vec4 borderStrong;
    vec4 borderWeak;
    vec4 buttonBg;
    vec4 buttonHover;
    vec4 buttonActive;
    vec4 text;
    vec4 textMuted;
    vec4 tableHeaderBg;

    vec4 gold;
    vec4 emerald;
    vec4 crimson;
    vec4 purple;
    vec4 navy;
    vec4 silver;
    vec4 bronze;
    vec4 teal;
    vec4 dimNavy;
    vec4 tileBg;
    vec4 tileSelectedBg;
    vec4 iceBlue;

    float windowRounding;
    float childRounding;
    float frameRounding;
    float tabRounding;

    ThemePalette() {
        SetObsidian();
    }

    void SetObsidian() {
        windowBg       = vec4(0.055, 0.055, 0.067, 0.98);
        childBg        = vec4(0.082, 0.082, 0.102, 1.00);
        containerBg    = vec4(0.082, 0.082, 0.102, 1.00);
        innerBg        = vec4(0.105, 0.105, 0.130, 1.00);
        headerBg       = vec4(0.120, 0.150, 0.220, 1.00);
        frameBg        = vec4(0.060, 0.090, 0.140, 1.00);
        border         = vec4(0.160, 0.160, 0.200, 1.00);
        borderStrong   = vec4(0.920, 0.930, 0.960, 1.00);
        borderWeak     = vec4(0.160, 0.160, 0.200, 1.00);
        buttonBg       = vec4(0.110, 0.110, 0.140, 1.00);
        buttonHover    = vec4(0.170, 0.170, 0.210, 1.00);
        buttonActive   = vec4(0.210, 0.210, 0.260, 1.00);
        text           = vec4(0.920, 0.920, 0.950, 1.00);
        textMuted      = vec4(0.550, 0.550, 0.620, 1.00);
        tableHeaderBg  = innerBg;

        gold = vec4(0.93, 0.82, 0.55, 1.00);
        emerald = vec4(0.36, 0.78, 0.52, 1.00);
        crimson = vec4(0.78, 0.32, 0.34, 1.00);
        purple = vec4(0.66, 0.60, 0.88, 1.00);
        navy = vec4(0.20, 0.24, 0.32, 1.00);
        silver = vec4(0.72, 0.74, 0.78, 1.00);
        bronze = vec4(0.62, 0.50, 0.38, 1.00);
        teal = vec4(0.45, 0.62, 0.70, 1.00);
        dimNavy = vec4(0.095, 0.095, 0.120, 1.00);
        tileBg = vec4(0.095, 0.095, 0.120, 1.00);
        tileSelectedBg = vec4(0.140, 0.140, 0.180, 1.00);
        iceBlue = vec4(0.92, 0.93, 0.96, 1.00);

        windowRounding = 6.0f;
        childRounding = 5.0f;
        frameRounding = 4.0f;
        tabRounding = 4.0f;
    }

    void SetTransparentGlass() {
        // Neutral black smoke + white frosted glass. All backgrounds have
        // R == G == B; no navy layer is stacked on top of another layer.
        float a = S_GlassOpacity;
        if (a < 0.15f) a = 0.15f;
        if (a > 0.80f) a = 0.80f;
        windowBg       = vec4(0.030, 0.030, 0.030, a);
        containerBg    = vec4(0.000, 0.000, 0.000, 0.00);  // columns: no extra layer
        childBg        = vec4(0.000, 0.000, 0.000, 0.22);  // sidebar only
        innerBg        = vec4(1.000, 1.000, 1.000, 0.07);  // stat cards
        headerBg       = vec4(0.000, 0.000, 0.000, 0.30);  // top / footer
        frameBg        = vec4(1.000, 1.000, 1.000, 0.10);
        border         = vec4(1.000, 1.000, 1.000, 0.16);
        borderStrong   = vec4(1.000, 1.000, 1.000, 0.75);
        borderWeak     = vec4(1.000, 1.000, 1.000, 0.12);
        buttonBg       = vec4(1.000, 1.000, 1.000, 0.07);
        buttonHover    = vec4(1.000, 1.000, 1.000, 0.14);
        buttonActive   = vec4(1.000, 1.000, 1.000, 0.18);
        text           = vec4(1.000, 1.000, 1.000, 0.96);
        textMuted      = vec4(1.000, 1.000, 1.000, 0.65);
        tableHeaderBg  = headerBg;

        gold = vec4(1.00, 0.86, 0.35, 1.00);          // leader star
        emerald = vec4(0.55, 1.00, 0.65, 1.00);       // completed
        crimson = vec4(1.00, 0.55, 0.65, 1.00);       // premium
        purple = vec4(0.78, 0.74, 0.98, 1.00);        // rest day: soft lavender
        navy = vec4(0.60, 0.60, 0.60, 1.00);
        silver = vec4(0.90, 0.90, 0.90, 1.00);
        bronze = vec4(0.75, 0.70, 0.60, 1.00);
        teal = vec4(0.70, 0.86, 0.95, 1.00);          // playable now: cool cyan
        dimNavy = vec4(1.000, 1.000, 1.000, 0.07);
        tileBg = vec4(1.000, 1.000, 1.000, 0.07);
        tileSelectedBg = vec4(1.000, 1.000, 1.000, 0.18);
        iceBlue = vec4(1.000, 1.000, 1.000, 0.96);

        windowRounding = 0.0f;
        childRounding = 0.0f;
        frameRounding = 0.0f;
        tabRounding = 0.0f;
    }
}

ThemePalette g_palette;

void RefreshPalette() {
    if (g_Theme == UiTheme::TransparentGlass) g_palette.SetTransparentGlass();
    else g_palette.SetObsidian();
}

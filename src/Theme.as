// One shared layout, two colour schemes. The palette holds every colour,
// transparency and corner radius used by the dashboard; UI.as reads only from
// g_palette, so switching themes never touches the layout code.

class ThemePalette {
    vec4 windowBg;
    vec4 childBg;
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

    void SetPursuitMatch() {
        // Translucent match glass, sharp edges and the Pursuit HUD accents.
        windowBg       = vec4(0.110, 0.130, 0.160, 0.78);
        childBg        = vec4(0.080, 0.095, 0.120, 0.72);
        innerBg        = vec4(0.160, 0.180, 0.220, 0.68);
        headerBg       = vec4(0.060, 0.070, 0.090, 0.88);
        frameBg        = vec4(0.060, 0.070, 0.090, 0.70);
        border         = vec4(1.000, 1.000, 1.000, 0.12);
        borderStrong   = vec4(1.000, 1.000, 1.000, 0.85);
        borderWeak     = vec4(1.000, 1.000, 1.000, 0.12);
        buttonBg       = vec4(0.160, 0.180, 0.220, 0.68);
        buttonHover    = vec4(0.240, 0.270, 0.330, 0.85);
        buttonActive   = vec4(0.300, 0.330, 0.400, 0.90);
        text           = vec4(0.960, 0.970, 0.990, 1.00);
        textMuted      = vec4(0.680, 0.720, 0.780, 1.00);
        tableHeaderBg  = headerBg;

        gold = vec4(1.00, 0.82, 0.22, 1.00);          // leader star
        emerald = vec4(0.30, 0.85, 0.45, 1.00);       // completed
        crimson = vec4(0.92, 0.32, 0.55, 1.00);       // heart / premium
        purple = vec4(0.55, 0.78, 1.00, 1.00);        // Pursuit night
        navy = vec4(0.20, 0.26, 0.34, 1.00);
        silver = vec4(0.85, 0.88, 0.94, 1.00);
        bronze = vec4(0.72, 0.58, 0.36, 1.00);
        teal = vec4(0.45, 0.70, 0.85, 1.00);
        dimNavy = vec4(0.120, 0.150, 0.190, 0.68);
        tileBg = vec4(0.160, 0.180, 0.220, 0.68);
        tileSelectedBg = vec4(0.240, 0.270, 0.330, 0.85);
        iceBlue = vec4(0.92, 0.96, 1.00, 1.00);

        windowRounding = 0.0f;
        childRounding = 0.0f;
        frameRounding = 0.0f;
        tabRounding = 0.0f;
    }
}

ThemePalette g_palette;

void RefreshPalette() {
    if (g_Theme == UiTheme::PursuitMatch) g_palette.SetPursuitMatch();
    else g_palette.SetObsidian();
}

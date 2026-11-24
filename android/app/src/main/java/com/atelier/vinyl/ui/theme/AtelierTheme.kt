package com.atelier.vinyl.ui.theme

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.LayoutDirection
import com.atelier.vinyl.model.AppLanguage
import com.atelier.vinyl.model.AppThemeMode

data class AtelierPalette(
    val isDark: Boolean,
    val canvas: Color,
    val surface: Color,
    val surfaceElevated: Color,
    val deckPlinth: Color,
    val recessed: Color,
    val textPrimary: Color,
    val textSecondary: Color,
    val textMuted: Color,
    val highlightRim: Color,
    val shadowDark: Color,
    val shadowLight: Color,
    val hairline: Color,
    val accentLed: Color,
    val visualizerRest: Color,
    val visualizerActive: Color
)

val LightAtelierPalette = AtelierPalette(
    isDark = false,
    canvas = Color(0xFFF3F4F8),
    surface = Color(0xFFFFFFFF),
    surfaceElevated = Color(0xFFFAFBFD),
    deckPlinth = Color(0xFFEAEDF3),
    recessed = Color(0xFFE4E7EF),
    textPrimary = Color(0xFF171920),
    textSecondary = Color(0xFF6F7687),
    textMuted = Color(0xFF98A0B0),
    highlightRim = Color(0xF5FFFFFF),
    shadowDark = Color(0x448E9BB4),
    shadowLight = Color(0xEBFFFFFF),
    hairline = Color(0x14181C26),
    accentLed = Color(0xFF3B4659),
    visualizerRest = Color(0xFF9AA3B3),
    visualizerActive = Color(0xFF3F4756)
)

val DarkAtelierPalette = AtelierPalette(
    isDark = true,
    canvas = Color(0xFF0E1015),
    surface = Color(0xFF171A22),
    surfaceElevated = Color(0xFF1D212B),
    deckPlinth = Color(0xFF191C24),
    recessed = Color(0xFF101319),
    textPrimary = Color(0xFFF1F3F8),
    textSecondary = Color(0xFF98A1B3),
    textMuted = Color(0xFF5F6778),
    highlightRim = Color(0x18FFFFFF),
    shadowDark = Color(0xB8000000),
    shadowLight = Color(0x0BFFFFFF),
    hairline = Color(0x12FFFFFF),
    accentLed = Color(0xFFD2DCEB),
    visualizerRest = Color(0xFF3B4252),
    visualizerActive = Color(0xFFCBD4E6)
)

data class AtelierStrings(
    val explore: String,
    val play: String,
    val playing: String,
    val pressings: String,
    val homeGreeting: String,
    val homeSubtitle: String,
    val openDeck: String,
    val albums: String,
    val artists: String,
    val playlists: String,
    val favorites: String,
    val equalizer: String,
    val queue: String,
    val settings: String,
    val search: String,
    val library: String,
    val importAudio: String,
    val scanDevice: String,
    val searchHint: String,
    val createPlaylistHint: String,
    val create: String,
    val sleepTimer: String,
    val off: String,
    val lightMode: String,
    val darkMode: String,
    val languageLabel: String,
    val hapticsLabel: String,
    val reduceMotionLabel: String,
    val stylusTracking: String,
    val cueing: String,
    val cueHover: String,
    val parked: String,
    val eqActive: String,
    val eqBypass: String,
    val clearQueue: String
)

val EnStrings = AtelierStrings(
    explore = "Explore",
    play = "Play",
    playing = "Playing",
    pressings = "Pressings",
    homeGreeting = "Listening Room",
    homeSubtitle = "Direct-drive precision audio console",
    openDeck = "Deck",
    albums = "Albums",
    artists = "Artists",
    playlists = "Playlists",
    favorites = "Favorites",
    equalizer = "Equalizer",
    queue = "Queue",
    settings = "Settings",
    search = "Search",
    library = "Library",
    importAudio = "Import Audio",
    scanDevice = "Scan Device",
    searchHint = "Search title, artist, album, format...",
    createPlaylistHint = "New playlist name...",
    create = "Create",
    sleepTimer = "Sleep Timer",
    off = "Off",
    lightMode = "Brushed Silver",
    darkMode = "Obsidian Dark",
    languageLabel = "Language",
    hapticsLabel = "Tactile Haptic Detents",
    reduceMotionLabel = "Reduce Motion",
    stylusTracking = "Stylus Tracking",
    cueing = "Tonearm Cueing",
    cueHover = "Cue Lifted",
    parked = "Tonearm Parked",
    eqActive = "Active",
    eqBypass = "Bypass",
    clearQueue = "Clear"
)

val FaStrings = AtelierStrings(
    explore = "کاوش",
    play = "پخش",
    playing = "در حال پخش",
    pressings = "صفحه",
    homeGreeting = "اتاق شنیدن",
    homeSubtitle = "کنسول صوتی درایو مستقیم",
    openDeck = "نمایش دک",
    albums = "آلبوم‌ها",
    artists = "خوانندگان",
    playlists = "پلی‌لیست‌ها",
    favorites = "علاقه‌مندی‌ها",
    equalizer = "اکولایزر",
    queue = "صف پخش",
    settings = "تنظیمات",
    search = "جستجو",
    library = "کتابخانه",
    importAudio = "افزودن فایل",
    scanDevice = "اسکن حافظه",
    searchHint = "جستجوی آهنگ، خواننده، آلبوم...",
    createPlaylistHint = "نام پلی‌لیست جدید...",
    create = "ساخت",
    sleepTimer = "تایمر خواب",
    off = "خاموش",
    lightMode = "نقره‌ای روشن",
    darkMode = "فلز تیره",
    languageLabel = "زبان",
    hapticsLabel = "لرزش لمسی هنگام چرخش",
    reduceMotionLabel = "کاهش حرکت",
    stylusTracking = "سوزن روی شیار",
    cueing = "حرکت بازو",
    cueHover = "بازو معلق",
    parked = "بازو در جایگاه",
    eqActive = "فعال",
    eqBypass = "غیرفعال",
    clearQueue = "پاک کردن"
)

val LocalAtelierPalette = staticCompositionLocalOf { LightAtelierPalette }
val LocalAtelierStrings = staticCompositionLocalOf { EnStrings }

@Composable
fun AtelierTheme(
    themeMode: AppThemeMode,
    language: AppLanguage,
    content: @Composable () -> Unit
) {
    val palette = if (themeMode == AppThemeMode.DARK) DarkAtelierPalette else LightAtelierPalette
    val strings = if (language == AppLanguage.FA) FaStrings else EnStrings
    val dir = if (language == AppLanguage.FA) LayoutDirection.Rtl else LayoutDirection.Ltr

    CompositionLocalProvider(
        LocalAtelierPalette provides palette,
        LocalAtelierStrings provides strings,
        LocalLayoutDirection provides dir,
        content = content
    )
}

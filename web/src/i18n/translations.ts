import { AppLanguage } from '../types/music';

export interface TranslationDict {
  appName: string;
  modelCode: string;
  nav: {
    home: string;
    explore: string;
    library: string;
    search: string;
  };
  explore: {
    title: string;
    play: string;
    playing: string;
    tracksCount: string;
    importAudio: string;
    hintRotate: string;
  };
  home: {
    greeting: string;
    subtitle: string;
    featuredTurntable: string;
    resumeSession: string;
    quickAccess: string;
    recentPressings: string;
    importFiles: string;
    albums: string;
    artists: string;
    playlists: string;
    favorites: string;
    equalizer: string;
    queue: string;
    settings: string;
    openDeck: string;
  };
  nowPlaying: {
    title: string;
    rpmBadge: string;
    tonearmActive: string;
    tonearmCueing: string;
    tonearmHover: string;
    tonearmParked: string;
    scratchHint: string;
    shuffle: string;
    repeatOff: string;
    repeatAll: string;
    repeatOne: string;
    queue: string;
    equalizer: string;
    sleepTimer: string;
    volume: string;
    addToPlaylist: string;
    favorite: string;
    speedToggle: string;
  };
  library: {
    title: string;
    allTracks: string;
    albums: string;
    artists: string;
    playlists: string;
    favorites: string;
    importBtn: string;
    importing: string;
    supportedFormats: string;
    emptyTracks: string;
    deleteTrack: string;
    addToQueue: string;
    playNext: string;
  };
  albums: {
    title: string;
    tracksUnit: string;
    playAlbum: string;
  };
  artists: {
    title: string;
    tracksUnit: string;
    playArtist: string;
  };
  playlists: {
    title: string;
    createTitle: string;
    namePlaceholder: string;
    createBtn: string;
    empty: string;
    addTrackPrompt: string;
    tracksUnit: string;
    deletePlaylist: string;
    playAll: string;
  };
  favorites: {
    title: string;
    emptyTitle: string;
    emptySubtitle: string;
  };
  search: {
    title: string;
    placeholder: string;
    noResults: string;
    resultsCount: string;
    quickFilters: string;
  };
  queue: {
    title: string;
    nowSpinning: string;
    upNext: string;
    clearUpcoming: string;
    empty: string;
    moveUp: string;
    moveDown: string;
    remove: string;
  };
  equalizer: {
    title: string;
    enabled: string;
    bypass: string;
    presets: string;
    preampNote: string;
    bassLabel: string;
    midLabel: string;
    trebleLabel: string;
  };
  settings: {
    title: string;
    appearance: string;
    themeMode: string;
    lightMode: string;
    darkMode: string;
    language: string;
    english: string;
    persian: string;
    playbackHardware: string;
    sleepTimer: string;
    off: string;
    minutes: string;
    haptics: string;
    reduceMotion: string;
    vinylSurface: string;
    nativeStatusTitle: string;
    nativeStatusSubtitle: string;
    capWebFileImport: string;
    capWebAudioFft: string;
    capWebOfflineIdb: string;
    capNativeMediaStore: string;
    capNativeLockscreen: string;
    capNativeBackground: string;
    statusSupported: string;
    statusNativeOnly: string;
    androidApkNote: string;
  };
  common: {
    back: string;
    close: string;
    cancel: string;
    save: string;
    done: string;
    importedToast: string;
    errorAudioFormat: string;
    minShort: string;
  };
}

export const TRANSLATIONS: Record<AppLanguage, TranslationDict> = {
  en: {
    appName: 'ATELIER',
    modelCode: 'LP-01',
    nav: {
      home: 'Home',
      explore: 'Explore',
      library: 'Library',
      search: 'Search',
    },
    explore: {
      title: 'Explore',
      play: 'Play',
      playing: 'Playing',
      tracksCount: 'Pressings',
      importAudio: 'Import Audio',
      hintRotate: 'Spin the arc to browse vinyl pressings',
    },
    home: {
      greeting: 'Listening Room',
      subtitle: 'Direct-drive precision audio console',
      featuredTurntable: 'Open Turntable',
      resumeSession: 'Resume Pressing',
      quickAccess: 'Studio Modules',
      recentPressings: 'Curated Pressings',
      importFiles: 'Import Track',
      albums: 'Albums',
      artists: 'Artists',
      playlists: 'Playlists',
      favorites: 'Favorites',
      equalizer: 'Equalizer',
      queue: 'Up Next',
      settings: 'Console',
      openDeck: 'Deck',
    },
    nowPlaying: {
      title: 'Now Playing',
      rpmBadge: '33⅓ RPM',
      tonearmActive: 'Stylus Tracking',
      tonearmCueing: 'Tonearm Cueing',
      tonearmHover: 'Cue Lifted',
      tonearmParked: 'Tonearm Parked',
      scratchHint: 'Touch & rotate vinyl to scrub',
      shuffle: 'Shuffle',
      repeatOff: 'Repeat Off',
      repeatAll: 'Repeat All',
      repeatOne: 'Repeat One',
      queue: 'Queue',
      equalizer: 'EQ',
      sleepTimer: 'Sleep Timer',
      volume: 'Gain',
      addToPlaylist: 'Add to Playlist',
      favorite: 'Favorite',
      speedToggle: 'Motor Drive',
    },
    library: {
      title: 'Library',
      allTracks: 'Tracks',
      albums: 'Albums',
      artists: 'Artists',
      playlists: 'Playlists',
      favorites: 'Favorites',
      importBtn: 'Import Audio',
      importing: 'Reading metadata...',
      supportedFormats: 'MP3, WAV, FLAC, AAC, M4A, OGG with ID3/cover extraction',
      emptyTracks: 'No tracks found. Import audio files from your device.',
      deleteTrack: 'Remove',
      addToQueue: 'Add to Queue',
      playNext: 'Play Next',
    },
    albums: {
      title: 'Albums',
      tracksUnit: 'tracks',
      playAlbum: 'Spin Album',
    },
    artists: {
      title: 'Artists',
      tracksUnit: 'tracks',
      playArtist: 'Play Artist',
    },
    playlists: {
      title: 'Playlists',
      createTitle: 'New Playlist',
      namePlaceholder: 'Late Night Vinyl...',
      createBtn: 'Create',
      empty: 'No playlists yet. Create your first crate.',
      addTrackPrompt: 'Tap a track in Library or Now Playing to add here.',
      tracksUnit: 'tracks',
      deletePlaylist: 'Delete',
      playAll: 'Play Crate',
    },
    favorites: {
      title: 'Favorites',
      emptyTitle: 'No favorited pressings yet',
      emptySubtitle: 'Tap the heart control on any record to pin it here.',
    },
    search: {
      title: 'Search',
      placeholder: 'Search title, artist, album, format...',
      noResults: 'No matching pressings found.',
      resultsCount: 'results',
      quickFilters: 'Quick Filters',
    },
    queue: {
      title: 'Playback Queue',
      nowSpinning: 'On the Platter',
      upNext: 'Queued Next',
      clearUpcoming: 'Clear Queue',
      empty: 'Queue is empty. Pick tracks from Explore or Library.',
      moveUp: 'Move up',
      moveDown: 'Move down',
      remove: 'Remove',
    },
    equalizer: {
      title: '5-Band Acoustic EQ',
      enabled: 'Active',
      bypass: 'Bypassed',
      presets: 'Tuning Curves',
      preampNote: 'Live Web Audio BiquadFilter chain routed before FFT analyzer',
      bassLabel: 'Bass',
      midLabel: 'Mid',
      trebleLabel: 'Treble',
    },
    settings: {
      title: 'Console Settings',
      appearance: 'Surface & Language',
      themeMode: 'Chassis Finish',
      lightMode: 'Brushed Silver (Light)',
      darkMode: 'Obsidian Anodized (Dark)',
      language: 'Language / Direction',
      english: 'English (LTR)',
      persian: 'فارسی (RTL)',
      playbackHardware: 'Turntable Mechanics',
      sleepTimer: 'Sleep Timer',
      off: 'Off',
      minutes: 'min',
      haptics: 'Tactile Haptic Detents',
      reduceMotion: 'Reduce Motion (Accessibility)',
      vinylSurface: 'Subtle Analog Groove Texture',
      nativeStatusTitle: 'Runtime & Android Native Capabilities',
      nativeStatusSubtitle:
        'Browser sandbox vs. native Kotlin + Jetpack Compose + Media3 build included in repository:',
      capWebFileImport: 'Local Audio File Import & ID3/FLAC/MP4 Metadata Extraction',
      capWebAudioFft: 'Real-Time FFT Spectrum Visualizer & 5-Band EQ',
      capWebOfflineIdb: 'Offline Persistence (Tracks, Playlists, Last Position)',
      capNativeMediaStore: 'Automatic Device MediaStore Scan (Android Native API)',
      capNativeLockscreen: 'OS Lock-Screen & Notification MediaStyle Controls (Android Media3)',
      capNativeBackground: 'Persistent OS Foreground Service Audio Playback (Android Native)',
      statusSupported: 'Active in Web',
      statusNativeOnly: 'Native Android Only (Unfinished on Web)',
      androidApkNote:
        'Full Kotlin + Jetpack Compose + Media3 source & CI APK workflow live under /android.',
    },
    common: {
      back: 'Back',
      close: 'Close',
      cancel: 'Cancel',
      save: 'Save',
      done: 'Done',
      importedToast: 'Imported track(s) into Library',
      errorAudioFormat: 'Unsupported or corrupted audio file',
      minShort: 'm',
    },
  },
  fa: {
    appName: 'آتلیه',
    modelCode: 'LP-01',
    nav: {
      home: 'خانه',
      explore: 'کاوش',
      library: 'کتابخانه',
      search: 'جستجو',
    },
    explore: {
      title: 'کاوش',
      play: 'پخش',
      playing: 'در حال پخش',
      tracksCount: 'صفحه',
      importAudio: 'افزودن فایل صوتی',
      hintRotate: 'برای مرور صفحه‌ها مسیر منحنی را بچرخانید',
    },
    home: {
      greeting: 'اتاق شنیدن',
      subtitle: 'کنسول صوتی درایو مستقیم با دقت استودیویی',
      featuredTurntable: 'گرامافون',
      resumeSession: 'ادامه پخش',
      quickAccess: 'بخش‌های استودیو',
      recentPressings: 'صفحه‌های منتخب',
      importFiles: 'وارد کردن آهنگ',
      albums: 'آلبوم‌ها',
      artists: 'خوانندگان',
      playlists: 'پلی‌لیست‌ها',
      favorites: 'علاقه‌مندی‌ها',
      equalizer: 'اکولایزر',
      queue: 'صف پخش',
      settings: 'تنظیمات',
      openDeck: 'نمایش دک',
    },
    nowPlaying: {
      title: 'در حال پخش',
      rpmBadge: '۳۳⅓ دور',
      tonearmActive: 'سوزن روی شیار',
      tonearmCueing: 'حرکت بازو',
      tonearmHover: 'بازو معلق',
      tonearmParked: 'بازو در جایگاه',
      scratchHint: 'برای جابه‌جایی زمان، صفحه را لمس کرده و بچرخانید',
      shuffle: 'پخش تصادفی',
      repeatOff: 'تکرار خاموش',
      repeatAll: 'تکرار همه',
      repeatOne: 'تکرار تک‌آهنگ',
      queue: 'صف پخش',
      equalizer: 'اکولایزر',
      sleepTimer: 'تایمر خواب',
      volume: 'ولوم',
      addToPlaylist: 'افزودن به پلی‌لیست',
      favorite: 'علاقه‌مندی',
      speedToggle: 'موتور درایو',
    },
    library: {
      title: 'کتابخانه موسیقی',
      allTracks: 'آهنگ‌ها',
      albums: 'آلبوم‌ها',
      artists: 'خوانندگان',
      playlists: 'پلی‌لیست‌ها',
      favorites: 'علاقه‌مندی‌ها',
      importBtn: 'وارد کردن فایل',
      importing: 'در حال خواندن متادیتا...',
      supportedFormats: 'پشتیبانی از MP3, WAV, FLAC, AAC, M4A, OGG با استخراج کاور و تگ‌ها',
      emptyTracks: 'هیچ آهنگی یافت نشد. فایل صوتی وارد کنید.',
      deleteTrack: 'حذف',
      addToQueue: 'افزودن به صف',
      playNext: 'پخش بعدی',
    },
    albums: {
      title: 'آلبوم‌ها',
      tracksUnit: 'قطعه',
      playAlbum: 'پخش آلبوم',
    },
    artists: {
      title: 'خوانندگان',
      tracksUnit: 'قطعه',
      playArtist: 'پخش آثار',
    },
    playlists: {
      title: 'پلی‌لیست‌ها',
      createTitle: 'پلی‌لیست جدید',
      namePlaceholder: 'مثلاً شب‌های آرام وینیل...',
      createBtn: 'ساخت',
      empty: 'هنوز پلی‌لیستی نساخته‌اید.',
      addTrackPrompt: 'از کتابخانه یا صفحه پخش، آهنگ‌ها را اضافه کنید.',
      tracksUnit: 'قطعه',
      deletePlaylist: 'حذف',
      playAll: 'پخش لیست',
    },
    favorites: {
      title: 'علاقه‌مندی‌ها',
      emptyTitle: 'هنوز آهنگی نشان‌گذاری نشده',
      emptySubtitle: 'دکمه قلب را روی هر صفحه بزنید تا اینجا ذخیره شود.',
    },
    search: {
      title: 'جستجوی موسیقی',
      placeholder: 'نام آهنگ، خواننده، آلبوم یا فرمت...',
      noResults: 'موردی پیدا نشد.',
      resultsCount: 'نتیجه',
      quickFilters: 'فیلتر سریع',
    },
    queue: {
      title: 'صف پخش',
      nowSpinning: 'روی صفحه گرامافون',
      upNext: 'در ادامه پخش می‌شود',
      clearUpcoming: 'پاک کردن صف',
      empty: 'صف پخش خالی است.',
      moveUp: 'بالا',
      moveDown: 'پایین',
      remove: 'حذف',
    },
    equalizer: {
      title: 'اکولایزر ۵ بانده',
      enabled: 'فعال',
      bypass: 'غیرفعال',
      presets: 'پروفیل‌های صدا',
      preampNote: 'پردازش واقعی Web Audio پیش از آنالایزر فرکانسی',
      bassLabel: 'بیس (Bass)',
      midLabel: 'میانی (Mid)',
      trebleLabel: 'زیر (Treble)',
    },
    settings: {
      title: 'تنظیمات کنسول',
      appearance: 'ظاهر و زبان',
      themeMode: 'جنس بدنه و تم',
      lightMode: 'نقره‌ای برس‌خورده (روشن)',
      darkMode: 'فلز تیره آنودایزشده (تاریک)',
      language: 'زبان و جهت چیدمان',
      english: 'English (LTR)',
      persian: 'فارسی (RTL)',
      playbackHardware: 'مکانیک گرامافون',
      sleepTimer: 'تایمر خواب',
      off: 'خاموش',
      minutes: 'دقیقه',
      haptics: 'لرزش لمسی هنگام چرخش',
      reduceMotion: 'کاهش حرکت (دسترس‌پذیری)',
      vinylSurface: 'بافت آنالوگ ملایم صفحه',
      nativeStatusTitle: 'وضعیت قابلیت‌ها (وب در برابر اندروید بومی)',
      nativeStatusSubtitle:
        'تفکیک قابلیت‌های فعال در محیط وب از APIهای بومی اندروید (نسخه کامل Kotlin/Media3 در پوشه /android موجود است):',
      capWebFileImport: 'وارد کردن فایل صوتی و استخراج تگ و کاور (ID3/FLAC/MP4)',
      capWebAudioFft: 'نمایشگر فرکانسی واقعی (FFT) و اکولایزر ۵ بانده',
      capWebOfflineIdb: 'ذخیره آفلاین آهنگ‌ها، پلی‌لیست‌ها و آخرین وضعیت پخش',
      capNativeMediaStore: 'اسکن خودکار حافظه دستگاه (نیازمند API بومی MediaStore اندروید)',
      capNativeLockscreen: 'کنترل از نوتیفیکیشن و صفحه قفل (نیازمند Media3 اندروید)',
      capNativeBackground: 'سرویس پخش پس‌زمینه سیستم‌عامل (نیازمند Foreground Service اندروید)',
      statusSupported: 'فعال در نسخه وب',
      statusNativeOnly: 'تکمیل‌نشده در وب (نیازمند API بومی اندروید)',
      androidApkNote:
        'سورس کامل Kotlin + Jetpack Compose + Media3 و ورک‌فلو ساخت APK در پوشه /android پیاده‌سازی شده است.',
    },
    common: {
      back: 'بازگشت',
      close: 'بستن',
      cancel: 'لغو',
      save: 'ذخیره',
      done: 'تأیید',
      importedToast: 'فایل صوتی به کتابخانه اضافه شد',
      errorAudioFormat: 'فایل صوتی نامعتبر یا پشتیبانی‌نشده است',
      minShort: 'دقیقه',
    },
  },
};

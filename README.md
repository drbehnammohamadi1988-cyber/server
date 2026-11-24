# ATELIER LP-01 · Tactile Vinyl Music Player

Precision industrial music player implementing Soft Neumorphism, Realistic Skeuomorphism, Spatial UI, and physics-based motion design across both **Native Android** (`Kotlin` + `Jetpack Compose` + `Media3`) and **Interactive Web** (`React` + `TypeScript` + `Motion` + `Canvas` + `Web Audio API`).

## Architecture

- **`/android`**: Native Android application (`minSdk 26`, `targetSdk 35`) using **Jetpack Compose** custom `Canvas` hardware rendering, **AndroidX Media3 (`ExoPlayer` + `MediaSessionService`)** for real offline/background/lock-screen playback, `MediaStore` scanner, `MediaMetadataRetriever` file importer, 5-band hardware `Equalizer`, and `Visualizer` FFT spectrum analysis.
- **`/web`**: Interactive browser studio console using **React 19 + TypeScript + Vite + Framer Motion**, HTML5 Canvas turntable & curved orbital vinyl wheel, real **Web Audio API** (`BiquadFilterNode` 5-band EQ + `AnalyserNode` FFT), pure-TS binary ID3v2/FLAC metadata & cover parser, IndexedDB offline persistence, and bilingual English (LTR) + Persian (RTL) support.

## Visual & Physics Highlights

- **Explore Curved Orbital Wheel**: Non-linear rotary arc geometry with pointer-velocity inertia, exponential friction, magnetic spring detents, radial text tilt, depth-of-field blur, and haptic ticks.
- **Top-Down Luxury Turntable**: Brushed anodized chassis (Silver Light / Obsidian Dark), top hinge pins, corner rotary speed knob (`33⅓` / `45` RPM), tactile Start/Stop button, stationary fixed-light anisotropic bow-tie vinyl reflections over micro-grooves, rotating cover-art center label, and circular touch-to-scratch scrubbing.
- **Mechanical Tonearm**: Independent gimbal pivot, counterweight barrel, dynamic 3D elevation shadow (`cueZ`), cue-in sweep on Play, groove progress tracking, hover-lift on Pause, and auto-return on track end.
- **Screens**: Home, Explore, Now Playing, Library, Albums, Artists, Playlists, Favorites, Search, Queue, 5-Band Equalizer, and Settings.

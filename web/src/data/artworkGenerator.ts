export type CoverMotif =
  | 'archive_daylight'
  | 'horizon_yellow'
  | 'dreams_stripe'
  | 'cassette_portrait'
  | 'crimson_bauhaus'
  | 'forgotten_mist'
  | 'phantom_arch'
  | 'one_week_ivory'
  | 'nocturne_silver'
  | 'solstice_slate';

function svgToDataUrl(svg: string): string {
  return `data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg.trim())}`;
}

export function generateCoverArt(motif: CoverMotif): string {
  switch (motif) {
    case 'archive_daylight':
      // High-contrast monochrome typographic pressing inspired by "Day light" in reference
      return svgToDataUrl(`
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">
          <defs>
            <linearGradient id="g1" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stop-color="#1E2024"/>
              <stop offset="55%" stop-color="#0C0D10"/>
              <stop offset="100%" stop-color="#272A30"/>
            </linearGradient>
            <radialGradient id="sheen" cx="35%" cy="30%" r="65%">
              <stop offset="0%" stop-color="rgba(255,255,255,0.20)"/>
              <stop offset="100%" stop-color="rgba(255,255,255,0)"/>
            </radialGradient>
          </defs>
          <rect width="400" height="400" fill="url(#g1)"/>
          <path d="M-20 260 Q 130 140 240 220 T 440 120 L 440 420 L -20 420 Z" fill="#14161A"/>
          <circle cx="200" cy="200" r="158" fill="none" stroke="rgba(255,255,255,0.08)" stroke-width="1"/>
          <g transform="translate(200,200) rotate(-90)">
            <text x="0" y="18" text-anchor="middle" font-family="Plus Jakarta Sans, Helvetica, Arial, sans-serif" font-weight="800" font-size="48" letter-spacing="4" fill="#F2F4F8">ARCHIVE</text>
            <text x="0" y="-26" text-anchor="middle" font-family="Plus Jakarta Sans, Helvetica, Arial, sans-serif" font-weight="600" font-size="16" letter-spacing="10" fill="rgba(255,255,255,0.55)">THE EDITION</text>
          </g>
          <rect width="400" height="400" fill="url(#sheen)"/>
        </svg>
      `);

    case 'horizon_yellow':
      // Bold acid-yellow + charcoal street-poster texture inspired by "Horizon" in reference
      return svgToDataUrl(`
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">
          <defs>
            <linearGradient id="hy" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stop-color="#ECEE45"/>
              <stop offset="50%" stop-color="#D4D928"/>
              <stop offset="100%" stop-color="#22252A"/>
            </linearGradient>
          </defs>
          <rect width="400" height="400" fill="url(#hy)"/>
          <circle cx="115" cy="145" r="130" fill="#EAEF3C" opacity="0.88"/>
          <path d="M180 60 L380 40 L390 380 L120 390 Z" fill="#17191D" opacity="0.82"/>
          <path d="M70 210 Q180 155 290 230 T400 190" stroke="#F4F85A" stroke-width="6" fill="none" opacity="0.6"/>
          <g fill="#0E1013" font-family="Plus Jakarta Sans, sans-serif" font-weight="800">
            <text x="58" y="158" font-size="38" letter-spacing="-1">HORIZON</text>
            <text x="64" y="198" font-size="24" letter-spacing="3" fill="#2A2D33">CREATE</text>
            <text x="64" y="226" font-size="18" letter-spacing="6" fill="#F2F562">SOLAR 04</text>
          </g>
        </svg>
      `);

    case 'dreams_stripe':
      // Crisp diagonal black/off-white modernist graphic inspired by "Dreams" in reference
      return svgToDataUrl(`
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">
          <rect width="400" height="400" fill="#F2F3F6"/>
          <g transform="rotate(-38 200 200)">
            <rect x="-100" y="30" width="600" height="72" rx="36" fill="#181A1E"/>
            <rect x="-100" y="164" width="600" height="72" rx="36" fill="#181A1E"/>
            <rect x="-100" y="298" width="600" height="72" rx="36" fill="#181A1E"/>
          </g>
          <circle cx="200" cy="200" r="68" fill="#F4F5F8" stroke="#181A1E" stroke-width="6"/>
          <text x="200" y="206" text-anchor="middle" font-family="JetBrains Mono, monospace" font-weight="600" font-size="16" letter-spacing="3" fill="#181A1E">DREAMS</text>
        </svg>
      `);

    case 'cassette_portrait':
      // High-contrast monochrome side profile silhouette inspired by "Cassette" in reference
      return svgToDataUrl(`
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">
          <defs>
            <linearGradient id="bgc" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stop-color="#FAFBFD"/>
              <stop offset="100%" stop-color="#E5E8EE"/>
            </linearGradient>
          </defs>
          <rect width="400" height="400" fill="url(#bgc)"/>
          <path d="M 190 70 C 265 72, 318 125, 315 205 C 312 245, 290 275, 275 300 L 290 400 L 95 400 C 102 340, 128 308, 138 278 C 110 245, 102 180, 128 125 C 145 90, 165 70, 190 70 Z" fill="#16181C"/>
          <path d="M 122 178 C 98 185, 92 215, 114 232 C 122 252, 134 268, 152 276" fill="none" stroke="#16181C" stroke-width="18" stroke-linecap="round"/>
          <circle cx="235" cy="185" r="90" fill="none" stroke="rgba(255,255,255,0.08)" stroke-width="1.5"/>
          <text x="48" y="356" font-family="JetBrains Mono, monospace" font-size="15" font-weight="600" letter-spacing="4" fill="#6E7585">SIDE A · 33⅓</text>
        </svg>
      `);

    case 'crimson_bauhaus':
      // Architectural split silver & slate contrast inspired by "Crimson" in reference
      return svgToDataUrl(`
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">
          <rect width="400" height="400" fill="#ECEEF3"/>
          <path d="M 200 0 L 400 0 L 400 400 L 200 400 A 200 200 0 0 1 200 0 Z" fill="#A4AAB6"/>
          <circle cx="200" cy="200" r="118" fill="#D2D6DF"/>
          <path d="M 200 82 A 118 118 0 0 1 200 318 Z" fill="#1E222A"/>
          <circle cx="200" cy="200" r="44" fill="#F4F5F8"/>
          <text x="200" y="205" text-anchor="middle" font-family="Plus Jakarta Sans, sans-serif" font-size="13" font-weight="700" letter-spacing="3" fill="#232730">CRIMSON</text>
        </svg>
      `);

    case 'forgotten_mist':
      return svgToDataUrl(`
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">
          <defs>
            <radialGradient id="fm" cx="40%" cy="35%" r="70%">
              <stop offset="0%" stop-color="#FFFFFF"/>
              <stop offset="55%" stop-color="#D7DCE5"/>
              <stop offset="100%" stop-color="#9BA3B4"/>
            </radialGradient>
          </defs>
          <rect width="400" height="400" fill="url(#fm)"/>
          <circle cx="200" cy="200" r="140" fill="none" stroke="rgba(24,26,32,0.16)" stroke-width="1.5"/>
          <circle cx="200" cy="200" r="95" fill="none" stroke="rgba(24,26,32,0.24)" stroke-width="1"/>
          <text x="200" y="206" text-anchor="middle" font-family="Plus Jakarta Sans, sans-serif" font-weight="700" font-size="22" letter-spacing="8" fill="#2D323E">FORGOTTEN</text>
        </svg>
      `);

    case 'phantom_arch':
      return svgToDataUrl(`
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">
          <defs>
            <linearGradient id="pa" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stop-color="#E7EAEF"/>
              <stop offset="100%" stop-color="#B9C0CE"/>
            </linearGradient>
          </defs>
          <rect width="400" height="400" fill="url(#pa)"/>
          <path d="M120 340 L120 180 A80 80 0 0 1 280 180 L280 340 Z" fill="#20232B"/>
          <path d="M152 340 L152 184 A48 48 0 0 1 248 184 L248 340 Z" fill="#E3E6EC"/>
          <circle cx="200" cy="184" r="22" fill="#20232B"/>
        </svg>
      `);

    case 'one_week_ivory':
      // Classic studio cream paper vinyl center label inspired by "One Week Last"
      return svgToDataUrl(`
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">
          <defs>
            <radialGradient id="ow" cx="38%" cy="32%" r="72%">
              <stop offset="0%" stop-color="#F7F8FA"/>
              <stop offset="65%" stop-color="#E6E8EE"/>
              <stop offset="100%" stop-color="#D2D6E0"/>
            </radialGradient>
          </defs>
          <rect width="400" height="400" fill="url(#ow)"/>
          <circle cx="200" cy="200" r="165" fill="none" stroke="rgba(30,34,42,0.14)" stroke-width="1.5"/>
          <circle cx="200" cy="200" r="154" fill="none" stroke="rgba(30,34,42,0.08)" stroke-width="1"/>
          <text x="200" y="138" text-anchor="middle" font-family="JetBrains Mono, monospace" font-size="14" font-weight="600" letter-spacing="4" fill="#596070">ATELIER PRESSING</text>
          <text x="200" y="274" text-anchor="middle" font-family="Plus Jakarta Sans, sans-serif" font-size="20" font-weight="700" letter-spacing="1" fill="#181A20">ONE WEEK LAST</text>
          <text x="200" y="300" text-anchor="middle" font-family="JetBrains Mono, monospace" font-size="13" letter-spacing="3" fill="#7D8596">33⅓ RPM · STEREO</text>
        </svg>
      `);

    case 'nocturne_silver':
      return svgToDataUrl(`
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">
          <defs>
            <linearGradient id="ns" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stop-color="#222630"/>
              <stop offset="100%" stop-color="#0E1015"/>
            </linearGradient>
          </defs>
          <rect width="400" height="400" fill="url(#ns)"/>
          <circle cx="200" cy="200" r="130" fill="none" stroke="#8C95A8" stroke-width="1.5" stroke-dasharray="6 8"/>
          <circle cx="200" cy="200" r="76" fill="#D9DFE9"/>
          <text x="200" y="206" text-anchor="middle" font-family="Plus Jakarta Sans, sans-serif" font-weight="800" font-size="18" letter-spacing="5" fill="#14171F">NOCTURNE</text>
        </svg>
      `);

    case 'solstice_slate':
      return svgToDataUrl(`
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">
          <rect width="400" height="400" fill="#DDE2EC"/>
          <circle cx="200" cy="175" r="96" fill="#4B5568"/>
          <rect x="60" y="215" width="280" height="140" fill="#F2F4F8" opacity="0.9"/>
          <line x1="60" y1="215" x2="340" y2="215" stroke="#252A34" stroke-width="3"/>
          <text x="200" y="285" text-anchor="middle" font-family="JetBrains Mono, monospace" font-weight="600" font-size="18" letter-spacing="6" fill="#252A34">SOLSTICE</text>
        </svg>
      `);
  }
}

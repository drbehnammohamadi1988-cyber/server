/// Handcrafted visual themes supported by the live multi-theme engine.
enum AppThemePreset {
  cosmicGlass(
    id: 'cosmic_glass',
    labelFa: 'شیشه کیهانی',
    subtitleFa: 'پس‌زمینه عمیق شب با هاله بنفش و شیشه دودی نورانی',
    isDark: true,
  ),
  darkNeumorphism(
    id: 'dark_neumorphism',
    labelFa: 'نئومورفیسم تاریک',
    subtitleFa: 'سطوح مات مدرن با سایه‌های برجسته و فرورفته و اکسنت نئونی',
    isDark: true,
  ),
  softCeramic(
    id: 'soft_ceramic',
    labelFa: 'سرامیک روشن',
    subtitleFa: 'نئومورفیسم سفید سرامیکی مینیمال و لمس‌پذیر برای استفاده روزانه',
    isDark: false,
  ),
  pureAmoled(
    id: 'pure_amoled',
    labelFa: 'آمُلد خالص',
    subtitleFa: 'مشکی مطلق OLED با خطوط نورانی تند برای صرفه‌جویی باتری',
    isDark: true,
  ),
  frostLight(
    id: 'frost_light',
    labelFa: 'شیشه یخی روشن',
    subtitleFa: 'شیشه‌گرایی پاستلی ملایم با شفافیت روشن و حاشیه کریستالی',
    isDark: false,
  );

  const AppThemePreset({
    required this.id,
    required this.labelFa,
    required this.subtitleFa,
    required this.isDark,
  });

  final String id;
  final String labelFa;
  final String subtitleFa;
  final bool isDark;

  static AppThemePreset fromId(String? id) {
    for (final preset in AppThemePreset.values) {
      if (preset.id == id) return preset;
    }
    return AppThemePreset.cosmicGlass;
  }
}

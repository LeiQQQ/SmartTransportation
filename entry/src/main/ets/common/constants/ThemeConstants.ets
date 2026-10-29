/**
 * 全局视觉规范：配色、圆角、间距、字号
 */
export class ThemeConstants {
  // 主色
  static readonly PRIMARY: string = '#0F6FFF';
  static readonly PRIMARY_LIGHT: string = '#E8F1FF';

  // 背景与卡片
  static readonly BG_PAGE: string = '#F5F7FA';
  static readonly BG_CARD: string = '#FFFFFF';

  // 文本
  static readonly TEXT_MAIN: string = '#1A1A1A';
  static readonly TEXT_SUB: string = '#8A94A6';
  static readonly TEXT_INVERT: string = '#FFFFFF';
  static readonly DIVIDER: string = '#EDF0F5';

  // 拥堵五级色（与 TrafficUtil 的 level 一一对应）
  static readonly LEVEL_CLEAR: string = '#00C48C';
  static readonly LEVEL_BASIC: string = '#7ED321';
  static readonly LEVEL_LIGHT: string = '#FFB020';
  static readonly LEVEL_MODERATE: string = '#FF7A45';
  static readonly LEVEL_SEVERE: string = '#FF3B30';

  // 相位色
  static readonly PHASE_COLORS: string[] = ['#4A90E2', '#50C878', '#F5A623', '#9B59B6'];

  // 尺寸
  static readonly RADIUS_CARD: number = 16;
  static readonly RADIUS_SMALL: number = 8;
  static readonly SPACE_PAGE: number = 16;
  static readonly SPACE_CARD: number = 12;
  static readonly BAR_HEIGHT: number = 56;

  // 字号
  static readonly FONT_TITLE: number = 20;
  static readonly FONT_SUBTITLE: number = 16;
  static readonly FONT_BODY: number = 14;
  static readonly FONT_CAPTION: number = 12;
  static readonly FONT_NUMBER: number = 36;
}

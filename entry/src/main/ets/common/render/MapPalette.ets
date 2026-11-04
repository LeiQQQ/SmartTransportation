/**
 * 地图配色与标注参数
 *
 * 原来这些常量散落在 TrafficMapPage 顶部，和绘制代码混在一个文件里。
 * 集中到一处后：调观感只改这个文件，渲染层不必再关心具体色值。
 */
export class MapPalette {
  /** 城区底色（百度瓦片观感：浅灰白） */
  static readonly BG: string = '#F6F5F2';
  /** 城内底色（比城外略深，衬托城墙） */
  static readonly INNER: string = '#F3F2ED';
  /** 环城公园带 */
  static readonly PARK: string = '#D6EAC9';
  /** 城内绿地 */
  static readonly GREEN: string = '#CFE7C1';
  static readonly GREEN_EDGE: string = '#BFDCAC';
  /** 护城河 */
  static readonly WATER: string = '#ABD3F0';
  /** 城墙体与描边 */
  static readonly WALL: string = '#B5B0A8';
  static readonly WALL_EDGE: string = '#9A948C';
  /** 路面 */
  static readonly ROAD: string = '#FFFFFF';
  /** 主干边线 */
  static readonly CURB: string = '#CFCBC2';
  /** 支路边线（更浅，避免图面发脏） */
  static readonly CURB_MINOR: string = '#E1DED7';

  /** 路名 */
  static readonly LABEL_TEXT: string = '#3F3F3F';
  /** 白色描边，保证压在路况色带上仍清晰 */
  static readonly LABEL_HALO: string = '#FFFFFF';
  /** 拥堵路名与拥堵节点名：深红加粗，从满图灰字里跳出来 */
  static readonly LABEL_ALERT: string = '#B3261E';
  /** 节点名与节点样式 */
  static readonly NODE_TEXT: string = '#4A4A4A';
  static readonly NODE_FILL: string = '#FFFFFF';
  static readonly NODE_EDGE: string = '#8E8A83';
  /** 拥堵色带外描边：和白色路面拉开对比 */
  static readonly TRAFFIC_EDGE: string = 'rgba(150, 32, 26, 0.5)';

  /** 路名标注的最短屏幕长度（vp）：太短的路段不标，避免文字压过道路 */
  static readonly MIN_LABEL_LEN: number = 32;
  /** 拥堵路段的最短标注长度：比普通路段放宽，保证"哪条堵了"一定有名字 */
  static readonly MIN_ALERT_LABEL_LEN: number = 16;
}

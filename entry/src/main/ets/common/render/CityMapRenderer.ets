import { MapGeometry } from '../constants/MapGeometry';
import { MapCanvasBase, MapRenderData } from './MapCanvasBase';
import { MapPalette } from './MapPalette';
import { RoadLayer } from './RoadLayer';
import { LabelLayer } from './LabelLayer';

/**
 * 城墙内片区渲染器
 *
 * 页面只需要调用 render(data)，不再关心图层顺序与绘制细节。
 * 分层顺序即叠放顺序：
 *   底色 → 护城河 → 绿地 → 城内底 → 城墙 → 城门 → 道路 → 路况带 → 点 → 路名 → 路口名 → 指北针
 */
export class CityMapRenderer extends MapCanvasBase {
  private roadLayer: RoadLayer;
  private labelLayer: LabelLayer;

  constructor(ctx: CanvasRenderingContext2D) {
    super(ctx);
    this.roadLayer = new RoadLayer(ctx);
    this.labelLayer = new LabelLayer(ctx);
  }

  /** 画一帧：整帧重绘，调用方只需保证 data 是最新的 */
  render(data: MapRenderData): void {
    this.setData(data);
    this.ctx.clearRect(0, 0, data.canvasW, data.canvasH);
    this.drawBase();
    this.drawRiver();
    this.drawGreens();
    this.drawWall();
    this.roadLayer.setData(data);
    this.roadLayer.draw();
    this.labelLayer.setData(data);
    this.labelLayer.draw();
    this.drawCompass();
  }

  /** 底图：整片浅灰白（百度地图城区底色，不画网格） */
  private drawBase(): void {
    this.ctx.fillStyle = MapPalette.BG;
    this.ctx.fillRect(0, 0, this.w, this.h);
  }

  /** 护城河：沿城墙外一圈矩形描粗线，得到环状水面 */
  private drawRiver(): void {
    this.ctx.globalAlpha = 0.92;
    this.strokePolyline(MapGeometry.RIVER, 7.5, MapPalette.WATER, true);
    this.ctx.globalAlpha = 1;
  }

  /** 绿化：环城公园带 + 城内绿地广场 */
  private drawGreens(): void {
    this.fillPolygon(MapGeometry.PARK_BELT, MapPalette.PARK);
    for (let i = 0; i < MapGeometry.GREENS.length; i++) {
      this.fillPolygon(MapGeometry.GREENS[i].points, MapPalette.GREEN);
      this.strokePolyline(MapGeometry.GREENS[i].points, 1, MapPalette.GREEN_EDGE, true);
    }
  }

  /** 城墙：城内底色 + 墙体（外深内浅做出厚度）+ 四门地标 */
  private drawWall(): void {
    this.fillPolygon(MapGeometry.WALL, MapPalette.INNER);
    this.strokePolyline(MapGeometry.WALL, 5.4, MapPalette.WALL_EDGE, true);
    this.strokePolyline(MapGeometry.WALL, 3.6, MapPalette.WALL, true);
    this.drawGates();
  }

  /** 城门：城墙上的门洞地标（长乐门/永宁门/安定门/安远门） */
  private drawGates(): void {
    for (let i = 0; i < MapGeometry.GATES.length; i++) {
      const x: number = this.xOf(MapGeometry.GATES[i].lon);
      const y: number = this.yOf(MapGeometry.GATES[i].lat);
      this.ctx.fillStyle = MapPalette.WALL_EDGE;
      this.ctx.fillRect(x - 3.4, y - 3.4, 6.8, 6.8);
      this.ctx.fillStyle = MapPalette.INNER;
      this.ctx.fillRect(x - 1.5, y - 1.5, 3, 3);
    }
  }

  /** 指北针 */
  private drawCompass(): void {
    const x: number = this.w - 26;
    const y: number = 30;
    this.ctx.beginPath();
    this.ctx.strokeStyle = MapPalette.WALL;
    this.ctx.lineWidth = 1.2;
    this.ctx.arc(x, y, 11, 0, Math.PI * 2);
    this.ctx.stroke();
    this.ctx.fillStyle = MapPalette.WALL;
    this.ctx.font = 'bold 10vp sans-serif';
    this.ctx.textAlign = 'center';
    this.ctx.fillText('N', x, y - 15);
    this.ctx.beginPath();
    this.ctx.moveTo(x, y - 7);
    this.ctx.lineTo(x - 4, y + 5);
    this.ctx.lineTo(x + 4, y + 5);
    this.ctx.closePath();
    this.ctx.fill();
  }
}

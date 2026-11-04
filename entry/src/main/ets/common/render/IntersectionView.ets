/**
 * 路口示意图渲染
 *
 * 原来这段画在 IntersectionDetailPage 里，和页面状态（相位、倒计时、收藏）
 * 混在一个 struct。抽出来之后：页面只负责算「每个进口道几辆车、是不是绿灯」，
 * 这里只负责画——想换一套示意风格不必碰业务代码。
 */
export interface IntersectionScene {
  canvasW: number;
  canvasH: number;
  /** 车流动画相位 0~1，绿灯时车辆随之前进 */
  shift: number;
  /** 各进口道排队车辆数（辆） */
  queues: Map<string, number>;
  /** 各进口道是否绿灯 */
  greens: Map<string, boolean>;
}

export class IntersectionView {
  /** 绿灯放行的车辆颜色 */
  private static readonly CAR_MOVING: string = '#2E7D32';
  /** 排队停止的车辆颜色 */
  private static readonly CAR_WAITING: string = '#4A5568';
  /** 单个进口道最多画几辆车：再多也看不出区别，反而糊成一片 */
  private static readonly MAX_CARS: number = 6;
  /** 路宽的一半（vp） */
  private static readonly ROAD_HALF: number = 34;

  private ctx: CanvasRenderingContext2D;

  constructor(ctx: CanvasRenderingContext2D) {
    this.ctx = ctx;
  }

  render(scene: IntersectionScene): void {
    const w: number = scene.canvasW;
    const h: number = scene.canvasH;
    if (w <= 0 || h <= 0) {
      return;
    }
    const cx: number = w / 2;
    const cy: number = h / 2;
    const road: number = IntersectionView.ROAD_HALF;

    this.ctx.clearRect(0, 0, w, h);

    // 路面
    this.ctx.fillStyle = '#E9EDF4';
    this.ctx.fillRect(0, cy - road, w, road * 2);
    this.ctx.fillRect(cx - road, 0, road * 2, h);

    // 车道分隔虚线
    this.ctx.strokeStyle = '#FFFFFF';
    this.ctx.lineWidth = 1.5;
    this.ctx.setLineDash([8, 8]);
    this.ctx.beginPath();
    this.ctx.moveTo(0, cy);
    this.ctx.lineTo(cx - road, cy);
    this.ctx.moveTo(cx + road, cy);
    this.ctx.lineTo(w, cy);
    this.ctx.moveTo(cx, 0);
    this.ctx.lineTo(cx, cy - road);
    this.ctx.moveTo(cx, cy + road);
    this.ctx.lineTo(cx, h);
    this.ctx.stroke();
    this.ctx.setLineDash([]);

    // 路口中心
    this.ctx.fillStyle = '#DCE3ED';
    this.ctx.fillRect(cx - road, cy - road, road * 2, road * 2);

    // 四个方向的车辆
    this.drawEast(scene, w, cx, cy, road);
    this.drawWest(scene, cx, cy, road);
    this.drawNorth(scene, cy, cx, road);
    this.drawSouth(scene, h, cy, cx, road);

    // 方向文字
    this.ctx.fillStyle = '#8A94A6';
    this.ctx.font = '11vp sans-serif';
    this.ctx.textAlign = 'center';
    this.ctx.fillText('北', cx, 16);
    this.ctx.fillText('南', cx, h - 8);
    this.ctx.textAlign = 'left';
    this.ctx.fillText('西', 8, cy - road - 8);
    this.ctx.textAlign = 'right';
    this.ctx.fillText('东', w - 8, cy - road - 8);
  }

  private queueOf(scene: IntersectionScene, dir: string): number {
    return Math.min(IntersectionView.MAX_CARS, scene.queues.get(dir) ?? 0);
  }

  private isGreen(scene: IntersectionScene, dir: string): boolean {
    return scene.greens.get(dir) === true;
  }

  /** 绿灯时车辆向前移动的距离，形成前进动画 */
  private moveOf(scene: IntersectionScene, dir: string): number {
    return this.isGreen(scene, dir) ? scene.shift * 18 : 0;
  }

  private colorOf(scene: IntersectionScene, dir: string): string {
    return this.isGreen(scene, dir) ? IntersectionView.CAR_MOVING : IntersectionView.CAR_WAITING;
  }

  private drawVehicle(x: number, y: number, color: string): void {
    this.ctx.fillStyle = color;
    this.ctx.fillRect(x - 6, y - 9, 12, 18);
  }

  private drawEast(scene: IntersectionScene, w: number, cx: number, cy: number, road: number): void {
    const queue: number = this.queueOf(scene, 'EAST');
    const move: number = this.moveOf(scene, 'EAST');
    const color: string = this.colorOf(scene, 'EAST');
    for (let i = 0; i < queue; i++) {
      const x: number = cx + road + 14 + i * 20 - move;
      if (x > w - 10) {
        continue;
      }
      this.drawVehicle(x, cy + 14, color);
    }
  }

  private drawWest(scene: IntersectionScene, cx: number, cy: number, road: number): void {
    const queue: number = this.queueOf(scene, 'WEST');
    const move: number = this.moveOf(scene, 'WEST');
    const color: string = this.colorOf(scene, 'WEST');
    for (let i = 0; i < queue; i++) {
      const x: number = cx - road - 14 - i * 20 + move;
      if (x < 10) {
        continue;
      }
      this.drawVehicle(x, cy - 14, color);
    }
  }

  private drawNorth(scene: IntersectionScene, cy: number, cx: number, road: number): void {
    const queue: number = this.queueOf(scene, 'NORTH');
    const move: number = this.moveOf(scene, 'NORTH');
    const color: string = this.colorOf(scene, 'NORTH');
    for (let i = 0; i < queue; i++) {
      const y: number = cy - road - 14 - i * 20 + move;
      if (y < 10) {
        continue;
      }
      this.drawVehicle(cx + 14, y, color);
    }
  }

  private drawSouth(scene: IntersectionScene, h: number, cy: number, cx: number, road: number): void {
    const queue: number = this.queueOf(scene, 'SOUTH');
    const move: number = this.moveOf(scene, 'SOUTH');
    const color: string = this.colorOf(scene, 'SOUTH');
    for (let i = 0; i < queue; i++) {
      const y: number = cy + road + 14 + i * 20 - move;
      if (y > h - 10) {
        continue;
      }
      this.drawVehicle(cx - 14, y, color);
    }
  }
}

import { ThemeConstants } from '../common/constants/ThemeConstants';
import { TrafficUtil } from '../common/utils/TrafficUtil';

/**
 * 拥堵指数环形仪表盘（Canvas 自绘）
 * 0~10，颜色按等级分级，数字带缓动
 */
@Component
export struct TrafficGauge {
  @Prop @Watch('onIndexChange') index: number = 0;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private ready: boolean = false;

  onIndexChange(): void {
    this.draw();
  }

  private draw(): void {
    if (!this.ready) {
      return;
    }
    const w: number = 220;
    const h: number = 160;
    const cx: number = w / 2;
    const cy: number = 118;
    const r: number = 86;
    const start: number = Math.PI * 0.85;
    const sweep: number = Math.PI * 1.3;

    this.ctx.clearRect(0, 0, w, h);
    this.ctx.lineCap = 'round';
    this.ctx.lineWidth = 14;

    // 底环
    this.ctx.strokeStyle = '#EDF0F5';
    this.ctx.beginPath();
    this.ctx.arc(cx, cy, r, start, start + sweep);
    this.ctx.stroke();

    // 进度环
    const level: number = TrafficUtil.levelOfIndex(this.index);
    this.ctx.strokeStyle = TrafficUtil.colorOfLevel(level);
    this.ctx.beginPath();
    this.ctx.arc(cx, cy, r, start, start + sweep * Math.max(0.02, this.index / 10));
    this.ctx.stroke();

    // 指针端点
    const angle: number = start + sweep * Math.max(0.02, this.index / 10);
    const px: number = cx + r * Math.cos(angle);
    const py: number = cy + r * Math.sin(angle);
    this.ctx.fillStyle = '#FFFFFF';
    this.ctx.beginPath();
    this.ctx.arc(px, py, 7, 0, Math.PI * 2);
    this.ctx.fill();
    this.ctx.strokeStyle = TrafficUtil.colorOfLevel(level);
    this.ctx.lineWidth = 3;
    this.ctx.stroke();

    // 中心数字
    this.ctx.fillStyle = ThemeConstants.TEXT_MAIN;
    this.ctx.font = 'bold 40vp sans-serif';
    this.ctx.textAlign = 'center';
    this.ctx.fillText(this.index.toFixed(1), cx, cy + 2);

    // 等级文案
    this.ctx.fillStyle = TrafficUtil.colorOfLevel(level);
    this.ctx.font = '14vp sans-serif';
    this.ctx.fillText(TrafficUtil.levelName(level), cx, cy + 26);

    // 刻度文案
    this.ctx.fillStyle = ThemeConstants.TEXT_SUB;
    this.ctx.font = '11vp sans-serif';
    this.ctx.fillText('0', cx - r - 4, cy + 26);
    this.ctx.fillText('10', cx + r + 4, cy + 26);
  }

  build() {
    Canvas(this.ctx)
      .width(220)
      .height(160)
      .onReady(() => {
        this.ready = true;
        this.draw();
      })
  }
}

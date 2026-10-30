import { ThemeConstants } from '../common/constants/ThemeConstants';
import { AppConstants } from '../common/constants/AppConstants';
import { NavRouter } from '../common/base/NavRouter';
import { TrafficUtil } from '../common/utils/TrafficUtil';
import { FavoriteUtil } from '../common/utils/FavoriteUtil';
import { ToastUtil } from '../common/utils/ToastUtil';
import { RepositoryFactory } from '../repository/RepositoryFactory';
import { Intersection } from '../model/Intersection';
import { ApproachFlow } from '../model/FlowRecord';
import { SignalPhase, SignalPlan } from '../model/SignalPlan';

/**
 * 路口实时状态：Canvas 车流 + 相位倒计时 + 用户化等待时间
 */
@ComponentV2
export struct IntersectionDetailPage {
  @Param intersectionId: string = '';

  @Local itName: string = '路口';
  @Local saturation: number = 0;
  @Local phases: SignalPhase[] = [];
  @Local phaseIndex: number = 0;
  @Local remain: number = 0;
  @Local waitSeconds: number = 0;
  @Local planName: string = '';
  @Local cycleLength: number = 0;
  @Local flows: ApproachFlow[] = [];
  @Local canvasW: number = 0;
  @Local canvasH: number = 0;
  @Local isFav: boolean = false;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private ready: boolean = false;
  private shift: number = 0;
  private tickId: number = -1;
  private frameId: number = -1;

  aboutToAppear(): void {
    this.loadData();
  }

  aboutToDisappear(): void {
    if (this.tickId !== -1) {
      clearInterval(this.tickId);
      this.tickId = -1;
    }
    if (this.frameId !== -1) {
      clearInterval(this.frameId);
      this.frameId = -1;
    }
  }

  async loadData(): Promise<void> {
    const repo = RepositoryFactory.getTrafficRepository();
    const it: Intersection | undefined = await repo.getIntersections()
      .then((list: Intersection[]) => list.find((x: Intersection) => x.id === this.intersectionId));
    const plan: SignalPlan = await repo.getSignalPlan(this.intersectionId);
    const flow = await repo.getFlow(this.intersectionId);

    if (it !== undefined) {
      this.itName = it.name;
    }
    this.planName = plan.planName;
    this.cycleLength = plan.cycleLength;
    this.phases = plan.phases;

    if (flow !== undefined) {
      this.flows = flow.flows;
      let maxSat: number = 0;
      for (let i = 0; i < flow.flows.length; i++) {
        maxSat = Math.max(maxSat, flow.flows[i].saturation);
      }
      this.saturation = maxSat;
    }

    this.isFav = await FavoriteUtil.contains(this.intersectionId);

    // 进入页面时让首个相位只剩 6 秒，便于快速观察相位切换
    this.phaseIndex = 0;
    const first: SignalPhase | undefined = this.phases.length > 0 ? this.phases[0] : undefined;
    this.remain = first !== undefined ? Math.min(first.green, 6) : 0;
    this.updateWait();
    this.startTimers();
  }

  private startTimers(): void {
    if (this.tickId !== -1) {
      return;
    }
    this.tickId = setInterval(() => {
      this.onTick();
    }, 1000);
    this.frameId = setInterval(() => {
      this.shift = this.shift + 0.08;
      if (this.shift > 1) {
        this.shift = 0;
      }
      this.draw();
    }, AppConstants.ANIMATION_FRAME_MS);
  }

  private onTick(): void {
    if (this.phases.length === 0) {
      return;
    }
    if (this.remain > 0) {
      this.remain = this.remain - 1;
    } else {
      this.phaseIndex = (this.phaseIndex + 1) % this.phases.length;
      this.remain = this.phases[this.phaseIndex].green;
    }
    this.updateWait();
  }

  private currentPhase(): SignalPhase | undefined {
    if (this.phases.length === 0) {
      return undefined;
    }
    return this.phases[this.phaseIndex];
  }

  /** 计算关注方向（饱和度最高进口道）的预计等待时间 */
  private updateWait(): void {
    if (this.phases.length === 0) {
      this.waitSeconds = 0;
      return;
    }
    const focusDir: string = this.focusDir();
    let wait: number = this.remain;
    let idx: number = this.phaseIndex;
    for (let step = 0; step < this.phases.length; step++) {
      const p: SignalPhase = this.phases[idx];
      if (p.movements.indexOf(focusDir) >= 0) {
        break;
      }
      wait += p.green + p.yellow + p.allRed;
      idx = (idx + 1) % this.phases.length;
    }
    this.waitSeconds = Math.round(wait);
  }

  /** 饱和度最高的进口道方向 */
  private focusDir(): string {
    let dir: string = 'EAST';
    let maxSat: number = -1;
    for (let i = 0; i < this.flows.length; i++) {
      if (this.flows[i].saturation > maxSat) {
        maxSat = this.flows[i].saturation;
        dir = this.flows[i].dir.toString();
      }
    }
    return dir;
  }

  private dirSaturation(dir: string): number {
    for (let i = 0; i < this.flows.length; i++) {
      if (this.flows[i].dir.toString() === dir) {
        return this.flows[i].saturation;
      }
    }
    return 0;
  }

  private queueOf(dir: string): number {
    for (let i = 0; i < this.flows.length; i++) {
      if (this.flows[i].dir.toString() === dir) {
        return this.flows[i].queueLength;
      }
    }
    return 0;
  }

  private isGreen(dir: string): boolean {
    const p: SignalPhase | undefined = this.currentPhase();
    if (p === undefined) {
      return false;
    }
    return p.movements.indexOf(dir) >= 0;
  }

  private dirName(dir: string): string {
    if (dir === 'EAST') {
      return '东进口';
    }
    if (dir === 'WEST') {
      return '西进口';
    }
    if (dir === 'SOUTH') {
      return '南进口';
    }
    return '北进口';
  }

  // ---------------- Canvas 绘制 ----------------

  private draw(): void {
    if (!this.ready || this.canvasW <= 0) {
      return;
    }
    const w: number = this.canvasW;
    const h: number = this.canvasH;
    const cx: number = w / 2;
    const cy: number = h / 2;
    const road: number = 34;

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
    this.drawEast(w, cx, cy, road);
    this.drawWest(cx, cy, road);
    this.drawNorth(cy, cx, road);
    this.drawSouth(h, cy, cx, road);

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

  private drawVehicle(x: number, y: number, color: string): void {
    this.ctx.fillStyle = color;
    this.ctx.fillRect(x - 6, y - 9, 12, 18);
  }

  private drawEast(w: number, cx: number, cy: number, road: number): void {
    const green: boolean = this.isGreen('EAST');
    const queue: number = Math.min(6, this.queueOf('EAST'));
    const color: string = green ? '#2E7D32' : '#4A5568';
    for (let i = 0; i < queue; i++) {
      const move: number = green ? this.shift * 18 : 0;
      const x: number = cx + road + 14 + i * 20 - move;
      if (x > w - 10) {
        continue;
      }
      this.drawVehicle(x, cy + 14, color);
    }
  }

  private drawWest(cx: number, cy: number, road: number): void {
    const green: boolean = this.isGreen('WEST');
    const queue: number = Math.min(6, this.queueOf('WEST'));
    const color: string = green ? '#2E7D32' : '#4A5568';
    for (let i = 0; i < queue; i++) {
      const move: number = green ? this.shift * 18 : 0;
      const x: number = cx - road - 14 - i * 20 + move;
      if (x < 10) {
        continue;
      }
      this.drawVehicle(x, cy - 14, color);
    }
  }

  private drawNorth(cy: number, cx: number, road: number): void {
    const green: boolean = this.isGreen('NORTH');
    const queue: number = Math.min(6, this.queueOf('NORTH'));
    const color: string = green ? '#2E7D32' : '#4A5568';
    for (let i = 0; i < queue; i++) {
      const move: number = green ? this.shift * 18 : 0;
      const y: number = cy - road - 14 - i * 20 + move;
      if (y < 10) {
        continue;
      }
      this.drawVehicle(cx + 14, y, color);
    }
  }

  private drawSouth(h: number, cy: number, cx: number, road: number): void {
    const green: boolean = this.isGreen('SOUTH');
    const queue: number = Math.min(6, this.queueOf('SOUTH'));
    const color: string = green ? '#2E7D32' : '#4A5568';
    for (let i = 0; i < queue; i++) {
      const move: number = green ? this.shift * 18 : 0;
      const y: number = cy + road + 14 + i * 20 - move;
      if (y > h - 10) {
        continue;
      }
      this.drawVehicle(cx - 14, y, color);
    }
  }

  // ---------------- UI ----------------

  build() {
    NavDestination() {
      Column() {
        // 顶部
        Row() {
          Text('<')
            .fontSize(22)
            .fontColor(ThemeConstants.TEXT_MAIN)
            .width(32)
            .onClick(() => {
              NavRouter.back();
            })
          Column() {
            Text(this.itName)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(ThemeConstants.TEXT_MAIN)
            Text('周期 ' + this.cycleLength + 's · ' + this.planName)
              .fontSize(ThemeConstants.FONT_CAPTION)
              .fontColor(ThemeConstants.TEXT_SUB)
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text('饱和度 ' + this.saturation.toFixed(2))
            .fontSize(12)
            .fontColor(TrafficUtil.colorOfSaturation(this.saturation))
        }
        .width('100%')
        .padding({ left: 12, right: 16, top: 8, bottom: 8 })

        // 路口动画
        Canvas(this.ctx)
          .width('100%')
          .height(320)
          .onReady(() => {
            this.ready = true;
            this.draw();
          })
          .onAreaChange((oldArea: Area, newArea: Area) => {
            this.canvasW = newArea.width as number;
            this.canvasH = newArea.height as number;
            this.draw();
          })

        // 相位与倒计时
        Column() {
          Row() {
            Text('当前放行')
              .fontSize(ThemeConstants.FONT_BODY)
              .fontColor(ThemeConstants.TEXT_SUB)
            Text(this.phaseNameText())
              .fontSize(ThemeConstants.FONT_SUBTITLE)
              .fontWeight(FontWeight.Bold)
              .fontColor(ThemeConstants.PRIMARY)
              .margin({ left: 8 })
            Blank()
            Text(this.remain + ' s')
              .fontSize(ThemeConstants.FONT_SUBTITLE)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.remain <= 3 ? ThemeConstants.LEVEL_MODERATE : ThemeConstants.TEXT_MAIN)
          }
          .width('100%')

          // 倒计时进度条
          Stack({ alignContent: Alignment.Start }) {
            Row()
              .width('100%')
              .height(8)
              .backgroundColor('#EDF0F5')
              .borderRadius(4)
            Row()
              .width(this.progressPercent())
              .height(8)
              .backgroundColor(this.remain <= 3 ? ThemeConstants.LEVEL_MODERATE : ThemeConstants.PRIMARY)
              .borderRadius(4)
          }
          .width('100%')
          .margin({ top: 10 })

          Divider()
            .color(ThemeConstants.DIVIDER)
            .margin({ top: 14, bottom: 14 })

          Row() {
            Text(this.dirName(this.focusDir()))
              .fontSize(ThemeConstants.FONT_BODY)
              .fontColor(ThemeConstants.TEXT_SUB)
            Blank()
            Text('预计等待')
              .fontSize(ThemeConstants.FONT_BODY)
              .fontColor(ThemeConstants.TEXT_SUB)
          }
          .width('100%')

          Row() {
            Text(this.waitSeconds + '')
              .fontSize(34)
              .fontWeight(FontWeight.Bold)
              .fontColor(ThemeConstants.PRIMARY)
            Text('秒')
              .fontSize(14)
              .fontColor(ThemeConstants.TEXT_SUB)
              .margin({ left: 4, bottom: 6 })
            Blank()
            Column() {
              Text('排队 ' + this.queueOf(this.focusDir()) + ' 辆')
                .fontSize(12)
                .fontColor(ThemeConstants.TEXT_SUB)
              Text('饱和度 ' + this.dirSaturation(this.focusDir()).toFixed(2))
                .fontSize(12)
                .fontColor(TrafficUtil.colorOfSaturation(this.dirSaturation(this.focusDir())))
                .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.End)
          }
          .width('100%')
          .alignItems(VerticalAlign.Bottom)

          Divider()
            .color(ThemeConstants.DIVIDER)
            .margin({ top: 12, bottom: 10 })

          Text(this.diagnosisText())
            .fontSize(12)
            .fontColor(ThemeConstants.TEXT_SUB)
            .width('100%')
            .lineHeight(18)
        }
        .width('100%')
        .padding(16)
        .backgroundColor(ThemeConstants.BG_CARD)
        .borderRadius(ThemeConstants.RADIUS_CARD)
        .margin({ top: 8, left: 16, right: 16 })
        .layoutWeight(1)

        // 操作
        Row({ space: 12 }) {
          Button('查看配时方案')
            .layoutWeight(1)
            .height(44)
            .backgroundColor(ThemeConstants.PRIMARY)
            .fontColor(ThemeConstants.TEXT_INVERT)
            .fontSize(15)
            .onClick(() => {
              NavRouter.toSignalPlan(this.intersectionId, '早高峰');
            })
          Button(this.isFav ? '已收藏' : '收藏')
            .width(88)
            .height(44)
            .backgroundColor(ThemeConstants.PRIMARY_LIGHT)
            .fontColor(ThemeConstants.PRIMARY)
            .fontSize(15)
            .onClick(() => {
              FavoriteUtil.toggle(this.intersectionId).then((added: boolean) => {
                this.isFav = added;
                ToastUtil.show(added ? '已收藏该路口' : '已取消收藏');
              })
            })
        }
        .width('100%')
        .padding(16)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(ThemeConstants.BG_PAGE)
    }
    .hideTitleBar(true)
    .backgroundColor(ThemeConstants.BG_PAGE)
  }

  private progressPercent(): string {
    const p: SignalPhase | undefined = this.currentPhase();
    if (p === undefined || p.green <= 0) {
      return '0%';
    }
    const ratio: number = Math.max(0, Math.min(1, this.remain / p.green));
    return (ratio * 100).toFixed(0) + '%';
  }

  private phaseNameText(): string {
    const p: SignalPhase | undefined = this.currentPhase();
    return p === undefined ? '--' : p.name;
  }

  /** 把饱和度与排队翻译成一句可读的结论 */
  private diagnosisText(): string {
    const sat: number = this.dirSaturation(this.focusDir());
    const queue: number = this.queueOf(this.focusDir());
    if (sat >= 0.9) {
      return '诊断：该进口道饱和度 ' + sat.toFixed(2) + '，已超过通行能力，排队 ' + queue +
        ' 辆，通常需要 2 个以上周期才能通过，建议错峰或绕行。';
    }
    if (sat >= 0.75) {
      return '诊断：该进口道接近饱和（' + sat.toFixed(2) + '），当前配时下等待约 1~2 个周期。';
    }
    return '诊断：该进口道通行状况良好（饱和度 ' + sat.toFixed(2) + '），一般 1 个周期内可通过。';
  }
}

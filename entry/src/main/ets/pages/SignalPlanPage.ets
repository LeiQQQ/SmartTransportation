import { ThemeConstants } from '../common/constants/ThemeConstants';
import { NavRouter } from '../common/base/NavRouter';
import { TrafficUtil } from '../common/utils/TrafficUtil';
import { RepositoryFactory } from '../repository/RepositoryFactory';
import { Intersection } from '../model/Intersection';
import { SignalPhase, SignalPlan } from '../model/SignalPlan';
import { Evaluation } from '../model/Evaluation';

interface EvalRow {
  label: string;
  beforeText: string;
  afterText: string;
  diffText: string;
  beforeRatio: number;
  afterRatio: number;
  better: boolean;
}

/**
 * 信号配时看板：相位甘特图 + 优化前后对比
 */
@ComponentV2
export struct SignalPlanPage {
  @Param intersectionId: string = '';
  @Param scenario: string = '早高峰';

  @Local itName: string = '路口';
  @Local phases: SignalPhase[] = [];
  @Local cycle: number = 0;
  @Local beforeCycle: number = 0;
  @Local lostTime: number = 0;
  @Local planName: string = '';
  @Local optimized: boolean = false;
  @Local rows: EvalRow[] = [];
  @Local scenarioIndex: number = 0;

  private scenarios: string[] = ['早高峰', '平峰', '晚高峰'];

  aboutToAppear(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    const repo = RepositoryFactory.getTrafficRepository();
    const list: Intersection[] = await repo.getIntersections();
    for (let i = 0; i < list.length; i++) {
      if (list[i].id === this.intersectionId) {
        this.itName = list[i].name;
      }
    }
    const plan: SignalPlan = await repo.getSignalPlan(this.intersectionId);
    this.phases = plan.phases;
    this.cycle = plan.cycleLength;
    this.beforeCycle = plan.beforeCycleLength;
    this.lostTime = plan.lostTime;
    this.planName = plan.planName;
    this.optimized = plan.optimized;

    const ev: Evaluation = await repo.getEvaluation(this.intersectionId, this.scenarios[this.scenarioIndex]);
    this.rows = this.buildRows(ev);
  }

  private buildRows(ev: Evaluation): EvalRow[] {
    const list: EvalRow[] = [];
    const maxDelay: number = Math.max(ev.before.avgDelay, ev.after.avgDelay);
    const maxQueue: number = Math.max(ev.before.avgQueue, ev.after.avgQueue);
    const maxThroughput: number = Math.max(ev.before.throughput, ev.after.throughput);
    const maxStops: number = Math.max(ev.before.stops, ev.after.stops);

    list.push({
      label: '平均延误',
      beforeText: ev.before.avgDelay.toFixed(1) + ' s',
      afterText: ev.after.avgDelay.toFixed(1) + ' s',
      diffText: SignalPlanPage.sign(ev.improvement.avgDelay) + ev.improvement.avgDelay.toFixed(1) + '%',
      beforeRatio: ev.before.avgDelay / maxDelay,
      afterRatio: ev.after.avgDelay / maxDelay,
      better: ev.improvement.avgDelay < 0
    });
    list.push({
      label: '平均排队',
      beforeText: ev.before.avgQueue.toFixed(1) + ' 辆',
      afterText: ev.after.avgQueue.toFixed(1) + ' 辆',
      diffText: SignalPlanPage.sign(ev.improvement.avgQueue) + ev.improvement.avgQueue.toFixed(1) + '%',
      beforeRatio: ev.before.avgQueue / maxQueue,
      afterRatio: ev.after.avgQueue / maxQueue,
      better: ev.improvement.avgQueue < 0
    });
    list.push({
      label: '通行量',
      beforeText: ev.before.throughput + ' 辆/h',
      afterText: ev.after.throughput + ' 辆/h',
      diffText: SignalPlanPage.sign(ev.improvement.throughput) + ev.improvement.throughput.toFixed(1) + '%',
      beforeRatio: ev.before.throughput / maxThroughput,
      afterRatio: ev.after.throughput / maxThroughput,
      better: ev.improvement.throughput > 0
    });
    list.push({
      label: '平均停车',
      beforeText: ev.before.stops.toFixed(2) + ' 次',
      afterText: ev.after.stops.toFixed(2) + ' 次',
      diffText: SignalPlanPage.sign(ev.improvement.stops) + ev.improvement.stops.toFixed(1) + '%',
      beforeRatio: ev.before.stops / maxStops,
      afterRatio: ev.after.stops / maxStops,
      better: ev.improvement.stops < 0
    });
    return list;
  }

  private static sign(v: number): string {
    return v > 0 ? '+' : '';
  }

  private phaseWidth(green: number): string {
    if (this.cycle <= 0) {
      return '0%';
    }
    return ((green / this.cycle) * 100).toFixed(1) + '%';
  }

  build() {
    NavDestination() {
      Column() {
        Row() {
          Text('<')
            .fontSize(22)
            .fontColor(ThemeConstants.TEXT_MAIN)
            .width(32)
            .onClick(() => {
              NavRouter.back();
            })
          Column() {
            Text(this.itName + ' · 配时方案')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(ThemeConstants.TEXT_MAIN)
            Text(this.planName + ' · ' + (this.optimized ? '已优化' : '固定配时'))
              .fontSize(ThemeConstants.FONT_CAPTION)
              .fontColor(ThemeConstants.TEXT_SUB)
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 12, right: 16, top: 8, bottom: 8 })

        Scroll() {
          Column({ space: 12 }) {
            // 周期概览
            Row() {
              this.summaryItem('优化前周期', this.beforeCycle + ' s')
              Divider().vertical(true).height(28).color(ThemeConstants.DIVIDER)
              this.summaryItem('优化后周期', this.cycle + ' s')
              Divider().vertical(true).height(28).color(ThemeConstants.DIVIDER)
              this.summaryItem('总损失', this.lostTime + ' s')
            }
            .width('100%')
            .padding(16)
            .backgroundColor(ThemeConstants.BG_CARD)
            .borderRadius(ThemeConstants.RADIUS_CARD)
            .justifyContent(FlexAlign.SpaceAround)

            // 相位甘特图
            Column() {
              Row() {
                Text('相位分配')
                  .fontSize(ThemeConstants.FONT_SUBTITLE)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(ThemeConstants.TEXT_MAIN)
                Blank()
                Text('一个周期 ' + this.cycle + ' s')
                  .fontSize(ThemeConstants.FONT_CAPTION)
                  .fontColor(ThemeConstants.TEXT_SUB)
              }
              .width('100%')
              .margin({ bottom: 14 })

              ForEach(this.phases, (p: SignalPhase, index: number) => {
                Column() {
                  Row() {
                    Text(p.name)
                      .fontSize(13)
                      .fontColor(ThemeConstants.TEXT_MAIN)
                    Blank()
                    Text(p.green + 's')
                      .fontSize(13)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(ThemeConstants.PHASE_COLORS[index % 4])
                    Text('  λ=' + TrafficUtil.greenRatioOf(p.green, this.cycle))
                      .fontSize(11)
                      .fontColor(ThemeConstants.TEXT_SUB)
                  }
                  .width('100%')

                  Row() {
                    Row()
                      .width(this.phaseWidth(p.green))
                      .height(12)
                      .backgroundColor(ThemeConstants.PHASE_COLORS[index % 4])
                      .borderRadius(3)
                    Row()
                      .width(this.phaseWidth(p.yellow + p.allRed))
                      .height(12)
                      .backgroundColor('#D5DBE5')
                      .borderRadius(3)
                      .margin({ left: 2 })
                  }
                  .width('100%')
                  .margin({ top: 6 })
                }
                .width('100%')
                .margin({ bottom: 12 })
              }, (p: SignalPhase) => '' + p.phaseId)

              Row() {
                Text('黄灯 + 全红')
                  .fontSize(10)
                  .fontColor(ThemeConstants.TEXT_SUB)
                Blank()
                Text('灰条表示相位切换损失')
                  .fontSize(10)
                  .fontColor(ThemeConstants.TEXT_SUB)
              }
              .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor(ThemeConstants.BG_CARD)
            .borderRadius(ThemeConstants.RADIUS_CARD)

            // 优化前后对比
            Column() {
              Row() {
                Text('优化效果对比')
                  .fontSize(ThemeConstants.FONT_SUBTITLE)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(ThemeConstants.TEXT_MAIN)
                Blank()
                Text(this.scenarios[this.scenarioIndex])
                  .fontSize(ThemeConstants.FONT_CAPTION)
                  .fontColor(ThemeConstants.PRIMARY)
              }
              .width('100%')
              .margin({ bottom: 14 })

              ForEach(this.rows, (row: EvalRow) => {
                Column() {
                  Row() {
                    Text(row.label)
                      .fontSize(13)
                      .fontColor(ThemeConstants.TEXT_MAIN)
                    Blank()
                    Text(row.diffText)
                      .fontSize(13)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(row.better ? ThemeConstants.LEVEL_CLEAR : ThemeConstants.LEVEL_SEVERE)
                  }
                  .width('100%')

                  Row() {
                    Text('前')
                      .fontSize(10)
                      .fontColor(ThemeConstants.TEXT_SUB)
                      .width(16)
                    Row()
                      .width((row.beforeRatio * 100).toFixed(0) + '%')
                      .height(10)
                      .backgroundColor('#C9D2E0')
                      .borderRadius(3)
                    Blank()
                    Text(row.beforeText)
                      .fontSize(11)
                      .fontColor(ThemeConstants.TEXT_SUB)
                  }
                  .width('100%')
                  .margin({ top: 6 })

                  Row() {
                    Text('后')
                      .fontSize(10)
                      .fontColor(ThemeConstants.TEXT_SUB)
                      .width(16)
                    Row()
                      .width((row.afterRatio * 100).toFixed(0) + '%')
                      .height(10)
                      .backgroundColor(ThemeConstants.PRIMARY)
                      .borderRadius(3)
                    Blank()
                    Text(row.afterText)
                      .fontSize(11)
                      .fontColor(ThemeConstants.TEXT_MAIN)
                  }
                  .width('100%')
                  .margin({ top: 4 })
                }
                .width('100%')
                .margin({ bottom: 16 })
              }, (row: EvalRow) => row.label)
            }
            .width('100%')
            .padding(16)
            .backgroundColor(ThemeConstants.BG_CARD)
            .borderRadius(ThemeConstants.RADIUS_CARD)

            // 时段切换
            Row({ space: 10 }) {
              ForEach(this.scenarios, (name: string, index: number) => {
                Text(name)
                  .fontSize(13)
                  .fontColor(this.scenarioIndex === index ? ThemeConstants.TEXT_INVERT : ThemeConstants.TEXT_SUB)
                  .backgroundColor(this.scenarioIndex === index ? ThemeConstants.PRIMARY : ThemeConstants.BG_CARD)
                  .padding({ left: 18, right: 18, top: 8, bottom: 8 })
                  .borderRadius(16)
                  .onClick(() => {
                    this.scenarioIndex = index;
                    this.loadData();
                  })
              }, (name: string) => name)
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .margin({ bottom: 20 })
          }
          .padding({ left: 16, right: 16 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(ThemeConstants.BG_PAGE)
    }
    .hideTitleBar(true)
    .backgroundColor(ThemeConstants.BG_PAGE)
  }

  @Builder
  summaryItem(label: string, value: string) {
    Column() {
      Text(value)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeConstants.PRIMARY)
      Text(label)
        .fontSize(11)
        .fontColor(ThemeConstants.TEXT_SUB)
        .margin({ top: 4 })
    }
  }
}

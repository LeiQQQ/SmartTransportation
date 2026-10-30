import { ThemeConstants } from '../common/constants/ThemeConstants';
import { AreaConstants } from '../common/constants/AreaConstants';
import { NavRouter } from '../common/base/NavRouter';

interface Section {
  title: string;
  lines: string[];
}

/**
 * 数据说明：主动交代数据来源与指标口径，避免答辩质疑
 */
@ComponentV2
export struct AboutPage {
  private sections: Section[] = [
    {
      title: '研究范围',
      lines: [
        '西安市城墙内片区，经度 ' + AreaConstants.MIN_LON + '~' + AreaConstants.MAX_LON + '，纬度 ' +
        AreaConstants.MIN_LAT + '~' + AreaConstants.MAX_LAT + '。',
        '覆盖 15 个信号路口、18 条主干路段，面积约 11.3 平方公里。'
      ]
    },
    {
      title: '数据来源',
      lines: [
        '路网拓扑：依据公开地图资料手工建模，坐标经简化为示意拓扑。',
        '交通流量：由高斯双峰模型（早 8 点、晚 18 点）叠加随机扰动仿真生成。',
        '配时方案：由 Webster 最优周期模型实时计算，非真实信号机数据。'
      ]
    },
    {
      title: '指标口径',
      lines: [
        '饱和度 v/c：进口道实际流量与通行能力之比，>0.9 判定为严重拥堵。',
        '通行能力：饱和流率 × 车道数 × 绿信比。',
        '周期 C：一个完整信号循环的总时长（秒）。',
        '绿信比 λ：某相位绿灯时长与周期之比。',
        '延误 d：车辆通过路口的平均等待时间（秒/辆），采用 Webster 延误公式。'
      ]
    },
    {
      title: '算法说明',
      lines: [
        '最优周期 C₀ = (1.5L + 5) / (1 - Y)，其中 L 为总损失时间，Y 为各相位流量比之和。',
        '相位绿灯 gᵢ = (C₀ - L) × (yᵢ / Y)，并对最小绿灯 8 秒做约束。',
        '延误由均匀延误项与随机到达附加项组成。'
      ]
    },
    {
      title: '免责声明',
      lines: [
        '本应用为本科毕业设计作品，所有数据均为仿真结果，不用于真实出行决策。',
        '系统未接入任何交通管理部门信号控制系统。'
      ]
    }
  ];

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
          Text('数据说明')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeConstants.TEXT_MAIN)
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 12, right: 16, top: 8, bottom: 8 })

        Scroll() {
          Column({ space: 12 }) {
            ForEach(this.sections, (sec: Section) => {
              Column() {
                Text(sec.title)
                  .fontSize(ThemeConstants.FONT_SUBTITLE)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(ThemeConstants.TEXT_MAIN)
                  .width('100%')

                ForEach(sec.lines, (line: string, index: number) => {
                  Row() {
                    Circle()
                      .width(5)
                      .height(5)
                      .fill(ThemeConstants.PRIMARY)
                      .margin({ top: 7 })
                    Text(line)
                      .fontSize(13)
                      .fontColor(ThemeConstants.TEXT_SUB)
                      .layoutWeight(1)
                      .margin({ left: 8 })
                      .lineHeight(20)
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Top)
                  .margin({ top: index === 0 ? 12 : 8 })
                }, (line: string) => line)
              }
              .width('100%')
              .padding(16)
              .backgroundColor(ThemeConstants.BG_CARD)
              .borderRadius(ThemeConstants.RADIUS_CARD)
            }, (sec: Section) => sec.title)

            Text('版本 1.0.0 · 本科毕业设计')
              .fontSize(11)
              .fontColor(ThemeConstants.TEXT_SUB)
              .margin({ top: 8, bottom: 24 })
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
}

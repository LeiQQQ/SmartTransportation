import { ThemeConstants } from '../common/constants/ThemeConstants';
import { NavRouter } from '../common/base/NavRouter';
import { ToastUtil } from '../common/utils/ToastUtil';
import { RepositoryFactory } from '../repository/RepositoryFactory';
import { EventTypeUtil } from '../model/TrafficEvent';
import { Intersection } from '../model/Intersection';

/**
 * 事件上报：类型 + 位置 + 影响等级 + 描述
 */
@ComponentV2
export struct EventReportPage {
  @Local typeIndex: number = 3;
  @Local impact: number = 2;
  @Local desc: string = '';
  @Local roadNames: string[] = [];
  @Local roadOptions: SelectOption[] = [];
  @Local roadIndex: number = 0;
  @Local submitting: boolean = false;

  private types: number[] = [0, 1, 2, 3];
  private impacts: string[] = ['轻微', '一般', '严重'];

  aboutToAppear(): void {
    this.loadRoads();
  }

  async loadRoads(): Promise<void> {
    const repo = RepositoryFactory.getTrafficRepository();
    const list: Intersection[] = await repo.getIntersections();
    const names: string[] = [];
    for (let i = 0; i < list.length; i++) {
      names.push(list[i].name);
    }
    this.roadNames = names;
    const options: SelectOption[] = [];
    for (let i = 0; i < names.length; i++) {
      options.push({ value: names[i] } as SelectOption);
    }
    this.roadOptions = options;
  }

  private submit(): void {
    if (this.desc.length === 0) {
      ToastUtil.show('请填写事件描述');
      return;
    }
    this.submitting = true;
    setTimeout(() => {
      this.submitting = false;
      ToastUtil.show('已提交，审核通过后同步至片区其他用户');
      NavRouter.back();
    }, 600);
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
          Text('上报交通事件')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeConstants.TEXT_MAIN)
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 12, right: 16, top: 8, bottom: 8 })

        Scroll() {
          Column({ space: 12 }) {
            // 事件类型
            Column() {
              Text('事件类型')
                .fontSize(ThemeConstants.FONT_SUBTITLE)
                .fontWeight(FontWeight.Medium)
                .fontColor(ThemeConstants.TEXT_MAIN)
                .width('100%')

              Row({ space: 8 }) {
                ForEach(this.types, (type: number) => {
                  Text(EventTypeUtil.nameOf(type))
                    .fontSize(13)
                    .fontColor(this.typeIndex === type ? ThemeConstants.TEXT_INVERT : ThemeConstants.TEXT_SUB)
                    .backgroundColor(this.typeIndex === type ? EventTypeUtil.colorOf(type) : '#F2F4F8')
                    .padding({ left: 16, right: 16, top: 7, bottom: 7 })
                    .borderRadius(15)
                    .onClick(() => {
                      this.typeIndex = type;
                    })
                }, (type: number) => '' + type)
              }
              .width('100%')
              .margin({ top: 12 })
            }
            .width('100%')
            .padding(16)
            .backgroundColor(ThemeConstants.BG_CARD)
            .borderRadius(ThemeConstants.RADIUS_CARD)

            // 位置
            Column() {
              Text('发生位置')
                .fontSize(ThemeConstants.FONT_SUBTITLE)
                .fontWeight(FontWeight.Medium)
                .fontColor(ThemeConstants.TEXT_MAIN)
                .width('100%')

              if (this.roadOptions.length > 0) {
                Select(this.roadOptions)
                  .selected(this.roadIndex)
                  .value(this.roadNames[this.roadIndex])
                  .font({ size: 14 })
                  .width('100%')
                  .margin({ top: 10 })
                  .onSelect((index: number) => {
                    this.roadIndex = index;
                  })
              }

            }
            .width('100%')
            .padding(16)
            .backgroundColor(ThemeConstants.BG_CARD)
            .borderRadius(ThemeConstants.RADIUS_CARD)

            // 影响等级
            Column() {
              Text('影响程度')
                .fontSize(ThemeConstants.FONT_SUBTITLE)
                .fontWeight(FontWeight.Medium)
                .fontColor(ThemeConstants.TEXT_MAIN)
                .width('100%')

              Row({ space: 8 }) {
                ForEach(this.impacts, (name: string, index: number) => {
                  Text(name)
                    .fontSize(13)
                    .fontColor(this.impact === index + 1 ? ThemeConstants.TEXT_INVERT : ThemeConstants.TEXT_SUB)
                    .backgroundColor(this.impact === index + 1 ? ThemeConstants.PRIMARY : '#F2F4F8')
                    .padding({ left: 18, right: 18, top: 7, bottom: 7 })
                    .borderRadius(15)
                    .onClick(() => {
                      this.impact = index + 1;
                    })
                }, (name: string) => name)
              }
              .width('100%')
              .margin({ top: 12 })
            }
            .width('100%')
            .padding(16)
            .backgroundColor(ThemeConstants.BG_CARD)
            .borderRadius(ThemeConstants.RADIUS_CARD)

            // 描述
            Column() {
              Text('情况描述')
                .fontSize(ThemeConstants.FONT_SUBTITLE)
                .fontWeight(FontWeight.Medium)
                .fontColor(ThemeConstants.TEXT_MAIN)
                .width('100%')

              TextArea({ placeholder: '例如：洒金桥南向北车流集中，排队约 300 米' })
                .width('100%')
                .height(110)
                .fontSize(13)
                .backgroundColor('#F7F9FC')
                .borderRadius(ThemeConstants.RADIUS_SMALL)
                .margin({ top: 10 })
                .onChange((value: string) => {
                  this.desc = value;
                })

              Text(this.desc.length + '/200')
                .fontSize(10)
                .fontColor(ThemeConstants.TEXT_SUB)
                .width('100%')
                .textAlign(TextAlign.End)
                .margin({ top: 6 })
            }
            .width('100%')
            .padding(16)
            .backgroundColor(ThemeConstants.BG_CARD)
            .borderRadius(ThemeConstants.RADIUS_CARD)
          }
          .padding({ left: 16, right: 16 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)

        Button(this.submitting ? '提交中…' : '提交上报')
          .width('100%')
          .height(46)
          .backgroundColor(this.submitting ? '#9BB8EA' : ThemeConstants.PRIMARY)
          .fontColor(ThemeConstants.TEXT_INVERT)
          .fontSize(15)
          .margin({ left: 16, right: 16, top: 12, bottom: 16 })
          .onClick(() => {
            if (!this.submitting) {
              this.submit();
            }
          })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(ThemeConstants.BG_PAGE)
    }
    .hideTitleBar(true)
    .backgroundColor(ThemeConstants.BG_PAGE)
  }

}

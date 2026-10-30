import { ThemeConstants } from '../common/constants/ThemeConstants';
import { NavRouter } from '../common/base/NavRouter';
import { RepositoryFactory } from '../repository/RepositoryFactory';
import { EventTypeUtil, TrafficEvent } from '../model/TrafficEvent';

/**
 * 事件中心：拥堵/事故/施工/管制事件列表
 */
@ComponentV2
export struct EventPage {
  @Local events: TrafficEvent[] = [];
  @Local filtered: TrafficEvent[] = [];
  @Local filterIndex: number = 0;

  private filters: number[] = [-1, 0, 3, 1, 2];

  aboutToAppear(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    const repo = RepositoryFactory.getTrafficRepository();
    this.events = await repo.getEvents();
    this.applyFilter();
  }

  private applyFilter(): void {
    if (this.filterIndex === 0) {
      this.filtered = this.events;
      return;
    }
    const type: number = this.filters[this.filterIndex];
    const list: TrafficEvent[] = [];
    for (let i = 0; i < this.events.length; i++) {
      if (this.events[i].type === type) {
        list.push(this.events[i]);
      }
    }
    this.filtered = list;
  }

  private filterName(index: number): string {
    if (index === 0) {
      return '全部';
    }
    return EventTypeUtil.nameOf(this.filters[index]);
  }

  private static relativeTime(ts: number): string {
    const diff: number = Math.floor((Date.now() - ts) / 60000);
    if (diff < 1) {
      return '刚刚';
    }
    if (diff < 60) {
      return diff + ' 分钟前';
    }
    return Math.floor(diff / 60) + ' 小时前';
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text('事件中心')
            .fontSize(ThemeConstants.FONT_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeConstants.TEXT_MAIN)
          Text('片区实时交通事件 · 共 ' + this.events.length + ' 条')
            .fontSize(ThemeConstants.FONT_CAPTION)
            .fontColor(ThemeConstants.TEXT_SUB)
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text('+ 上报')
          .fontSize(13)
          .fontColor(ThemeConstants.TEXT_INVERT)
          .backgroundColor(ThemeConstants.PRIMARY)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .borderRadius(14)
          .onClick(() => {
            NavRouter.toEventReport();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      // 筛选
      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.filters, (item: number, index: number) => {
            Text(this.filterName(index))
              .fontSize(13)
              .fontColor(this.filterIndex === index ? ThemeConstants.TEXT_INVERT : ThemeConstants.TEXT_SUB)
              .backgroundColor(this.filterIndex === index ? ThemeConstants.PRIMARY : ThemeConstants.BG_CARD)
              .padding({ left: 14, right: 14, top: 6, bottom: 6 })
              .borderRadius(14)
              .onClick(() => {
                this.filterIndex = index;
                this.applyFilter();
              })
          }, (item: number, index: number) => '' + index)
        }
        .padding({ left: 16, right: 16 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .margin({ bottom: 8 })

      List({ space: 10 }) {
        ForEach(this.filtered, (ev: TrafficEvent) => {
          ListItem() {
            Column() {
              Row() {
                Text(EventTypeUtil.nameOf(ev.type))
                  .fontSize(11)
                  .fontColor(ThemeConstants.TEXT_INVERT)
                  .backgroundColor(EventTypeUtil.colorOf(ev.type))
                  .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                  .borderRadius(4)
                Text(ev.title)
                  .fontSize(ThemeConstants.FONT_BODY)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(ThemeConstants.TEXT_MAIN)
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ left: 8 })
                Text(EventPage.relativeTime(ev.createTime))
                  .fontSize(11)
                  .fontColor(ThemeConstants.TEXT_SUB)
              }
              .width('100%')

              Text(ev.description)
                .fontSize(12)
                .fontColor(ThemeConstants.TEXT_SUB)
                .width('100%')
                .margin({ top: 8 })
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              Row() {
                Text('位置：' + ev.roadName)
                  .fontSize(11)
                  .fontColor(ThemeConstants.TEXT_SUB)
                Blank()
                Text(ev.impact >= 3 ? '影响严重' : (ev.impact === 2 ? '影响一般' : '影响轻微'))
                  .fontSize(11)
                  .fontColor(ev.impact >= 3 ? ThemeConstants.LEVEL_SEVERE : ThemeConstants.TEXT_SUB)
              }
              .width('100%')
              .margin({ top: 8 })
            }
            .width('100%')
            .padding(14)
            .backgroundColor(ThemeConstants.BG_CARD)
            .borderRadius(ThemeConstants.RADIUS_CARD)
          }
        }, (ev: TrafficEvent) => ev.id)

        ListItem() {
          Column() {
            Text('暂无可展示的事件')
              .fontSize(13)
              .fontColor(ThemeConstants.TEXT_SUB)
          }
          .width('100%')
          .padding(24)
          .visibility(this.filtered.length === 0 ? Visibility.Visible : Visibility.None)
        }
      }
      .layoutWeight(1)
      .padding({ left: 16, right: 16 })
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_PAGE)
  }
}

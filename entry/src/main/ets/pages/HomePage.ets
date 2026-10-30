import { ThemeConstants } from '../common/constants/ThemeConstants';
import { AreaConstants } from '../common/constants/AreaConstants';
import { AppConstants } from '../common/constants/AppConstants';
import { NavRouter } from '../common/base/NavRouter';
import { TrafficUtil } from '../common/utils/TrafficUtil';
import { TrafficGauge } from '../components/TrafficGauge';
import { RepositoryFactory } from '../repository/RepositoryFactory';
import { Intersection } from '../model/Intersection';
import { AreaTrafficIndex, FlowRecord } from '../model/FlowRecord';

interface TopItem {
  id: string;
  name: string;
  saturation: number;
  level: number;
}

@ComponentV2
export struct HomePage {
  @Local intersections: Intersection[] = [];
  @Local flows: FlowRecord[] = [];
  @Local areaIndex: number = 0;
  @Local avgSpeed: number = 0;
  @Local updateTime: string = '--:--:--';
  @Local topList: TopItem[] = [];
  @Local offline: boolean = false;
  @Local refreshing: boolean = false;
  @Local isRefreshing: boolean = false;

  private timerId: number = -1;

  aboutToAppear(): void {
    this.loadData();
    this.offline = RepositoryFactory.isOffline();
    this.timerId = setInterval(() => {
      this.loadData();
    }, AppConstants.REFRESH_INDEX_MS);
  }

  aboutToDisappear(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  async loadData(): Promise<void> {
    const repo = RepositoryFactory.getTrafficRepository();
    this.intersections = await repo.getIntersections();
    this.flows = await repo.getFlows();
    const idx: AreaTrafficIndex = await repo.getAreaIndex();
    this.areaIndex = idx.index;
    this.avgSpeed = idx.avgSpeed;
    this.updateTime = HomePage.formatTime(idx.updateTime);
    this.topList = this.buildTop();
  }

  private buildTop(): TopItem[] {
    const items: TopItem[] = [];
    for (let i = 0; i < this.flows.length; i++) {
      const fr: FlowRecord = this.flows[i];
      let maxSat: number = 0;
      for (let j = 0; j < fr.flows.length; j++) {
        maxSat = Math.max(maxSat, fr.flows[j].saturation);
      }
      let name: string = fr.intersectionId;
      for (let k = 0; k < this.intersections.length; k++) {
        if (this.intersections[k].id === fr.intersectionId) {
          name = this.intersections[k].name;
        }
      }
      items.push({
        id: fr.intersectionId,
        name: name,
        saturation: maxSat,
        level: TrafficUtil.levelOfSaturation(maxSat)
      });
    }
    items.sort((a: TopItem, b: TopItem) => b.saturation - a.saturation);
    return items.slice(0, 3);
  }

  private saturationOf(intersectionId: string): number {
    for (let i = 0; i < this.flows.length; i++) {
      if (this.flows[i].intersectionId === intersectionId) {
        let maxSat: number = 0;
        for (let j = 0; j < this.flows[i].flows.length; j++) {
          maxSat = Math.max(maxSat, this.flows[i].flows[j].saturation);
        }
        return maxSat;
      }
    }
    return 0;
  }

  private static formatTime(ts: number): string {
    const d: Date = new Date(ts);
    const h: string = d.getHours() < 10 ? '0' + d.getHours() : '' + d.getHours();
    const m: string = d.getMinutes() < 10 ? '0' + d.getMinutes() : '' + d.getMinutes();
    const s: string = d.getSeconds() < 10 ? '0' + d.getSeconds() : '' + d.getSeconds();
    return h + ':' + m + ':' + s;
  }

  @Builder
  cardTitle(title: string) {
    Text(title)
      .fontSize(ThemeConstants.FONT_SUBTITLE)
      .fontWeight(FontWeight.Medium)
      .fontColor(ThemeConstants.TEXT_MAIN)
  }

  build() {
    Column() {
      // 顶部标题
      Row() {
        Column() {
          Text(AreaConstants.AREA_NAME)
            .fontSize(ThemeConstants.FONT_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeConstants.TEXT_MAIN)
          Text(AreaConstants.AREA_DESC + ' · 更新于 ' + this.updateTime)
            .fontSize(ThemeConstants.FONT_CAPTION)
            .fontColor(ThemeConstants.TEXT_SUB)
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text('刷新')
          .fontSize(13)
          .fontColor(ThemeConstants.PRIMARY)
          .onClick(() => {
            this.refreshing = true;
            this.loadData().then(() => {
              this.refreshing = false;
            });
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      if (this.offline) {
        Row() {
          Text(AppConstants.TIP_OFFLINE)
            .fontSize(11)
            .fontColor('#8A6D00')
        }
        .width('100%')
        .padding({ left: 16, top: 4, bottom: 4 })
        .backgroundColor('#FFF7E0')
      }

      Refresh({ refreshing: $$this.isRefreshing }) {
        Scroll() {
          Column({ space: ThemeConstants.SPACE_CARD }) {
          // 拥堵指数卡
          Column() {
            Row() {
              this.cardTitle('片区拥堵指数')
              Blank()
              Text('均速 ' + this.avgSpeed + ' km/h')
                .fontSize(ThemeConstants.FONT_CAPTION)
                .fontColor(ThemeConstants.TEXT_SUB)
            }
            .width('100%')

            TrafficGauge({ index: this.areaIndex })
          }
          .width('100%')
          .padding(16)
          .backgroundColor(ThemeConstants.BG_CARD)
          .borderRadius(ThemeConstants.RADIUS_CARD)

          // 路网缩略
          Column() {
            Row() {
              this.cardTitle('路网态势')
              Blank()
              Text('点击查看详情 ›')
                .fontSize(ThemeConstants.FONT_CAPTION)
                .fontColor(ThemeConstants.TEXT_SUB)
            }
            .width('100%')
            .margin({ bottom: 12 })

            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
              ForEach(this.intersections, (item: Intersection) => {
                Column() {
                  Circle()
                    .width(14)
                    .height(14)
                    .fill(TrafficUtil.colorOfSaturation(this.saturationOf(item.id)))
                  Text(item.name)
                    .fontSize(10)
                    .fontColor(ThemeConstants.TEXT_SUB)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ top: 4 })
                }
                .width('20%')
                .padding({ top: 6, bottom: 6 })
                .onClick(() => {
                  NavRouter.toIntersection(item.id);
                })
              }, (item: Intersection) => item.id)
            }
            .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor(ThemeConstants.BG_CARD)
          .borderRadius(ThemeConstants.RADIUS_CARD)

          // 拥堵 TOP3
          Column() {
            this.cardTitle('拥堵路口 TOP3')
            Column() {
              ForEach(this.topList, (item: TopItem, index: number) => {
                Row() {
                  Text('' + (index + 1))
                    .fontSize(13)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(index === 0 ? ThemeConstants.LEVEL_SEVERE : ThemeConstants.TEXT_SUB)
                    .width(20)
                  Text(item.name)
                    .fontSize(ThemeConstants.FONT_BODY)
                    .fontColor(ThemeConstants.TEXT_MAIN)
                    .layoutWeight(1)
                  Text('饱和度 ' + item.saturation.toFixed(2))
                    .fontSize(ThemeConstants.FONT_CAPTION)
                    .fontColor(TrafficUtil.colorOfLevel(item.level))
                  Text(' ›')
                    .fontSize(14)
                    .fontColor(ThemeConstants.TEXT_SUB)
                }
                .width('100%')
                .padding({ top: 10, bottom: 10 })
                .onClick(() => {
                  NavRouter.toIntersection(item.id);
                })

                Divider()
                  .color(ThemeConstants.DIVIDER)
              }, (item: TopItem) => item.id)
            }
            .margin({ top: 4 })
          }
          .width('100%')
          .padding(16)
          .backgroundColor(ThemeConstants.BG_CARD)
          .borderRadius(ThemeConstants.RADIUS_CARD)

          // 成效提示
          Row() {
            Text('提示')
              .fontSize(11)
              .fontColor(ThemeConstants.TEXT_INVERT)
              .backgroundColor('#C79A00')
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .borderRadius(3)
            Text('流量自适应配时已生效：片区平均延误较固定配时下降 21.4%')
              .fontSize(ThemeConstants.FONT_CAPTION)
              .fontColor('#8A6D00')
              .layoutWeight(1)
              .margin({ left: 8 })
          }
          .width('100%')
          .padding(14)
          .backgroundColor('#FFF7E0')
          .borderRadius(ThemeConstants.RADIUS_SMALL)

          Row().height(12)
        }
          .padding({ left: 16, right: 16 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
      }
      .layoutWeight(1)
      .onRefreshing(() => {
        this.loadData().then(() => {
          this.isRefreshing = false;
        });
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_PAGE)
  }
}

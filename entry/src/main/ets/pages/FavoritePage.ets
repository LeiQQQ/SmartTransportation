import { ThemeConstants } from '../common/constants/ThemeConstants';
import { NavRouter } from '../common/base/NavRouter';
import { FavoriteUtil } from '../common/utils/FavoriteUtil';
import { EmptyView } from '../components/EmptyView';
import { RepositoryFactory } from '../repository/RepositoryFactory';
import { Intersection } from '../model/Intersection';
import { FlowRecord } from '../model/FlowRecord';
import { TrafficUtil } from '../common/utils/TrafficUtil';

/**
 * 收藏的路口
 */
@ComponentV2
export struct FavoritePage {
  @Local list: Intersection[] = [];
  @Local saturations: number[] = [];

  aboutToAppear(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    const ids: string[] = await FavoriteUtil.list();
    const repo = RepositoryFactory.getTrafficRepository();
    const all: Intersection[] = await repo.getIntersections();
    const flows: FlowRecord[] = await repo.getFlows();
    const result: Intersection[] = [];
    const sats: number[] = [];
    for (let i = 0; i < all.length; i++) {
      if (ids.indexOf(all[i].id) < 0) {
        continue;
      }
      result.push(all[i]);
      let maxSat: number = 0;
      for (let j = 0; j < flows.length; j++) {
        if (flows[j].intersectionId === all[i].id) {
          for (let k = 0; k < flows[j].flows.length; k++) {
            maxSat = Math.max(maxSat, flows[j].flows[k].saturation);
          }
        }
      }
      sats.push(maxSat);
    }
    this.list = result;
    this.saturations = sats;
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
          Text('我收藏的路口')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeConstants.TEXT_MAIN)
            .layoutWeight(1)
          Text(this.list.length + ' 个')
            .fontSize(12)
            .fontColor(ThemeConstants.TEXT_SUB)
        }
        .width('100%')
        .padding({ left: 12, right: 16, top: 8, bottom: 8 })

        if (this.list.length === 0) {
          EmptyView({ tip: '还没有收藏的路口，进入路口详情可收藏' })
        } else {
          List({ space: 10 }) {
            ForEach(this.list, (it: Intersection, index: number) => {
              ListItem() {
                Row() {
                  Column() {
                    Text(it.name)
                      .fontSize(ThemeConstants.FONT_BODY)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(ThemeConstants.TEXT_MAIN)
                    Text('饱和度 ' + this.saturations[index].toFixed(2) + ' · ' +
                      TrafficUtil.levelName(TrafficUtil.levelOfSaturation(this.saturations[index])))
                      .fontSize(11)
                      .fontColor(TrafficUtil.colorOfSaturation(this.saturations[index]))
                      .margin({ top: 4 })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Text('查看 ›')
                    .fontSize(12)
                    .fontColor(ThemeConstants.PRIMARY)
                }
                .width('100%')
                .padding(16)
                .backgroundColor(ThemeConstants.BG_CARD)
                .borderRadius(ThemeConstants.RADIUS_CARD)
                .onClick(() => {
                  NavRouter.toIntersection(it.id);
                })
              }
            }, (it: Intersection) => it.id)
          }
          .layoutWeight(1)
          .padding({ left: 16, right: 16 })
          .scrollBar(BarState.Off)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(ThemeConstants.BG_PAGE)
    }
    .hideTitleBar(true)
    .backgroundColor(ThemeConstants.BG_PAGE)
  }
}

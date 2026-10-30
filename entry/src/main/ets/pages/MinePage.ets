import { ThemeConstants } from '../common/constants/ThemeConstants';
import { AreaConstants } from '../common/constants/AreaConstants';
import { NavRouter } from '../common/base/NavRouter';
import { FavoriteUtil } from '../common/utils/FavoriteUtil';

interface MenuItem {
  title: string;
  desc: string;
}

/**
 * 我的：收藏、偏好、数据说明
 */
@ComponentV2
export struct MinePage {
  @Local darkMode: boolean = false;
  @Local favoriteCount: number = 0;

  private menus: MenuItem[] = [
    { title: '我收藏的路口', desc: '查看已收藏的信号路口' } as MenuItem,
    { title: '数据说明', desc: '仿真数据来源与指标口径' } as MenuItem,
    { title: '关于', desc: '版本 1.0.0 · 本科毕业设计' } as MenuItem
  ];

  aboutToAppear(): void {
    FavoriteUtil.count().then((count: number) => {
      this.favoriteCount = count;
    });
  }

  build() {
    Column() {
      // 头部
      Column() {
        Row() {
          Column() {
            Text('智行西安')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(ThemeConstants.TEXT_INVERT)
            Text(AreaConstants.AREA_NAME + ' · 信号优化')
              .fontSize(12)
              .fontColor('#DCEBFF')
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text('离线仿真')
            .fontSize(11)
            .fontColor(ThemeConstants.TEXT_INVERT)
            .backgroundColor('#FFFFFF33')
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .borderRadius(10)
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 28, bottom: 28 })
      .backgroundColor(ThemeConstants.PRIMARY)
      .borderRadius({ bottomLeft: 20, bottomRight: 20 })

      Column({ space: 12 }) {
        // 数据卡
        Row() {
          this.statItem('' + this.favoriteCount, '收藏路口')
          Divider().vertical(true).height(28).color(ThemeConstants.DIVIDER)
          this.statItem('' + AreaConstants.INTERSECTION_COUNT, '监测路口')
          Divider().vertical(true).height(28).color(ThemeConstants.DIVIDER)
          this.statItem('' + AreaConstants.SEGMENT_COUNT, '监测路段')
        }
        .width('100%')
        .padding(18)
        .backgroundColor(ThemeConstants.BG_CARD)
        .borderRadius(ThemeConstants.RADIUS_CARD)
        .justifyContent(FlexAlign.SpaceAround)

        // 菜单
        Column() {
          ForEach(this.menus, (item: MenuItem, index: number) => {
            Row() {
              Column() {
                Text(item.title)
                  .fontSize(ThemeConstants.FONT_BODY)
                  .fontColor(ThemeConstants.TEXT_MAIN)
                Text(item.desc)
                  .fontSize(11)
                  .fontColor(ThemeConstants.TEXT_SUB)
                  .margin({ top: 3 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Text('›')
                .fontSize(16)
                .fontColor(ThemeConstants.TEXT_SUB)
            }
            .width('100%')
            .padding({ top: 14, bottom: 14 })
            .onClick(() => {
              if (index === 0) {
                NavRouter.toFavorite();
              } else {
                NavRouter.toAbout();
              }
            })

            if (index < this.menus.length - 1) {
              Divider().color(ThemeConstants.DIVIDER)
            }
          }, (item: MenuItem) => item.title)
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
        .backgroundColor(ThemeConstants.BG_CARD)
        .borderRadius(ThemeConstants.RADIUS_CARD)

        // 设置项
        Row() {
          Text('深色模式')
            .fontSize(ThemeConstants.FONT_BODY)
            .fontColor(ThemeConstants.TEXT_MAIN)
          Blank()
          Toggle({ type: ToggleType.Switch, isOn: this.darkMode })
            .selectedColor(ThemeConstants.PRIMARY)
            .onChange((isOn: boolean) => {
              this.darkMode = isOn;
            })
        }
        .width('100%')
        .padding(16)
        .backgroundColor(ThemeConstants.BG_CARD)
        .borderRadius(ThemeConstants.RADIUS_CARD)

        Blank()
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 6 })
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_PAGE)
  }

  @Builder
  statItem(value: string, label: string) {
    Column() {
      Text(value)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeConstants.PRIMARY)
      Text(label)
        .fontSize(11)
        .fontColor(ThemeConstants.TEXT_SUB)
        .margin({ top: 4 })
    }
  }
}

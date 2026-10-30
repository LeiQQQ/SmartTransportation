import { ThemeConstants } from '../common/constants/ThemeConstants';
import { NavRouter } from '../common/base/NavRouter';
import { DetailParam } from '../common/base/DetailParam';
import { RepositoryFactory } from '../repository/RepositoryFactory';
import { LogUtil } from '../common/utils/LogUtil';
import { SplashView } from '../components/SplashView';
import { HomePage } from './HomePage';
import { TrafficMapPage } from './TrafficMapPage';
import { EventPage } from './EventPage';
import { MinePage } from './MinePage';
import { IntersectionDetailPage } from './IntersectionDetailPage';
import { SignalPlanPage } from './SignalPlanPage';
import { EventReportPage } from './EventReportPage';
import { FavoritePage } from './FavoritePage';
import { AboutPage } from './AboutPage';

@Entry
@ComponentV2
struct MainPage {
  @Local currentIndex: number = 0;
  @Local showSplash: boolean = true;
  @Local splashOpacity: number = 1;
  // V2 说明：此处原本是 @Provide('pathStack')，但全工程无 @Consume 消费它
  // 路由实际由 NavRouter.bind() 静态注入，故改为普通成员
  pathStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    NavRouter.bind(this.pathStack);
    this.playSplash();
    this.detectDataSource();
  }

  /**
   * 启动时探测后端是否可用（AUTO 模式生效）
   * 探测为异步，未完成时页面先用本地仿真数据，探测完成后下次刷新自动切换
   */
  private detectDataSource(): void {
    RepositoryFactory.probeRemote().then((available: boolean) => {
      LogUtil.info('MainPage', available ? '已切换到远程数据源' : '未连接远程，继续使用本地仿真数据');
    });
  }

  private playSplash(): void {
    setTimeout(() => {
      animateTo({ duration: 480, curve: Curve.EaseInOut }, () => {
        this.splashOpacity = 0;
      });
      setTimeout(() => {
        this.showSplash = false;
      }, 500);
    }, 1500);
  }

  @Builder
  pageMap(name: string, param: Object) {
    if (name === 'IntersectionDetail') {
      IntersectionDetailPage({ intersectionId: (param as DetailParam).id })
    } else if (name === 'SignalPlan') {
      SignalPlanPage({
        intersectionId: (param as DetailParam).id,
        scenario: (param as DetailParam).scenario
      })
    } else if (name === 'EventReport') {
      EventReportPage()
    } else if (name === 'Favorite') {
      FavoritePage()
    } else if (name === 'About') {
      AboutPage()
    }
  }

  @Builder
  tabItem(index: number, title: string) {
    Column() {
      Text(title)
        .fontSize(12)
        .fontWeight(this.currentIndex === index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.currentIndex === index ? ThemeConstants.PRIMARY : ThemeConstants.TEXT_SUB)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Stack() {
      Navigation(this.pathStack) {
        Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
          TabContent() {
            HomePage()
          }
          .tabBar(this.tabItem(0, '首页'))

          TabContent() {
            TrafficMapPage()
          }
          .tabBar(this.tabItem(1, '路况'))

          TabContent() {
            EventPage()
          }
          .tabBar(this.tabItem(2, '事件'))

          TabContent() {
            MinePage()
          }
          .tabBar(this.tabItem(3, '我的'))
        }
        .barHeight(ThemeConstants.BAR_HEIGHT)
        .barBackgroundColor(ThemeConstants.BG_CARD)
        .scrollable(false)
        .onChange((index: number) => {
          this.currentIndex = index;
        })
      }
      .hideTitleBar(true)
      .mode(NavigationMode.Stack)
      .navDestination(this.pageMap)
      .backgroundColor(ThemeConstants.BG_PAGE)

      if (this.showSplash) {
        SplashView({ fadeOpacity: this.splashOpacity })
          .width('100%')
          .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }
}

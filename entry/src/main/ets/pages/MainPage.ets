import { ThemeConstants } from '../common/constants/ThemeConstants';
import { NavRouter } from '../common/base/NavRouter';
import { DetailParam } from '../common/base/DetailParam';
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
@Component
struct MainPage {
  @State currentIndex: number = 0;
  @Provide('pathStack') pathStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    NavRouter.bind(this.pathStack);
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
  }
}

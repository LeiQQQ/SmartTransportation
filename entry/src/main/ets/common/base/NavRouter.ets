import { DetailParam } from './DetailParam';

/**
 * 全局路由入口
 * 由 MainPage 在创建时注入 NavPathStack，其余页面只调用语义化方法
 */
export class NavRouter {
  private static stackRef: NavPathStack | undefined = undefined;

  static bind(stack: NavPathStack): void {
    NavRouter.stackRef = stack;
  }

  private static push(name: string, param: Object): void {
    if (NavRouter.stackRef !== undefined) {
      NavRouter.stackRef.pushPathByName(name, param);
    }
  }

  static toIntersection(id: string): void {
    const param: DetailParam = new DetailParam();
    param.id = id;
    param.scenario = '';
    NavRouter.push('IntersectionDetail', param);
  }

  static toSignalPlan(id: string, scenario: string): void {
    const param: DetailParam = new DetailParam();
    param.id = id;
    param.scenario = scenario;
    NavRouter.push('SignalPlan', param);
  }

  static toEventReport(): void {
    NavRouter.push('EventReport', new DetailParam());
  }

  static toFavorite(): void {
    NavRouter.push('Favorite', new DetailParam());
  }

  static toAbout(): void {
    NavRouter.push('About', new DetailParam());
  }

  static back(): void {
    if (NavRouter.stackRef !== undefined) {
      NavRouter.stackRef.pop();
    }
  }
}

/**
 * 定时刷新控制器
 *
 * 此前 6 个页面各自写一份「setInterval + refreshing 标志 + aboutToDisappear 清理」，
 * 周期分散、逻辑重复，还容易漏掉清理导致后台空转。
 * 这里把三件事收成一个类：
 *   1. 定时触发（统一周期）
 *   2. 防重入（手动刷新时不叠加定时请求）
 *   3. 生命周期启停（页面 onPageHide/aboutToDisappear 调 stop）
 *
 * 用法：
 *   this.refresher = new RefreshController(30000, () => this.loadData(),
 *     (busy: boolean) => { this.refreshing = busy; });
 *   aboutToAppear()   → this.refresher.start()
 *   aboutToDisappear()→ this.refresher.stop()
 *   手动刷新          → this.refresher.trigger()
 */
export class RefreshController {
  private intervalMs: number;
  private task: () => Promise<void>;
  /** 刷新状态回调：把内部 busy 同步到页面的 @Local 字段，驱动按钮文案 */
  private onBusyChange: (busy: boolean) => void;
  private timerId: number = -1;
  private busy: boolean = false;

  constructor(intervalMs: number, task: () => Promise<void>, onBusyChange: (busy: boolean) => void) {
    this.intervalMs = intervalMs;
    this.task = task;
    this.onBusyChange = onBusyChange;
  }

  /** 启动定时器（重复调用不会叠加） */
  start(): void {
    this.stop();
    this.timerId = setInterval(() => {
      this.trigger();
    }, this.intervalMs);
  }

  /** 停止定时器：页面不可见时务必调用 */
  stop(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  /**
   * 执行一次刷新（定时与手动共用）
   * @returns 是否真正执行；上一次还没结束时返回 false，避免请求堆积
   */
  async trigger(): Promise<boolean> {
    if (this.busy) {
      return false;
    }
    this.busy = true;
    this.onBusyChange(true);
    try {
      await this.task();
    } finally {
      this.busy = false;
      this.onBusyChange(false);
    }
    return true;
  }

  isBusy(): boolean {
    return this.busy;
  }
}

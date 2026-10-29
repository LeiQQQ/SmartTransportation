/**
 * 页面跳转参数
 * 使用 class 而非 interface，便于在 Navigation 回调中由 Object 安全转换
 */
export class DetailParam {
  id: string = '';
  scenario: string = '';
}

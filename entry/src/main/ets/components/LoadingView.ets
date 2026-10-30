import { ThemeConstants } from '../common/constants/ThemeConstants';

@ComponentV2
export struct LoadingView {
  @Param tip: string = '加载中…';

  build() {
    Column() {
      LoadingProgress()
        .width(36)
        .height(36)
        .color(ThemeConstants.PRIMARY)
      Text(this.tip)
        .fontSize(12)
        .fontColor(ThemeConstants.TEXT_SUB)
        .margin({ top: 10 })
    }
    .width('100%')
    .padding({ top: 60, bottom: 60 })
    .justifyContent(FlexAlign.Center)
  }
}

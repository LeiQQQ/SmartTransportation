import { ThemeConstants } from '../common/constants/ThemeConstants';

@Component
export struct EmptyView {
  @Prop tip: string = '暂无数据';

  build() {
    Column() {
      Circle()
        .width(56)
        .height(56)
        .fill('#EDF0F5')
      Text(this.tip)
        .fontSize(13)
        .fontColor(ThemeConstants.TEXT_SUB)
        .margin({ top: 12 })
    }
    .width('100%')
    .padding({ top: 60, bottom: 60 })
    .justifyContent(FlexAlign.Center)
  }
}

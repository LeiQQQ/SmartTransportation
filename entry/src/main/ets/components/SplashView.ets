import { ThemeConstants } from '../common/constants/ThemeConstants';

/**
 * 启动动画：品牌渐变背景 + Logo 缩放淡入 + 光圈扩散 + 文字上浮
 */
@ComponentV2
export struct SplashView {
  @Param fadeOpacity: number = 1;

  @Local logoScale: number = 0.72;
  @Local logoOpacity: number = 0;
  @Local ringScale: number = 0.55;
  @Local ringOpacity: number = 0.55;
  @Local textOpacity: number = 0;
  @Local textOffset: number = 18;

  aboutToAppear(): void {
    animateTo({ duration: 620, curve: Curve.Friction }, () => {
      this.logoScale = 1;
      this.logoOpacity = 1;
    });
    animateTo({ duration: 1000, curve: Curve.EaseOut }, () => {
      this.ringScale = 2.1;
      this.ringOpacity = 0;
    });
    animateTo({ duration: 520, delay: 260, curve: Curve.EaseOut }, () => {
      this.textOpacity = 1;
      this.textOffset = 0;
    });
  }

  build() {
    Column() {
      Stack() {
        Circle()
          .width(132)
          .height(132)
          .fill(Color.Transparent)
          .stroke('#FFFFFF')
          .strokeWidth(2)
          .opacity(this.ringOpacity)
          .scale({ x: this.ringScale, y: this.ringScale })

        Image($r('app.media.app_icon'))
          .width(118)
          .height(118)
          .borderRadius(26)
          .opacity(this.logoOpacity)
          .scale({ x: this.logoScale, y: this.logoScale })
          .shadow({ radius: 24, color: '#4D000000', offsetX: 0, offsetY: 10 })
      }
      .width(180)
      .height(180)

      Text('智行西安')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeConstants.TEXT_INVERT)
        .letterSpacing(4)
        .opacity(this.textOpacity)
        .translate({ y: this.textOffset })
        .margin({ top: 8 })

      Text('西安城墙内 · 片区信号优化')
        .fontSize(12)
        .fontColor('#E6FFFFFF')
        .letterSpacing(1)
        .opacity(this.textOpacity)
        .translate({ y: this.textOffset })
        .margin({ top: 10 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .linearGradient({
      angle: 165,
      colors: [['#4A3BEF', 0.0], ['#2E7FE0', 0.55], ['#3DDC84', 1.0]]
    })
    .opacity(this.fadeOpacity)
  }
}

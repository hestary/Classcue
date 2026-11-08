import { webview } from '@kit.ArkWeb';
import { promptAction } from '@kit.ArkUI';
import { CourseItem } from '../model/CourseItem';
import { JluParseResult, JluScheduleParser } from '../service/JluScheduleParser';

const LOGIN_URL: string = 'https://iedu.jlu.edu.cn/';
const SCHEDULE_URL: string = 'https://iedu.jlu.edu.cn/jwapp/sys/wdkb/*default/index.do';
const COLOR_BACKGROUND: string = '#F4F6F5';
const COLOR_SURFACE: string = '#FFFFFF';
const COLOR_PRIMARY: string = '#167A5B';
const COLOR_TEXT: string = '#18201D';
const COLOR_MUTED: string = '#66736E';
const COLOR_BORDER: string = '#DEE4E1';
const COLOR_DANGER: string = '#C6463D';

const CAPTURE_SCRIPT: string = `
(function () {
  if (window.__lockTodoJluHooked) return;
  window.__lockTodoJluHooked = true;
  window.__lockTodoScheduleCaptures = [];
  function relevant(url) {
    var value = String(url || '').toLowerCase();
    return value.indexOf('cxxszhxqkb.do') >= 0 || value.indexOf('modules/xskcb') >= 0;
  }
  function save(url, text) {
    try {
      if (!relevant(url) || !text || text.indexOf('"datas"') < 0 || text.indexOf('"rows"') < 0) return;
      window.__lockTodoScheduleCaptures.push({ url: String(url), text: String(text) });
      if (window.__lockTodoScheduleCaptures.length > 8) window.__lockTodoScheduleCaptures.shift();
    } catch (e) {}
  }
  var originalOpen = XMLHttpRequest.prototype.open;
  var originalSend = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.open = function(method, url) {
    this.__lockTodoUrl = url || '';
    return originalOpen.apply(this, arguments);
  };
  XMLHttpRequest.prototype.send = function() {
    this.addEventListener('load', function() { save(this.__lockTodoUrl, this.responseText || ''); });
    return originalSend.apply(this, arguments);
  };
  if (window.fetch) {
    var originalFetch = window.fetch;
    window.fetch = function(input, init) {
      var url = typeof input === 'string' ? input : ((input && input.url) || '');
      return originalFetch(input, init).then(function(response) {
        if (relevant(url)) {
          try { response.clone().text().then(function(text) { save(url, text); }).catch(function() {}); } catch (e) {}
        }
        return response;
      });
    };
  }
})();`;

interface CapturedResponse {
  url: string;
  text: string;
}

@Component
export struct CourseImportPage {
  onClose: () => void = () => {};
  onImported: (courses: CourseItem[], semesterStartAt: number, replace: boolean) => void = () => {};
  private controller: webview.WebviewController = new webview.WebviewController();
  @State private currentUrl: string = LOGIN_URL;
  @State private status: string = '请在学校页面登录，然后打开“我的课表”';
  @State private importing: boolean = false;
  private pendingResult: JluParseResult = new JluParseResult();

  private openLogin(): void {
    this.controller.loadUrl(LOGIN_URL);
    this.status = '请在吉林大学统一认证页面完成登录';
  }

  private openSchedule(): void {
    this.controller.loadUrl(SCHEDULE_URL);
    this.status = '正在打开我的课表，看到课程后点击下方导入';
  }

  private async clearLogin(): Promise<void> {
    try {
      await webview.WebCookieManager.clearAllCookies();
      this.controller.clearHistory();
      this.controller.loadUrl(LOGIN_URL);
      this.status = '登录信息已清除，请重新登录';
    } catch (error) {
      promptAction.showToast({ message: '清除登录失败，请稍后重试' });
    }
  }

  private async importCaptured(): Promise<void> {
    if (this.importing) {
      return;
    }
    this.importing = true;
    this.status = '正在读取课表数据…';
    try {
      const rawResult: string = await this.controller.runJavaScript(
        'JSON.stringify(window.__lockTodoScheduleCaptures || [])');
      const decoded: string = rawResult.startsWith('"') ? JSON.parse(rawResult) as string : rawResult;
      const captures: CapturedResponse[] = JSON.parse(decoded) as CapturedResponse[];
      let best: JluParseResult = new JluParseResult();
      captures.forEach((capture: CapturedResponse) => {
        const parsed: JluParseResult = JluScheduleParser.parse(capture.text);
        if (parsed.courses.length >= best.courses.length) {
          best = parsed;
        }
      });
      if (best.courses.length === 0) {
        this.status = '还未捕获到课表。请先点击“我的课表”，等课程显示后再导入。';
        return;
      }
      this.pendingResult = best;
      this.status = `已识别 ${best.courses.length} 条课程安排`;
      this.chooseMode();
    } catch (error) {
      this.status = '读取失败，请重新打开“我的课表”后再试';
    } finally {
      this.importing = false;
    }
  }

  private chooseMode(): void {
    const semester: string = this.pendingResult.semesterLabel.length > 0 ?
      `\n学期：${this.pendingResult.semesterLabel}` : '';
    this.getUIContext().showAlertDialog({
      title: '导入课程表',
      message: `识别到 ${this.pendingResult.courses.length} 条课程安排。${semester}`,
      primaryButton: {
        value: '覆盖当前课表',
        action: () => {
          this.finishImport(true);
        }
      },
      secondaryButton: {
        value: '追加到课表',
        action: () => {
          this.finishImport(false);
        }
      }
    });
  }

  private finishImport(replace: boolean): void {
    this.onImported(this.pendingResult.courses, this.pendingResult.semesterStartAt, replace);
    this.controller.runJavaScript('window.__lockTodoScheduleCaptures = [];').catch(() => {});
  }

  build() {
    Column() {
      Row() {
        Button('‹', { type: ButtonType.Normal })
          .width(42)
          .height(42)
          .fontSize(24)
          .fontColor(COLOR_MUTED)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.onClose();
          });
        Text('吉林大学教务导入')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT);
        Blank();
        Button('清除登录', { type: ButtonType.Normal })
          .height(36)
          .fontSize(13)
          .fontColor(COLOR_DANGER)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.clearLogin();
          });
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 12 })
      .backgroundColor(COLOR_SURFACE)
      .border({ width: { bottom: 1 }, color: COLOR_BORDER });

      Text(this.status)
        .width('100%')
        .fontSize(12)
        .fontColor(COLOR_MUTED)
        .padding({ left: 14, right: 14, top: 8, bottom: 8 })
        .backgroundColor('#EDF3F0')
        .maxLines(2);

      Row({ space: 8 }) {
        Button('登录首页', { type: ButtonType.Normal })
          .layoutWeight(1)
          .height(40)
          .fontSize(14)
          .fontColor(COLOR_PRIMARY)
          .backgroundColor('#E8F3EF')
          .borderRadius(6)
          .onClick(() => {
            this.openLogin();
          });
        Button('我的课表', { type: ButtonType.Normal })
          .layoutWeight(1)
          .height(40)
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor(COLOR_PRIMARY)
          .borderRadius(6)
          .onClick(() => {
            this.openSchedule();
          });
      }
      .width('100%')
      .padding({ left: 10, right: 10, top: 8, bottom: 8 })
      .backgroundColor(COLOR_SURFACE);

      Web({ src: this.currentUrl, controller: this.controller })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .mixedMode(MixedMode.Compatible)
        .javaScriptOnDocumentStart([{
          script: CAPTURE_SCRIPT,
          scriptRules: ['*']
        }])
        .onPageBegin(() => {
          this.controller.runJavaScript(CAPTURE_SCRIPT).catch(() => {});
        })
        .onPageEnd(() => {
          this.currentUrl = this.controller.getUrl();
        })
        .width('100%')
        .layoutWeight(1);

      Button(this.importing ? '正在导入…' : '导入已显示的课表', { type: ButtonType.Normal })
        .width('calc(100% - 20vp)')
        .height(50)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .backgroundColor(COLOR_PRIMARY)
        .borderRadius(8)
        .enabled(!this.importing)
        .margin({ left: 10, right: 10, top: 8, bottom: 10 })
        .onClick(() => {
          this.importCaptured();
        });
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BACKGROUND);
  }
}

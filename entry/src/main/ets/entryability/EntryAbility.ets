import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

const DOMAIN: number = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'LockTodo', 'EntryAbility created');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (error) => {
      if (error.code) {
        hilog.error(DOMAIN, 'LockTodo', 'Unable to load the main page: %{public}s', JSON.stringify(error));
      }
    });

    windowStage.getMainWindow((error, mainWindow) => {
      if (error.code) {
        return;
      }
      mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#F4F6F5',
        statusBarContentColor: '#18201D',
        navigationBarColor: '#F4F6F5',
        navigationBarContentColor: '#18201D'
      });
    });
  }
}

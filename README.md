# ClassCue

ClassCue 是一个面向学生的待办与课程表应用，同时提供 HarmonyOS 原生版和 Android 版。待办、课程与提醒数据保存在本机，不会上传个人内容。

## 主要功能

- 创建、编辑、完成和分类管理待办
- 为待办添加备注、日期、地点和图片
- 可设置多次提前提醒及到期提醒
- 在系统通知与锁屏上显示提醒
- 按周查看课表，左右滑动切换周次
- 支持单双周、分段周次和同一课程不同地点
- 点击课程快速创建关联待办
- 根据已导入课程自动生成课程分类
- 通过吉林大学统一认证导入“我的课表”
- 提供校外 VPN 登录入口

教务导入由学校网页完成认证。应用不保存学号或密码，只读取课表接口返回的课程、地点、周次和节次；清除登录后会删除内嵌网页的登录 Cookie。

## 项目结构

```text
AppScope/       HarmonyOS 应用级资源
entry/          HarmonyOS 原生版主模块
android-app/    Android 版工程
```

## HarmonyOS 版运行方式

1. 安装 DevEco Studio 和 HarmonyOS 5 对应 SDK。
2. 在 DevEco Studio 中打开项目根目录并等待同步。
3. 在 `File > Project Structure > Signing Configs` 中登录华为开发者账号并开启自动签名。
4. 连接已开启开发者模式和 USB 调试的华为手机。
5. 选择 `entry` 模块和真机后运行。

HarmonyOS 版不会提交本机签名配置。首次打开项目后，需要按第 3 步为自己的设备重新生成签名。

## Android 版运行方式

1. 使用 Android Studio 打开 `android-app` 目录。
2. 安装 Android SDK 35，并使用 JDK 17 或更高版本同步工程。
3. 运行 `app` 模块，或通过 `Build > Build APK(s)` 生成测试安装包。

正式发布时请自行创建签名密钥。仓库不会包含发布密钥、签名密码或已经签名的 APK。

## 通知说明

首次保存带提醒的待办时，请允许通知权限，并在手机的应用通知设置中开启锁屏通知和通知内容显示。普通第三方应用不能永久覆盖系统锁屏，ClassCue 使用系统通知或系统代理提醒在到期时显示内容。

## 开源参考

课表的数据设计、吉林大学节次时间和交互思路参考了 [JFyuhong/JLU_schedule](https://github.com/JFyuhong/JLU_schedule/tree/3070fd74f4919e2ce68093251e87d72fc64aa4af) 指定版本，并按本项目结构重新实现。

## 其他说明

- HarmonyOS 包名目前为 `com.example.locktodo`，正式发布前建议改为自己的唯一包名。
- Android 包名为 `com.classcue.android`。
- 图片使用系统相册返回的授权地址，不会复制或上传原图。

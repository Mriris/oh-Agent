import { hilog } from '@kit.PerformanceAnalysisKit';
import { AutoGLMService, TaskCallback } from '../services/AutoGLMService';
import { preferences } from '@kit.ArkData';

// 任务执行状态枚举
enum TaskStatus {
  IDLE = 'idle',
  CONNECTING = 'connecting',
  EXECUTING = 'executing',
  SUCCESS = 'success',
  FAILED = 'failed'
}

@Entry
@Component
struct Index {
  // 状态管理
  @State taskInput: string = '';
  @State taskStatus: TaskStatus = TaskStatus.IDLE;
  @State statusMessage: string = '未连接';
  @State isAnimating: boolean = false;
  @State aiThinking: string = '';
  @State currentAction: string = '';
  @State stepCount: number = 0;
  @State isConnected: boolean = false;  // 连接状态（用于 UI 刷新）
  @State expandedStatus: boolean = false;  // 状态区域是否展开

  // 配置
  @State serverUrl: string = 'http://192.168.1.105:7860';
  @State deviceId: string = '127.0.0.1:5555';  // HDC 默认设备
  @State showConfig: boolean = false;

  // 服务实例
  private autoGLMService: AutoGLMService = new AutoGLMService();

  // 组件生命周期
  async aboutToAppear() {
    await this.loadConfig();
    await this.initService();
  }

  // 加载配置
  async loadConfig(): Promise<void> {
    try {
      const context = getContext(this);
      const dataPreferences = preferences.getPreferencesSync(context, { name: 'agent_config' });

      const savedServerUrl = dataPreferences.getSync('serverUrl', this.serverUrl) as string;
      const savedDeviceId = dataPreferences.getSync('deviceId', this.deviceId) as string;

      this.serverUrl = savedServerUrl;
      this.deviceId = savedDeviceId;

      hilog.info(0x0000, 'Agent', `配置已加载: ${this.serverUrl}, ${this.deviceId}`);
    } catch (error) {
      hilog.warn(0x0000, 'Agent', '加载配置失败，使用默认值');
    }
  }

  // 保存配置
  async saveConfig(): Promise<void> {
    try {
      const context = getContext(this);
      const dataPreferences = preferences.getPreferencesSync(context, { name: 'agent_config' });

      dataPreferences.putSync('serverUrl', this.serverUrl);
      dataPreferences.putSync('deviceId', this.deviceId);
      dataPreferences.flush();

      hilog.info(0x0000, 'Agent', '配置已保存');
      this.updateStatus(TaskStatus.IDLE, '配置已保存');
    } catch (error) {
      hilog.error(0x0000, 'Agent', `保存配置失败: ${error}`);
    }
  }

  // 初始化服务
  async initService(): Promise<void> {
    try {
      this.updateStatus(TaskStatus.CONNECTING, '连接中...');
      this.isConnected = false;

      // 配置服务
      this.autoGLMService.configure(this.serverUrl, this.deviceId);

      // 连接到后端
      await this.autoGLMService.connect();

      this.updateStatus(TaskStatus.IDLE, '已连接');
      this.isConnected = true;
      hilog.info(0x0000, 'Agent', '服务初始化成功');
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      hilog.error(0x0000, 'Agent', `初始化失败: ${errorMsg}`);
      this.updateStatus(TaskStatus.FAILED, `连接失败: ${errorMsg}`);
      this.isConnected = false;
    }
  }

  // 重新连接
  async reconnect(): Promise<void> {
    this.autoGLMService.disconnect();
    this.isConnected = false;
    await this.initService();
  }

  // 执行任务
  async executeTask(): Promise<void> {
    if (!this.taskInput.trim()) {
      this.updateStatus(TaskStatus.FAILED, '请输入任务指令');
      return;
    }

    if (!this.isConnected) {
      this.updateStatus(TaskStatus.FAILED, '未连接到后端');
      return;
    }

    this.updateStatus(TaskStatus.EXECUTING, '正在执行...');
    this.aiThinking = '';
    this.currentAction = '';
    this.stepCount = 0;

    try {
      const callback: TaskCallback = {
        onStarted: () => {
          this.updateStatus(TaskStatus.EXECUTING, '任务已开始');
        },
        onThinking: (thinking: string) => {
          this.aiThinking = thinking;
          this.updateStatus(TaskStatus.EXECUTING, 'AI 正在思考...');
        },
        onAction: (action: string) => {
          this.currentAction = action;
          this.stepCount++;
          this.updateStatus(TaskStatus.EXECUTING, `执行中 (步骤 ${this.stepCount})...`);
        },
        onCompleted: (result: string, steps: number) => {
          this.stepCount = steps;
          this.updateStatus(TaskStatus.SUCCESS, `完成: ${result}`);
        },
        onFailed: (error: string) => {
          this.updateStatus(TaskStatus.FAILED, `失败: ${error}`);
        }
      };

      await this.autoGLMService.executeTask(this.taskInput, callback);
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      hilog.error(0x0000, 'Agent', `任务执行失败: ${errorMsg}`);
      this.updateStatus(TaskStatus.FAILED, `执行失败: ${errorMsg}`);
    }
  }

  // 更新状态
  updateStatus(status: TaskStatus, message: string): void {
    this.taskStatus = status;
    this.statusMessage = message;
    // 新状态时自动收起展开区域
    this.expandedStatus = false;
  }

  // 获取状态颜色
  getStatusColor(): string {
    switch (this.taskStatus) {
      case TaskStatus.IDLE:
        return '#8892b0';
      case TaskStatus.CONNECTING:
        return '#a200ff';
      case TaskStatus.EXECUTING:
        return '#00d9ff';
      case TaskStatus.SUCCESS:
        return '#05ffa1';
      case TaskStatus.FAILED:
        return '#ff2a6d';
      default:
        return '#8892b0';
    }
  }

  build() {
    Stack() {
      // 赛博朋克风格背景
      this.buildBackground()

      // 可滚动内容
      Scroll() {
        Column() {
          // 标题
          this.buildTitle()

          // 连接状态和配置按钮
          this.buildConnectionStatus()

          // 配置界面（可展开）
          if (this.showConfig) {
            this.buildConfigPanel()
          }

          // 输入区域
          this.buildInputArea()

          // 按钮组
          this.buildButtonGroup()

          // AI 思考显示
          if (this.aiThinking) {
            this.buildThinkingArea()
          }

          // 动作显示
          if (this.currentAction) {
            this.buildActionArea()
          }

          // 状态显示
          this.buildStatusArea()
        }
        .width('90%')
        .padding(24)
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Top)
  }

  // 背景组件
  @Builder
  buildBackground() {
    Column()
      .width('100%')
      .height('100%')
      .linearGradient({
        angle: 180,
        colors: [
          ['#0a0e27', 0.0],
          ['#1a1a2e', 0.5],
          ['#0a0e27', 1.0]
        ]
      })
  }

  // 标题组件
  @Builder
  buildTitle() {
    Column() {
      Text('AGENT CONTROLLER')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor('#ffffff')
        .textShadow({
          radius: 20,
          color: '#00d9ff',
          offsetX: 0,
          offsetY: 0
        })
        .letterSpacing(2)

      Text('AutoGLM Real Control')
        .fontSize(12)
        .fontColor('#8892b0')
        .margin({ top: 8 })
        .letterSpacing(1)
    }
    .margin({ top: 24, bottom: 24 })
  }

  // 连接状态组件
  @Builder
  buildConnectionStatus() {
    Row() {
      Row() {
        Circle()
          .width(8)
          .height(8)
          .fill(this.isConnected ? '#05ffa1' : '#ff2a6d')
          .shadow({
            radius: 6,
            color: this.isConnected ? '#05ffa1' : '#ff2a6d',
            offsetX: 0,
            offsetY: 0
          })
          .margin({ right: 8 })

        Text(this.isConnected ? '已连接' : '未连接')
          .fontSize(12)
          .fontColor('#ffffff')
      }

      Row() {
        Button('配置')
          .fontSize(12)
          .height(32)
          .padding({ left: 16, right: 16 })
          .backgroundColor('rgba(0, 217, 255, 0.2)')
          .borderRadius(16)
          .onClick(() => {
            this.showConfig = !this.showConfig;
          })

        if (!this.isConnected) {
          Button('重连')
            .fontSize(12)
            .height(32)
            .padding({ left: 16, right: 16 })
            .backgroundColor('rgba(5, 255, 161, 0.2)')
            .borderRadius(16)
            .margin({ left: 8 })
            .onClick(() => {
              this.reconnect();
            })
        }
      }
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .backgroundColor('rgba(26, 26, 46, 0.6)')
    .borderRadius(8)
    .borderWidth(1)
    .borderColor('rgba(0, 217, 255, 0.2)')
    .justifyContent(FlexAlign.SpaceBetween)
    .margin({ bottom: 16 })
  }

  // 配置面板
  @Builder
  buildConfigPanel() {
    Column() {
      Text('后端配置')
        .fontSize(14)
        .fontColor('#8892b0')
        .margin({ bottom: 12 })
        .alignSelf(ItemAlign.Start)

      Column() {
        Text('服务器地址')
          .fontSize(12)
          .fontColor('#8892b0')
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 4 })

        TextInput({ placeholder: 'http://192.168.1.100:7860', text: this.serverUrl })
          .fontSize(14)
          .fontColor('#ffffff')
          .backgroundColor('rgba(0, 217, 255, 0.05)')
          .borderRadius(8)
          .borderWidth(1)
          .borderColor('rgba(0, 217, 255, 0.3)')
          .onChange((value: string) => {
            this.serverUrl = value;
          })
      }
      .margin({ bottom: 12 })

      Column() {
        Text('设备 ID')
          .fontSize(12)
          .fontColor('#8892b0')
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 4 })

        TextInput({ placeholder: '留空使用默认设备', text: this.deviceId })
          .fontSize(14)
          .fontColor('#ffffff')
          .backgroundColor('rgba(0, 217, 255, 0.05)')
          .borderRadius(8)
          .borderWidth(1)
          .borderColor('rgba(0, 217, 255, 0.3)')
          .onChange((value: string) => {
            this.deviceId = value;
          })
      }
      .margin({ bottom: 12 })

      Button('保存并重连')
        .width('100%')
        .height(40)
        .fontSize(14)
        .backgroundColor('#00d9ff')
        .borderRadius(20)
        .onClick(async () => {
          await this.saveConfig();
          this.showConfig = false;
          await this.reconnect();
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('rgba(26, 26, 46, 0.8)')
    .borderRadius(12)
    .borderWidth(1)
    .borderColor('rgba(0, 217, 255, 0.3)')
    .margin({ bottom: 16 })
  }

  // 输入区域组件
  @Builder
  buildInputArea() {
    TextArea({
      placeholder: '输入任务指令（如：打开设置）',
      text: this.taskInput
    })
      .width('100%')
      .height(100)
      .fontSize(16)
      .fontColor('#ffffff')
      .placeholderColor('rgba(136, 146, 176, 0.5)')
      .backgroundColor('rgba(0, 217, 255, 0.05)')
      .borderRadius(12)
      .borderWidth(2)
      .borderColor(this.isAnimating ? '#00d9ff' : 'rgba(0, 217, 255, 0.3)')
      .padding(16)
      .margin({ bottom: 16 })
      .onChange((value: string) => {
        this.taskInput = value;
      })
      .onFocus(() => {
        this.isAnimating = true;
      })
      .onBlur(() => {
        this.isAnimating = false;
      })
      .animation({
        duration: 300,
        curve: Curve.EaseInOut
      })
      .shadow({
        radius: this.isAnimating ? 20 : 10,
        color: this.isAnimating ? 'rgba(0, 217, 255, 0.5)' : 'rgba(0, 217, 255, 0.2)',
        offsetX: 0,
        offsetY: 0
      })
      .animation({
        duration: 300,
        curve: Curve.EaseInOut
      })
  }

  // 按钮组
  @Builder
  buildButtonGroup() {
    Row() {
      Button('执行任务')
        .width('100%')
        .height(50)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#0a0e27')
        .backgroundColor('#00d9ff')
        .borderRadius(25)
        .enabled(this.taskStatus !== TaskStatus.EXECUTING && this.isConnected)
        .opacity(this.taskStatus === TaskStatus.EXECUTING ? 0.6 : 1.0)
        .onClick(() => {
          this.executeTask();
        })
        .shadow({
          radius: 25,
          color: 'rgba(0, 217, 255, 0.6)',
          offsetX: 0,
          offsetY: 0
        })
        .stateEffect(true)
    }
    .width('100%')
    .margin({ bottom: 24 })
  }

  // AI 思考区域
  @Builder
  buildThinkingArea() {
    Column() {
      Text('💭 AI 思考')
        .fontSize(12)
        .fontColor('#8892b0')
        .margin({ bottom: 8 })

      Text(this.aiThinking)
        .fontSize(14)
        .fontColor('#ffffff')
        .lineHeight(20)
        .maxLines(5)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('rgba(0, 217, 255, 0.08)')
    .borderRadius(8)
    .borderWidth(1)
    .borderColor('rgba(0, 217, 255, 0.2)')
    .alignItems(HorizontalAlign.Start)
    .margin({ bottom: 16 })
  }

  // 动作区域
  @Builder
  buildActionArea() {
    Column() {
      Text('⚡ 执行动作')
        .fontSize(12)
        .fontColor('#8892b0')
        .margin({ bottom: 8 })

      Text(this.currentAction)
        .fontSize(14)
        .fontColor('#05ffa1')
        .fontFamily('monospace')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('rgba(5, 255, 161, 0.08)')
    .borderRadius(8)
    .borderWidth(1)
    .borderColor('rgba(5, 255, 161, 0.2)')
    .alignItems(HorizontalAlign.Start)
    .margin({ bottom: 16 })
  }

  // 状态显示区域
  @Builder
  buildStatusArea() {
    Column() {
      Row() {
        Text('状态')
          .fontSize(12)
          .fontColor('#8892b0')

        if (this.statusMessage.length > 50) {
          Text(this.expandedStatus ? '收起 ▲' : '展开 ▼')
            .fontSize(10)
            .fontColor('#00d9ff')
            .margin({ left: 8 })
            .onClick(() => {
              this.expandedStatus = !this.expandedStatus;
            })
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ bottom: 8 })

      Column() {
        Row() {
          Circle()
            .width(10)
            .height(10)
            .fill(this.getStatusColor())
            .shadow({
              radius: 8,
              color: this.getStatusColor(),
              offsetX: 0,
              offsetY: 0
            })
            .margin({ right: 10 })
            .alignSelf(ItemAlign.Start)

          if (this.expandedStatus || this.statusMessage.length <= 50) {
            // 展开模式或短文本：显示完整内容，支持滚动
            Column() {
              Scroll() {
                Text(this.statusMessage)
                  .fontSize(14)
                  .fontColor('#ffffff')
                  .lineHeight(20)
                  .wordBreak(WordBreak.BREAK_ALL)
              }
              .width('100%')
              .scrollBar(BarState.Auto)
            }
            .width('100%')
            .constraintSize({ maxHeight: 200 })
          } else {
            // 折叠模式：只显示前 50 个字符
            Text(this.statusMessage.substring(0, 50) + '...')
              .fontSize(14)
              .fontColor('#ffffff')
              .lineHeight(20)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .onClick(() => {
                this.expandedStatus = true;
              })
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        .alignItems(VerticalAlign.Top)
      }
      .width('100%')
      .backgroundColor('rgba(26, 26, 46, 0.6)')
      .borderRadius(8)
      .borderWidth(1)
      .borderColor('rgba(0, 217, 255, 0.2)')
      .animation({
        duration: 300,
        curve: Curve.EaseInOut
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ bottom: 24 })
  }
}

import { hilog } from '@kit.PerformanceAnalysisKit';
import { display } from '@kit.ArkUI';

// 动作类型
export enum ActionType {
  TAP = 'Tap',
  SWIPE = 'Swipe',
  TYPE = 'Type',
  BACK = 'Back',
  HOME = 'Home',
  LONG_PRESS = 'LongPress',
  DOUBLE_TAP = 'DoubleTap'
}

// 动作接口
export interface Action {
  type: ActionType;
  element?: number[] | number[][];
  text?: string;
}

// 动作参数映射接口
interface ActionParams {
  action: string;
  element?: number[] | number[][];
  text?: string;
}

/**
 * 设备控制服务（演示模式）
 * 注意：UiTest Driver API 只能在测试目录使用
 * 此版本为演示实现，模拟设备控制操作
 */
export class DeviceController {
  private screenWidth: number = 1080;
  private screenHeight: number = 2400;
  private isInitialized: boolean = false;

  /**
   * 初始化控制器
   */
  async init(): Promise<void> {
    try {
      hilog.info(0x0000, 'DeviceController', '初始化设备控制器（演示模式）');

      // 获取屏幕尺寸
      await this.getScreenSize();

      this.isInitialized = true;
      hilog.info(0x0000, 'DeviceController', `初始化成功，屏幕尺寸: ${this.screenWidth}x${this.screenHeight}`);
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      hilog.error(0x0000, 'DeviceController', `初始化失败: ${errorMsg}`);
      throw new Error(`设备控制器初始化失败: ${errorMsg}`);
    }
  }

  /**
   * 获取屏幕尺寸
   */
  private async getScreenSize(): Promise<void> {
    try {
      const displayInfo = display.getDefaultDisplaySync();
      this.screenWidth = displayInfo.width;
      this.screenHeight = displayInfo.height;
      hilog.info(0x0000, 'DeviceController', `屏幕尺寸: ${this.screenWidth}x${this.screenHeight}`);
    } catch (error) {
      hilog.warn(0x0000, 'DeviceController', '获取屏幕尺寸失败，使用默认值');
      this.screenWidth = 1080;
      this.screenHeight = 2400;
    }
  }

  /**
   * 执行动作（演示模式）
   */
  async executeAction(action: Action): Promise<void> {
    if (!this.isInitialized) {
      throw new Error('控制器未初始化');
    }

    hilog.info(0x0000, 'DeviceController', `[演示] 执行动作: ${JSON.stringify(action)}`);

    try {
      switch (action.type) {
        case ActionType.TAP:
          await this.tap(action.element as number[]);
          break;
        case ActionType.SWIPE:
          await this.swipe(action.element as number[][]);
          break;
        case ActionType.TYPE:
          await this.type(action.text || '');
          break;
        case ActionType.BACK:
          await this.back();
          break;
        case ActionType.HOME:
          await this.home();
          break;
        case ActionType.LONG_PRESS:
          await this.longPress(action.element as number[]);
          break;
        case ActionType.DOUBLE_TAP:
          await this.doubleTap(action.element as number[]);
          break;
        default:
          throw new Error(`不支持的动作类型: ${action.type}`);
      }

      hilog.info(0x0000, 'DeviceController', `[演示] 动作执行成功: ${action.type}`);
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      hilog.error(0x0000, 'DeviceController', `动作执行失败: ${errorMsg}`);
      throw new Error(`动作执行失败: ${errorMsg}`);
    }
  }

  /**
   * 点击（演示模式）
   */
  private async tap(element: number[]): Promise<void> {
    if (!element || element.length !== 2) {
      throw new Error('点击坐标无效');
    }

    const x = Math.floor((element[0] / 1000) * this.screenWidth);
    const y = Math.floor((element[1] / 1000) * this.screenHeight);

    hilog.info(0x0000, 'DeviceController', `[演示] 点击坐标: (${x}, ${y})`);
    hilog.info(0x0000, 'DeviceController', `[演示] 归一化坐标: (${element[0]}, ${element[1]}) => 实际坐标: (${x}, ${y})`);

    await this.delay(500);
  }

  /**
   * 滑动（演示模式）
   */
  private async swipe(element: number[][]): Promise<void> {
    if (!element || element.length !== 2) {
      throw new Error('滑动坐标无效');
    }

    const startX = Math.floor((element[0][0] / 1000) * this.screenWidth);
    const startY = Math.floor((element[0][1] / 1000) * this.screenHeight);
    const endX = Math.floor((element[1][0] / 1000) * this.screenWidth);
    const endY = Math.floor((element[1][1] / 1000) * this.screenHeight);

    hilog.info(0x0000, 'DeviceController', `[演示] 滑动: (${startX},${startY}) -> (${endX},${endY})`);
    hilog.info(0x0000, 'DeviceController', `[演示] 滑动距离: ${Math.abs(endX - startX)}px 水平, ${Math.abs(endY - startY)}px 垂直`);

    await this.delay(800);
  }

  /**
   * 输入文本（演示模式）
   */
  private async type(text: string): Promise<void> {
    hilog.info(0x0000, 'DeviceController', `[演示] 输入文本: "${text}" (${text.length} 个字符)`);
    await this.delay(500);
  }

  /**
   * 返回键（演示模式）
   */
  private async back(): Promise<void> {
    hilog.info(0x0000, 'DeviceController', '[演示] 按返回键');
    await this.delay(500);
  }

  /**
   * 主页键（演示模式）
   */
  private async home(): Promise<void> {
    hilog.info(0x0000, 'DeviceController', '[演示] 按主页键');
    await this.delay(500);
  }

  /**
   * 长按（演示模式）
   */
  private async longPress(element: number[]): Promise<void> {
    if (!element || element.length !== 2) {
      throw new Error('长按坐标无效');
    }

    const x = Math.floor((element[0] / 1000) * this.screenWidth);
    const y = Math.floor((element[1] / 1000) * this.screenHeight);

    hilog.info(0x0000, 'DeviceController', `[演示] 长按坐标: (${x}, ${y})`);
    await this.delay(1000);
  }

  /**
   * 双击（演示模式）
   */
  private async doubleTap(element: number[]): Promise<void> {
    if (!element || element.length !== 2) {
      throw new Error('双击坐标无效');
    }

    const x = Math.floor((element[0] / 1000) * this.screenWidth);
    const y = Math.floor((element[1] / 1000) * this.screenHeight);

    hilog.info(0x0000, 'DeviceController', `[演示] 双击坐标: (${x}, ${y})`);
    await this.delay(600);
  }

  /**
   * 截屏（演示模式 - 返回模拟数据）
   */
  async takeScreenshot(): Promise<string> {
    hilog.info(0x0000, 'DeviceController', '[演示] 截屏功能已禁用（演示模式）');
    // 返回空字符串，表示没有截图
    return '';
  }

  /**
   * 延迟
   */
  private async delay(ms: number): Promise<void> {
    return new Promise<void>(resolve => setTimeout(resolve, ms));
  }

  /**
   * 获取屏幕尺寸
   */
  getScreenDimensions(): ScreenDimensions {
    return {
      width: this.screenWidth,
      height: this.screenHeight
    };
  }

  /**
   * 销毁
   */
  destroy(): void {
    this.isInitialized = false;
    hilog.info(0x0000, 'DeviceController', '控制器已销毁');
  }
}

// 屏幕尺寸接口
interface ScreenDimensions {
  width: number;
  height: number;
}

/**
 * 解析 AI 返回的动作字符串
 * @param actionString 例如: do(action="Tap", element=[500, 800])
 */
export function parseActionString(actionString: string): Action | null {
  try {
    hilog.info(0x0000, 'DeviceController', `解析动作字符串: ${actionString}`);

    // 移除 do( 和 finish( 前缀
    const cleanString = actionString
      .replace(/^do\(/, '')
      .replace(/^finish\(/, '')
      .replace(/\)$/, '');

    // 解析参数
    const params: ActionParams = {
      action: ''
    };

    // 匹配 action="value"
    const actionMatch = cleanString.match(/action="([^"]*)"/);
    if (actionMatch) {
      params.action = actionMatch[1];
    }

    // 匹配 text="value"
    const textMatch = cleanString.match(/text="([^"]*)"/);
    if (textMatch) {
      params.text = textMatch[1];
    }

    // 匹配 element=[...]
    const elementMatch = cleanString.match(/element=(\[.*?\])/);
    if (elementMatch) {
      try {
        params.element = JSON.parse(elementMatch[1]) as number[] | number[][];
      } catch (e) {
        hilog.error(0x0000, 'DeviceController', `解析 element 失败: ${elementMatch[1]}`);
      }
    }

    hilog.info(0x0000, 'DeviceController', `解析结果: ${JSON.stringify(params)}`);

    // 构建 Action 对象
    if (params.action) {
      const action: Action = {
        type: params.action as ActionType
      };

      if (params.element !== undefined) {
        action.element = params.element;
      }

      if (params.text !== undefined) {
        action.text = params.text;
      }

      return action;
    }

    hilog.warn(0x0000, 'DeviceController', '未找到有效的 action 参数');
    return null;
  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : String(error);
    hilog.error(0x0000, 'DeviceController', `解析动作失败: ${errorMsg}`);
    return null;
  }
}

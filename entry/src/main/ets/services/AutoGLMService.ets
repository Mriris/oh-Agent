import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

// 任务状态回调
export interface TaskCallback {
  onStarted?: () => void;
  onThinking?: (thinking: string) => void;
  onAction?: (action: string) => void;
  onCompleted?: (result: string, steps: number) => void;
  onFailed?: (error: string) => void;
}

// 配置接口
export interface ServiceConfig {
  serverUrl: string;
  deviceId: string;
}

// API 请求接口
interface AgentConfigData {
  device_id: string;
  device_type: string;  // "adb" or "hdc"
}

interface InitRequest {
  agent_config: AgentConfigData;
}

interface ChatRequest {
  message: string;
  device_id: string;
}

// API 响应接口
interface InitResponse {
  success: boolean;
  device_id: string;
  message: string;
}

interface ChatResponse {
  result: string;
  steps: number;
  success: boolean;
}

/**
 * AutoGLM 后端服务
 * 通过 HTTP REST API 与 AutoGLM-GUI 后端通信
 */
export class AutoGLMService {
  private serverUrl: string = '';
  private deviceId: string = '';
  private isInitialized: boolean = false;

  /**
   * 配置服务
   */
  configure(serverUrl: string, deviceId: string): void {
    this.serverUrl = serverUrl;
    this.deviceId = deviceId || 'default';
    this.isInitialized = false;
    hilog.info(0x0000, 'AutoGLM', `配置服务: ${serverUrl}, 设备: ${this.deviceId}`);
  }

  /**
   * 连接到后端（初始化 Agent）
   */
  async connect(): Promise<void> {
    if (this.isInitialized) {
      hilog.info(0x0000, 'AutoGLM', '已初始化');
      return;
    }

    return new Promise<void>((resolve, reject) => {
      try {
        const httpRequest = http.createHttp();

        // 构建初始化请求
        const agentConfig: AgentConfigData = {
          device_id: this.deviceId,
          device_type: 'hdc'  // 鸿蒙设备使用 HDC
        };

        const requestBody: InitRequest = {
          agent_config: agentConfig
        };

        const url = `${this.serverUrl}/api/init`;
        hilog.info(0x0000, 'AutoGLM', `初始化 Agent: ${url}`);

        httpRequest.request(
          url,
          {
            method: http.RequestMethod.POST,
            header: {
              'Content-Type': 'application/json'
            },
            extraData: requestBody,
            expectDataType: http.HttpDataType.STRING,
            connectTimeout: 30000,
            readTimeout: 30000
          },
          (err, data) => {
            if (!err) {
              try {
                hilog.info(0x0000, 'AutoGLM', `初始化响应状态码: ${data.responseCode}`);

                if (data.responseCode === 200) {
                  const result = JSON.parse(data.result as string) as InitResponse;
                  if (result.success) {
                    this.isInitialized = true;
                    hilog.info(0x0000, 'AutoGLM', `初始化成功: ${result.message}`);
                    resolve();
                  } else {
                    const errorMsg = `初始化失败: ${result.message}`;
                    hilog.error(0x0000, 'AutoGLM', errorMsg);
                    reject(new Error(errorMsg));
                  }
                } else {
                  const errorMsg = `初始化失败: HTTP ${data.responseCode} - ${data.result}`;
                  hilog.error(0x0000, 'AutoGLM', errorMsg);
                  reject(new Error(errorMsg));
                }
              } catch (parseError) {
                const parseErrorMsg = parseError instanceof Error ? parseError.message : String(parseError);
                hilog.error(0x0000, 'AutoGLM', `解析响应失败: ${parseErrorMsg}`);
                reject(new Error(`解析响应失败: ${parseErrorMsg}`));
              }
            } else {
              const errMsg = err.message || '未知错误';
              hilog.error(0x0000, 'AutoGLM', `初始化请求失败: ${errMsg}`);
              reject(new Error(`初始化请求失败: ${errMsg}`));
            }

            httpRequest.destroy();
          }
        );

      } catch (error) {
        const errorMsg = error instanceof Error ? error.message : String(error);
        hilog.error(0x0000, 'AutoGLM', `初始化异常: ${errorMsg}`);
        reject(new Error(errorMsg));
      }
    });
  }

  /**
   * 断开连接
   */
  disconnect(): void {
    this.isInitialized = false;
    hilog.info(0x0000, 'AutoGLM', '已断开连接');
  }

  /**
   * 执行任务
   */
  async executeTask(task: string, callback: TaskCallback): Promise<void> {
    if (!this.isInitialized) {
      throw new Error('未连接到后端，请先调用 connect()');
    }

    return new Promise<void>((resolve, reject) => {
      try {
        const httpRequest = http.createHttp();

        // 构建任务请求
        const requestBody: ChatRequest = {
          message: task,
          device_id: this.deviceId
        };

        const url = `${this.serverUrl}/api/chat`;
        hilog.info(0x0000, 'AutoGLM', `发送任务: ${task}`);

        // 通知任务开始
        if (callback.onStarted) {
          callback.onStarted();
        }

        httpRequest.request(
          url,
          {
            method: http.RequestMethod.POST,
            header: {
              'Content-Type': 'application/json'
            },
            extraData: requestBody,
            expectDataType: http.HttpDataType.STRING,
            connectTimeout: 120000, // 2分钟超时（任务可能需要较长时间）
            readTimeout: 120000
          },
          (err, data) => {
            if (!err) {
              try {
                hilog.info(0x0000, 'AutoGLM', `任务响应状态码: ${data.responseCode}`);

                if (data.responseCode === 200) {
                  const result = JSON.parse(data.result as string) as ChatResponse;

                  if (result.success) {
                    hilog.info(0x0000, 'AutoGLM', `任务完成: ${result.result}, 步骤: ${result.steps}`);
                    if (callback.onCompleted) {
                      callback.onCompleted(result.result, result.steps);
                    }
                    resolve();
                  } else {
                    hilog.error(0x0000, 'AutoGLM', `任务失败: ${result.result}`);
                    if (callback.onFailed) {
                      callback.onFailed(result.result);
                    }
                    reject(new Error(result.result));
                  }
                } else {
                  const errorMsg = `任务执行失败: HTTP ${data.responseCode} - ${data.result}`;
                  hilog.error(0x0000, 'AutoGLM', errorMsg);
                  if (callback.onFailed) {
                    callback.onFailed(errorMsg);
                  }
                  reject(new Error(errorMsg));
                }
              } catch (parseError) {
                const parseErrorMsg = parseError instanceof Error ? parseError.message : String(parseError);
                hilog.error(0x0000, 'AutoGLM', `解析响应失败: ${parseErrorMsg}`);
                if (callback.onFailed) {
                  callback.onFailed(`解析响应失败: ${parseErrorMsg}`);
                }
                reject(new Error(`解析响应失败: ${parseErrorMsg}`));
              }
            } else {
              const errMsg = err.message || '未知错误';
              hilog.error(0x0000, 'AutoGLM', `任务请求失败: ${errMsg}`);
              if (callback.onFailed) {
                callback.onFailed(`任务请求失败: ${errMsg}`);
              }
              reject(new Error(`任务请求失败: ${errMsg}`));
            }

            httpRequest.destroy();
          }
        );

      } catch (error) {
        const errorMsg = error instanceof Error ? error.message : String(error);
        hilog.error(0x0000, 'AutoGLM', `任务执行异常: ${errorMsg}`);
        if (callback.onFailed) {
          callback.onFailed(errorMsg);
        }
        reject(new Error(errorMsg));
      }
    });
  }

}

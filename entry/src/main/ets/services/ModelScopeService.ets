import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

// 图片 URL 接口
export interface ImageUrl {
  url: string;
}

// 消息内容接口
export interface MessageContent {
  type: 'text' | 'image_url';
  text?: string;
  image_url?: ImageUrl;
}

// AI 消息接口
export interface AIMessage {
  role: 'system' | 'user' | 'assistant';
  content: string | MessageContent[];
}

// AI 响应接口
export interface AIResponse {
  thinking?: string;
  action?: string;
}

// API 配置接口
interface APIConfig {
  baseUrl: string;
  model: string;
  apiKey: string;
}

// 请求体接口
interface RequestBody {
  model: string;
  messages: AIMessage[];
  temperature: number;
  max_tokens: number;
}

// API 响应接口
interface APIResponseData {
  choices: Array<{
    message: {
      content: string;
    };
  }>;
}

// ModelScope API 配置
const API_CONFIG: APIConfig = {
  baseUrl: 'https://api-inference.modelscope.cn/v1',
  model: 'ZhipuAI/AutoGLM-Phone-9B',
  apiKey: 'ms-d04dc764-ccf5-48ec-a161-b9d2d06d2c4a'
};

/**
 * ModelScope AI 服务
 * 调用 AutoGLM-Phone-9B 模型进行任务解析
 */
export class ModelScopeService {
  private messages: AIMessage[] = [];

  constructor() {
    // 初始化系统提示词
    this.messages.push({
      role: 'system',
      content: `你是一个手机控制助手。你需要理解用户的指令，并返回相应的操作动作。

支持的动作类型：
1. Tap - 点击屏幕坐标
   格式: do(action="Tap", element=[x, y])
   坐标范围: 0-1000 (归一化坐标)

2. Swipe - 滑动
   格式: do(action="Swipe", element=[[x1,y1], [x2,y2]])

3. Type - 输入文本
   格式: do(action="Type", text="要输入的内容")

4. Back - 返回
   格式: do(action="Back")

5. Home - 主页
   格式: do(action="Home")

6. Finish - 完成任务
   格式: finish(message="任务完成")

请根据用户指令返回合适的动作。先思考，再输出动作。`
    });
  }

  /**
   * 调用 AI 模型
   */
  async chat(userMessage: string, screenshot?: string): Promise<AIResponse> {
    try {
      // 构建用户消息
      const messageContent: MessageContent[] = [];

      // 添加文本
      const textContent: MessageContent = {
        type: 'text',
        text: userMessage
      };
      messageContent.push(textContent);

      // 如果有截图，添加图片
      if (screenshot) {
        const imageContent: MessageContent = {
          type: 'image_url',
          image_url: {
            url: `data:image/png;base64,${screenshot}`
          }
        };
        messageContent.push(imageContent);
      }

      this.messages.push({
        role: 'user',
        content: messageContent
      });

      hilog.info(0x0000, 'ModelScope', `发送请求到 AI，消息数: ${this.messages.length}`);

      // 调用 API
      const response = await this.callAPI();

      hilog.info(0x0000, 'ModelScope', `收到 AI 响应: ${response.substring(0, 100)}...`);

      // 解析响应
      const parsed = this.parseResponse(response);

      // 添加到对话历史
      this.messages.push({
        role: 'assistant',
        content: response
      });

      return parsed;
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      hilog.error(0x0000, 'ModelScope', `AI 调用失败: ${errorMsg}`);
      throw new Error(`AI 调用失败: ${errorMsg}`);
    }
  }

  /**
   * 调用 ModelScope API
   */
  private async callAPI(): Promise<string> {
    return new Promise<string>((resolve, reject) => {
      // 创建 HTTP 请求
      const httpRequest = http.createHttp();

      // 构建请求体
      const requestBody: RequestBody = {
        model: API_CONFIG.model,
        messages: this.messages,
        temperature: 0.7,
        max_tokens: 2000
      };

      hilog.info(0x0000, 'ModelScope', `请求 URL: ${API_CONFIG.baseUrl}/chat/completions`);

      // 发送请求
      httpRequest.request(
        `${API_CONFIG.baseUrl}/chat/completions`,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${API_CONFIG.apiKey}`
          },
          extraData: requestBody,
          expectDataType: http.HttpDataType.STRING,
          connectTimeout: 60000,
          readTimeout: 60000
        },
        (err, data) => {
          if (!err) {
            try {
              hilog.info(0x0000, 'ModelScope', `响应状态码: ${data.responseCode}`);

              if (data.responseCode === 200) {
                const result = JSON.parse(data.result as string) as APIResponseData;
                const content = result.choices[0].message.content;
                resolve(content);
              } else {
                const errorMsg = `API 返回错误: ${data.responseCode} - ${data.result}`;
                hilog.error(0x0000, 'ModelScope', errorMsg);
                reject(new Error(errorMsg));
              }
            } catch (parseError) {
              const parseErrorMsg = parseError instanceof Error ? parseError.message : String(parseError);
              hilog.error(0x0000, 'ModelScope', `解析响应失败: ${parseErrorMsg}`);
              reject(new Error(`解析响应失败: ${parseErrorMsg}`));
            }
          } else {
            const errMsg = err.message || '未知错误';
            hilog.error(0x0000, 'ModelScope', `请求失败: ${errMsg}`);
            reject(new Error(`请求失败: ${errMsg}`));
          }

          // 清理
          httpRequest.destroy();
        }
      );
    });
  }

  /**
   * 解析 AI 响应
   */
  private parseResponse(response: string): AIResponse {
    const result: AIResponse = {};

    // 提取 thinking
    const thinkingMatch = response.match(/^(.*?)(?=do\(|finish\()/s);
    if (thinkingMatch) {
      result.thinking = thinkingMatch[1].trim();
    }

    // 提取 action
    const actionMatch = response.match(/(do\(.*?\)|finish\(.*?\))/s);
    if (actionMatch) {
      result.action = actionMatch[1].trim();
    } else {
      // 如果没有找到标准格式，整个响应作为 thinking
      result.thinking = response;
    }

    const thinkingPreview = result.thinking ? result.thinking.substring(0, 50) : '';
    hilog.info(0x0000, 'ModelScope', `解析结果 - thinking: ${thinkingPreview}, action: ${result.action || '无'}`);

    return result;
  }

  /**
   * 重置对话
   */
  reset(): void {
    this.messages = this.messages.slice(0, 1); // 保留系统提示词
    hilog.info(0x0000, 'ModelScope', '对话已重置');
  }

  /**
   * 获取对话历史
   */
  getHistory(): AIMessage[] {
    return this.messages;
  }
}

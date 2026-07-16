import { BusinessError } from '@kit.BasicServicesKit';
import { connection } from '@kit.NetworkKit';

export class NetworkDiagnosticsResult {
  ok: boolean = false;
  netId: number = 0;
  interfaceName: string = '';
  ipv4Valid: boolean = false;
  ipv6Valid: boolean = false;
  dnsCount: number = 0;
  defaultRouteCount: number = 0;
  errorCode: number = 0;
  errorMessage: string = '';
  errorHint: string = '';
}

export class NetworkDiagnosticsService {
  private static instance: NetworkDiagnosticsService;

  private constructor() {}

  static getInstance(): NetworkDiagnosticsService {
    if (!NetworkDiagnosticsService.instance) {
      NetworkDiagnosticsService.instance = new NetworkDiagnosticsService();
    }
    return NetworkDiagnosticsService.instance;
  }

  async diagnose(): Promise<NetworkDiagnosticsResult> {
    const result: NetworkDiagnosticsResult = new NetworkDiagnosticsResult();
    try {
      const netHandle: connection.NetHandle = await connection.getDefaultNet();
      result.netId = netHandle.netId;
      if (netHandle.netId === 0) {
        result.ok = false;
        result.errorMessage = 'No default network';
        result.errorHint = '当前没有可用默认网络';
        return result;
      }

      const properties: connection.ConnectionProperties =
        await connection.getConnectionProperties(netHandle);
      result.interfaceName = properties.interfaceName;
      result.ipv4Valid = properties.isIPv4LinkValid === true;
      result.ipv6Valid = properties.isIPv6LinkValid === true;
      result.dnsCount = properties.dnses ? properties.dnses.length : 0;

      let defaultRoutes: number = 0;
      if (properties.routes) {
        for (let i = 0; i < properties.routes.length; i++) {
          if (properties.routes[i].isDefaultRoute === true) {
            defaultRoutes++;
          }
        }
      }
      result.defaultRouteCount = defaultRoutes;
      result.ok = result.ipv4Valid || result.ipv6Valid || defaultRoutes > 0;
      return result;
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      result.ok = false;
      result.errorCode = error.code || 0;
      result.errorMessage = error.message || JSON.stringify(err);
      result.errorHint = this.explainError(result.errorCode);
      return result;
    }
  }

  explainError(code: number): string {
    if (code === 201) {
      return '权限不足，请确认已声明 GET_NETWORK_INFO';
    }
    if (code === 2100002) {
      return '连接网络系统服务失败';
    }
    if (code === 2100003) {
      return '系统网络服务内部错误';
    }
    if (code === 2101022) {
      return '网络监听请求数过多';
    }
    if (code === 0) {
      return '';
    }
    return '网络连接管理错误码 ' + code.toString();
  }
}

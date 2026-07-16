import { preferences } from '@kit.ArkData';

export interface LoginResult {
  success: boolean;
  message: string;
}

export interface User {
  account: string;
  passwordHash: string;
  salt: string;
}

const AUTH_STORE_NAME: string = 'auth_store';
const KEY_ACCOUNT: string = 'account';
const KEY_TOKEN: string = 'token';
const KEY_REMEMBER: string = 'remember_account';
const KEY_SAVED_ACCOUNT: string = 'saved_account';
const TOKEN_EXPIRY_MS: number = 24 * 60 * 60 * 1000;

export class AuthManager {
  private static instance: AuthManager;
  private store: preferences.Preferences | null = null;
  private initialized: boolean = false;

  private constructor() {}

  static getInstance(): AuthManager {
    if (!AuthManager.instance) {
      AuthManager.instance = new AuthManager();
    }
    return AuthManager.instance;
  }

  async init(context: Context): Promise<void> {
    if (this.initialized) {
      return;
    }
    try {
      this.store = await preferences.getPreferences(context, AUTH_STORE_NAME);
      this.initialized = true;
    } catch (err) {
      console.error('Failed to init auth store:', err.message);
    }
  }

  private generateSalt(): string {
    const chars: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    let salt: string = '';
    for (let i = 0; i < 16; i++) {
      salt += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return salt;
  }

  private hashPassword(password: string, salt: string): string {
    const data: string = salt + ':' + password;
    let hash: number = 0;
    for (let i = 0; i < data.length; i++) {
      const char: number = data.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash;
    }
    const hashStr: string = Math.abs(hash).toString(16).padStart(8, '0');
    let result: string = '';
    for (let i = 0; i < data.length; i++) {
      const code: number = data.charCodeAt(i) ^ hashStr.charCodeAt(i % hashStr.length);
      result += code.toString(16).padStart(2, '0');
    }
    return result;
  }

  private encodeBase64(data: string): string {
    const chars: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    let result: string = '';
    let i: number = 0;
    while (i < data.length) {
      const a: number = data.charCodeAt(i++);
      const b: number = i < data.length ? data.charCodeAt(i++) : 0;
      const c: number = i < data.length ? data.charCodeAt(i++) : 0;
      const bitmap: number = (a << 16) | (b << 8) | c;
      result += chars.charAt((bitmap >> 18) & 63);
      result += chars.charAt((bitmap >> 12) & 63);
      result += i - 2 < data.length ? chars.charAt((bitmap >> 6) & 63) : '=';
      result += i - 1 < data.length ? chars.charAt(bitmap & 63) : '=';
    }
    return result;
  }

  private decodeBase64(encoded: string): string {
    const chars: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    let result: string = '';
    let i: number = 0;
    while (i < encoded.length) {
      const a: number = chars.indexOf(encoded.charAt(i++));
      const b: number = chars.indexOf(encoded.charAt(i++));
      const c: number = chars.indexOf(encoded.charAt(i++));
      const d: number = chars.indexOf(encoded.charAt(i++));
      const bitmap: number = (a << 18) | (b << 12) | (c << 6) | d;
      result += String.fromCharCode((bitmap >> 16) & 255);
      if (c !== 64) {
        result += String.fromCharCode((bitmap >> 8) & 255);
      }
      if (d !== 64) {
        result += String.fromCharCode(bitmap & 255);
      }
    }
    return result;
  }

  async login(account: string, password: string): Promise<LoginResult> {
    if (!this.store) {
      const failResult: LoginResult = { success: false, message: '存储未初始化' };
      return failResult;
    }

    try {
      const savedUser = await this.store.get('user', '') as string;
      if (savedUser.length > 0) {
        const user: User = JSON.parse(savedUser) as User;
        const passwordHash: string = this.hashPassword(password, user.salt);
        if (user.account === account && user.passwordHash === passwordHash) {
          const tokenData: string = account + '_' + Date.now() + '_' + (Date.now() + TOKEN_EXPIRY_MS);
          const token: string = this.encodeBase64(tokenData);
          await this.store.put(KEY_ACCOUNT, this.encodeBase64(account));
          await this.store.put(KEY_TOKEN, token);
          await this.store.flush();
          const successResult: LoginResult = { success: true, message: '登录成功' };
          return successResult;
        }
      }

      const errorResult: LoginResult = { success: false, message: '账号或密码错误，请重新输入' };
      return errorResult;
    } catch (err) {
      console.error('Login failed:', err.message);
      const catchResult: LoginResult = { success: false, message: '登录失败，请重试' };
      return catchResult;
    }
  }

  async logout(): Promise<void> {
    if (!this.store) return;
    try {
      await this.store.delete(KEY_ACCOUNT);
      await this.store.delete(KEY_TOKEN);
      await this.store.flush();
    } catch (err) {
      console.error('Logout failed:', err.message);
    }
  }

  async isLoggedIn(): Promise<boolean> {
    if (!this.store) return false;
    try {
      const token = await this.store.get(KEY_TOKEN, '') as string;
      if (token.length === 0) return false;
      const tokenData: string = this.decodeBase64(token);
      if (tokenData.length === 0) return false;
      const parts: string[] = tokenData.split('_');
      if (parts.length < 3) return false;
      const expiry: number = parseInt(parts[2]);
      if (Date.now() > expiry) {
        await this.logout();
        return false;
      }
      return true;
    } catch (err) {
      return false;
    }
  }

  async getAccount(): Promise<string> {
    if (!this.store) return '';
    try {
      const encoded = await this.store.get(KEY_ACCOUNT, '') as string;
      if (encoded.length === 0) return '';
      return this.decodeBase64(encoded);
    } catch (err) {
      return '';
    }
  }

  async setRememberAccount(remember: boolean): Promise<void> {
    if (!this.store) return;
    try {
      await this.store.put(KEY_REMEMBER, remember ? '1' : '0');
      await this.store.flush();
    } catch (err) {
      console.error('Failed to set remember:', err.message);
    }
  }

  async getRememberAccount(): Promise<boolean> {
    if (!this.store) return false;
    try {
      const val = await this.store.get(KEY_REMEMBER, '0') as string;
      return val === '1';
    } catch (err) {
      return false;
    }
  }

  async saveAccount(account: string): Promise<void> {
    if (!this.store) return;
    try {
      await this.store.put(KEY_SAVED_ACCOUNT, this.encodeBase64(account));
      await this.store.flush();
    } catch (err) {
      console.error('Failed to save account:', err.message);
    }
  }

  async getSavedAccount(): Promise<string> {
    if (!this.store) return '';
    try {
      const encoded = await this.store.get(KEY_SAVED_ACCOUNT, '') as string;
      if (encoded.length === 0) return '';
      return this.decodeBase64(encoded);
    } catch (err) {
      return '';
    }
  }

  async register(account: string, password: string): Promise<LoginResult> {
    if (!this.store) {
      const failResult: LoginResult = { success: false, message: '存储未初始化' };
      return failResult;
    }

    try {
      const existingUser = await this.store.get('user', '') as string;
      if (existingUser.length > 0) {
        const user: User = JSON.parse(existingUser) as User;
        if (user.account === account) {
          const existResult: LoginResult = { success: false, message: '该账号已存在' };
          return existResult;
        }
      }

      const salt: string = this.generateSalt();
      const passwordHash: string = this.hashPassword(password, salt);
      const newUser: User = { account: account, passwordHash: passwordHash, salt: salt };
      await this.store.put('user', JSON.stringify(newUser));
      await this.store.flush();
      const successResult: LoginResult = { success: true, message: '注册成功' };
      return successResult;
    } catch (err) {
      console.error('Register failed:', err.message);
      const catchResult: LoginResult = { success: false, message: '注册失败，请重试' };
      return catchResult;
    }
  }

  async resetPassword(account: string, newPassword: string): Promise<LoginResult> {
    if (!this.store) {
      const failResult: LoginResult = { success: false, message: '存储未初始化' };
      return failResult;
    }
    try {
      const existingUser = await this.store.get('user', '') as string;
      if (existingUser.length === 0) {
        const notFoundResult: LoginResult = { success: false, message: '账号不存在' };
        return notFoundResult;
      }
      const user: User = JSON.parse(existingUser) as User;
      if (user.account !== account) {
        const mismatchResult: LoginResult = { success: false, message: '账号不匹配' };
        return mismatchResult;
      }
      const salt: string = this.generateSalt();
      const passwordHash: string = this.hashPassword(newPassword, salt);
      user.passwordHash = passwordHash;
      user.salt = salt;
      await this.store.put('user', JSON.stringify(user));
      await this.store.flush();
      const successResult: LoginResult = { success: true, message: '密码重置成功' };
      return successResult;
    } catch (err) {
      console.error('Reset password failed:', err.message);
      const catchResult: LoginResult = { success: false, message: '密码重置失败，请重试' };
      return catchResult;
    }
  }
}

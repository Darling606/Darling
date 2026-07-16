import http from '@ohos.net.http';
import { AdoptApplication, AdoptPet, BehaviorRecord, FeedPlan, HealthRecord, PetProfile } from '../model/PetModels';
import { CalendarEvent } from '../model/CalendarModels';
import { BackendConfig } from '../model/BackendConfig';
import { NetworkDiagnosticsResult, NetworkDiagnosticsService } from './NetworkDiagnosticsService';

const DEFAULT_BACKEND_URL: string = BackendConfig.BASE_URL;

interface SyncPetsPayload {
  userId: string;
  pets: PetProfile[];
}

interface PullPetsPayload {
  userId: string;
}

interface DeletePetPayload {
  userId: string;
  updatedAt: number;
}

interface SyncPetsResponse {
  success: boolean;
  message?: string;
  userId?: string;
  pets?: PetProfile[];
  serverTime?: number;
}

interface SyncDebugResponse {
  success: boolean;
  userId?: string;
  petCount?: number;
  activePetCount?: number;
  deletedPetCount?: number;
  updatedAt?: number;
  message?: string;
}

export type SyncCollectionName =
  'healthRecords' | 'feedPlans' | 'behaviorRecords' | 'applications' | 'adoptPets' | 'calendarEvents';

type SyncCollectionItem =
  HealthRecord | FeedPlan | BehaviorRecord | AdoptApplication | AdoptPet | CalendarEvent;

interface SyncCollectionPayload<T extends SyncCollectionItem> {
  userId: string;
  items: T[];
}

interface PullCollectionPayload {
  userId: string;
}

interface SyncCollectionResponse<T extends SyncCollectionItem> {
  success: boolean;
  message?: string;
  userId?: string;
  collection?: string;
  items?: T[];
  serverTime?: number;
}

export class CloudSyncStatus {
  backendUrl: string = DEFAULT_BACKEND_URL;
  userId: string = '';
  lastAction: string = '';
  lastSyncTime: string = '';
  localCount: number = 0;
  remoteCount: number = -1;
  mergedCount: number = 0;
  netId: number = 0;
  interfaceName: string = '';
  ipv4Valid: boolean = false;
  ipv6Valid: boolean = false;
  lastError: string = '';
}

export class CloudSyncService {
  private static instance: CloudSyncService;
  private apiBaseUrl: string = DEFAULT_BACKEND_URL;
  private status: CloudSyncStatus = new CloudSyncStatus();
  private networkDiagnostics: NetworkDiagnosticsService = NetworkDiagnosticsService.getInstance();

  private constructor() {}

  static getInstance(): CloudSyncService {
    if (!CloudSyncService.instance) {
      CloudSyncService.instance = new CloudSyncService();
    }
    return CloudSyncService.instance;
  }

  init(baseUrl: string): void {
    if (baseUrl.length > 0) {
      this.apiBaseUrl = baseUrl;
      this.status.backendUrl = baseUrl;
    }
  }

  getBaseUrl(): string {
    return this.apiBaseUrl;
  }

  getStatus(): CloudSyncStatus {
    return this.status;
  }

  normalizeLocalPets(pets: PetProfile[]): PetProfile[] {
    let changed: boolean = false;
    const now: number = Date.now();
    const result: PetProfile[] = [];
    for (let i = 0; i < pets.length; i++) {
      const pet: PetProfile = pets[i];
      if (pet.updatedAt <= 0) {
        pet.updatedAt = now + i;
        changed = true;
      }
      pet.deleted = pet.deleted === true;
      result.push(pet);
    }
    if (changed) {
      console.log('CloudSync: normalized local pets updatedAt count=' + result.length.toString());
    }
    return result;
  }

  normalizeLocalItems<T extends SyncCollectionItem>(items: T[]): T[] {
    let changed: boolean = false;
    const now: number = Date.now();
    const result: T[] = [];
    for (let i = 0; i < items.length; i++) {
      const item: T = items[i];
      if (item.updatedAt <= 0) {
        item.updatedAt = now + i;
        changed = true;
      }
      item.deleted = item.deleted === true;
      result.push(item);
    }
    if (changed) {
      console.log('CloudSync: normalized collection items count=' + result.length.toString());
    }
    return result;
  }

  async pushPets(userId: string, pets: PetProfile[]): Promise<boolean> {
    if (userId.length === 0) {
      return false;
    }
    this.prepareStatus(userId, 'push', pets.length);
    try {
      await this.updateNetworkStatus();
      const request = http.createHttp();
      const payload: SyncPetsPayload = {
        userId: userId,
        pets: this.normalizeLocalPets(pets)
      };
      const response: http.HttpResponse = await request.request(
        this.apiBaseUrl + '/api/v1/sync/pets/push',
        {
          method: http.RequestMethod.POST,
          header: { 'Content-Type': 'application/json' },
          extraData: JSON.stringify(payload),
          connectTimeout: 5000,
          readTimeout: 8000
        }
      );
      if (response.responseCode !== 200) {
        this.setError('push response=' + response.responseCode.toString());
        return false;
      }
      const data = JSON.parse(response.result.toString()) as SyncPetsResponse;
      this.status.lastSyncTime = this.formatTime();
      this.status.lastError = data.success === true ? '' : (data.message || 'push failed');
      this.status.remoteCount = data.pets ? data.pets.length : this.status.remoteCount;
      console.log('CloudSync: pushPets url=' + this.apiBaseUrl + ' user=' + userId +
        ' success=' + data.success.toString() + ' local=' + pets.length.toString() +
        ' remote=' + this.status.remoteCount.toString());
      return data.success === true;
    } catch (err) {
      this.setError('push error=' + JSON.stringify(err));
      return false;
    }
  }

  async pullPets(userId: string, localPets: PetProfile[]): Promise<PetProfile[]> {
    if (userId.length === 0) {
      return localPets;
    }
    this.prepareStatus(userId, 'pull', localPets.length);
    try {
      await this.updateNetworkStatus();
      const request = http.createHttp();
      const payload: PullPetsPayload = { userId: userId };
      const response: http.HttpResponse = await request.request(
        this.apiBaseUrl + '/api/v1/sync/pets/pull',
        {
          method: http.RequestMethod.POST,
          header: { 'Content-Type': 'application/json' },
          extraData: JSON.stringify(payload),
          connectTimeout: 5000,
          readTimeout: 8000
        }
      );
      if (response.responseCode !== 200) {
        this.setError('pull response=' + response.responseCode.toString());
        return localPets;
      }
      const data = JSON.parse(response.result.toString()) as SyncPetsResponse;
      if (data.success !== true || !data.pets) {
        this.setError('pull failed=' + (data.message || 'unknown'));
        return localPets;
      }
      const merged: PetProfile[] = this.mergePets(localPets, data.pets);
      this.status.remoteCount = data.pets.length;
      this.status.mergedCount = merged.length;
      this.status.lastSyncTime = this.formatTime();
      this.status.lastError = '';
      console.log('CloudSync: pullPets url=' + this.apiBaseUrl + ' user=' + userId +
        ' remote=' + data.pets.length.toString() + ' merged=' + merged.length.toString());
      return merged;
    } catch (err) {
      this.setError('pull error=' + JSON.stringify(err));
      return localPets;
    }
  }

  async syncPets(userId: string, localPets: PetProfile[]): Promise<PetProfile[]> {
    const normalized: PetProfile[] = this.normalizeLocalPets(localPets);
    const pulled: PetProfile[] = await this.pullPets(userId, normalized);
    await this.pushPets(userId, pulled);
    return pulled;
  }

  async pullCollection<T extends SyncCollectionItem>(
    userId: string,
    collection: SyncCollectionName,
    localItems: T[]
  ): Promise<T[]> {
    if (userId.length === 0) {
      return localItems;
    }
    this.prepareStatus(userId, 'pull ' + collection, localItems.length);
    try {
      await this.updateNetworkStatus();
      const request = http.createHttp();
      const payload: PullCollectionPayload = { userId: userId };
      const response: http.HttpResponse = await request.request(
        this.apiBaseUrl + '/api/v1/sync/' + collection + '/pull',
        {
          method: http.RequestMethod.POST,
          header: { 'Content-Type': 'application/json' },
          extraData: JSON.stringify(payload),
          connectTimeout: 5000,
          readTimeout: 8000
        }
      );
      if (response.responseCode !== 200) {
        this.setError(collection + ' pull response=' + response.responseCode.toString());
        return localItems;
      }
      const data = JSON.parse(response.result.toString()) as SyncCollectionResponse<T>;
      if (data.success !== true || !data.items) {
        this.setError(collection + ' pull failed=' + (data.message || 'unknown'));
        return localItems;
      }
      const merged: T[] = this.mergeItems(localItems, data.items);
      this.status.remoteCount = data.items.length;
      this.status.mergedCount = merged.length;
      this.status.lastSyncTime = this.formatTime();
      this.status.lastError = '';
      console.log('CloudSync: pull collection=' + collection + ' remote=' + data.items.length.toString() +
        ' merged=' + merged.length.toString());
      return merged;
    } catch (err) {
      this.setError(collection + ' pull error=' + JSON.stringify(err));
      return localItems;
    }
  }

  async pushCollection<T extends SyncCollectionItem>(
    userId: string,
    collection: SyncCollectionName,
    items: T[]
  ): Promise<boolean> {
    if (userId.length === 0) {
      return false;
    }
    this.prepareStatus(userId, 'push ' + collection, items.length);
    try {
      await this.updateNetworkStatus();
      const request = http.createHttp();
      const payload: SyncCollectionPayload<T> = {
        userId: userId,
        items: this.normalizeLocalItems(items)
      };
      const response: http.HttpResponse = await request.request(
        this.apiBaseUrl + '/api/v1/sync/' + collection + '/push',
        {
          method: http.RequestMethod.POST,
          header: { 'Content-Type': 'application/json' },
          extraData: JSON.stringify(payload),
          connectTimeout: 5000,
          readTimeout: 8000
        }
      );
      if (response.responseCode !== 200) {
        this.setError(collection + ' push response=' + response.responseCode.toString());
        return false;
      }
      const data = JSON.parse(response.result.toString()) as SyncCollectionResponse<T>;
      this.status.lastSyncTime = this.formatTime();
      this.status.lastError = data.success === true ? '' : (data.message || collection + ' push failed');
      this.status.remoteCount = data.items ? data.items.length : this.status.remoteCount;
      console.log('CloudSync: push collection=' + collection + ' success=' + data.success.toString() +
        ' local=' + items.length.toString() + ' remote=' + this.status.remoteCount.toString());
      return data.success === true;
    } catch (err) {
      this.setError(collection + ' push error=' + JSON.stringify(err));
      return false;
    }
  }

  async syncCollection<T extends SyncCollectionItem>(
    userId: string,
    collection: SyncCollectionName,
    localItems: T[]
  ): Promise<T[]> {
    const normalized: T[] = this.normalizeLocalItems(localItems);
    const pulled: T[] = await this.pullCollection(userId, collection, normalized);
    await this.pushCollection(userId, collection, pulled);
    return pulled;
  }

  async deleteCollectionItem(userId: string, collection: SyncCollectionName, itemId: string, updatedAt: number): Promise<boolean> {
    if (userId.length === 0 || itemId.length === 0) {
      return false;
    }
    this.prepareStatus(userId, 'delete ' + collection, 0);
    try {
      await this.updateNetworkStatus();
      const request = http.createHttp();
      const payload: DeletePetPayload = {
        userId: userId,
        updatedAt: updatedAt
      };
      const response: http.HttpResponse = await request.request(
        this.apiBaseUrl + '/api/v1/sync/' + collection + '/' + encodeURIComponent(itemId),
        {
          method: http.RequestMethod.DELETE,
          header: { 'Content-Type': 'application/json' },
          extraData: JSON.stringify(payload),
          connectTimeout: 5000,
          readTimeout: 8000
        }
      );
      if (response.responseCode !== 200) {
        this.setError(collection + ' delete response=' + response.responseCode.toString());
        return false;
      }
      const data = JSON.parse(response.result.toString()) as SyncCollectionResponse<SyncCollectionItem>;
      this.status.remoteCount = data.items ? data.items.length : this.status.remoteCount;
      this.status.lastSyncTime = this.formatTime();
      this.status.lastError = data.success === true ? '' : (data.message || collection + ' delete failed');
      return data.success === true;
    } catch (err) {
      this.setError(collection + ' delete error=' + JSON.stringify(err));
      return false;
    }
  }

  async deletePet(userId: string, petId: string, updatedAt: number): Promise<boolean> {
    if (userId.length === 0 || petId.length === 0) {
      return false;
    }
    this.prepareStatus(userId, 'delete', 0);
    try {
      await this.updateNetworkStatus();
      const request = http.createHttp();
      const payload: DeletePetPayload = {
        userId: userId,
        updatedAt: updatedAt
      };
      const response: http.HttpResponse = await request.request(
        this.apiBaseUrl + '/api/v1/sync/pets/' + encodeURIComponent(petId),
        {
          method: http.RequestMethod.DELETE,
          header: { 'Content-Type': 'application/json' },
          extraData: JSON.stringify(payload),
          connectTimeout: 5000,
          readTimeout: 8000
        }
      );
      if (response.responseCode !== 200) {
        this.setError('delete response=' + response.responseCode.toString());
        return false;
      }
      const data = JSON.parse(response.result.toString()) as SyncPetsResponse;
      this.status.remoteCount = data.pets ? data.pets.length : this.status.remoteCount;
      this.status.lastSyncTime = this.formatTime();
      this.status.lastError = data.success === true ? '' : (data.message || 'delete failed');
      console.log('CloudSync: deletePet url=' + this.apiBaseUrl + ' user=' + userId +
        ' success=' + data.success.toString() + ' petId=' + petId);
      return data.success === true;
    } catch (err) {
      this.setError('delete error=' + JSON.stringify(err));
      return false;
    }
  }

  async fetchDebug(userId: string): Promise<boolean> {
    if (userId.length === 0) {
      return false;
    }
    this.prepareStatus(userId, 'debug', this.status.localCount);
    try {
      await this.updateNetworkStatus();
      const request = http.createHttp();
      const response: http.HttpResponse = await request.request(
        this.apiBaseUrl + '/api/v1/sync/debug?userId=' + encodeURIComponent(userId),
        {
          method: http.RequestMethod.GET,
          connectTimeout: 5000,
          readTimeout: 8000
        }
      );
      if (response.responseCode !== 200) {
        this.setError('debug response=' + response.responseCode.toString());
        return false;
      }
      const data = JSON.parse(response.result.toString()) as SyncDebugResponse;
      this.status.remoteCount = data.activePetCount || 0;
      this.status.lastSyncTime = this.formatTime();
      this.status.lastError = data.success === true ? '' : (data.message || 'debug failed');
      return data.success === true;
    } catch (err) {
      this.setError('debug error=' + JSON.stringify(err));
      return false;
    }
  }

  private mergePets(localPets: PetProfile[], remotePets: PetProfile[]): PetProfile[] {
    const map: Map<string, PetProfile> = new Map<string, PetProfile>();
    for (let i = 0; i < localPets.length; i++) {
      const pet: PetProfile = localPets[i];
      if (pet.id.length > 0) {
        map.set(pet.id, pet);
      }
    }
    for (let i = 0; i < remotePets.length; i++) {
      const pet: PetProfile = remotePets[i];
      if (!pet || pet.id.length === 0) {
        continue;
      }
      const local: PetProfile | undefined = map.get(pet.id);
      if (!local || this.timeOf(pet) >= this.timeOf(local)) {
        map.set(pet.id, pet);
      }
    }

    const merged: PetProfile[] = [];
    map.forEach((pet: PetProfile) => {
      if (pet.deleted !== true) {
        merged.push(pet);
      }
    });
    merged.sort((a: PetProfile, b: PetProfile) => this.timeOf(a) - this.timeOf(b));
    return merged;
  }

  private timeOf(pet: PetProfile): number {
    return pet.updatedAt > 0 ? pet.updatedAt : 0;
  }

  private mergeItems<T extends SyncCollectionItem>(localItems: T[], remoteItems: T[]): T[] {
    const map: Map<string, T> = new Map<string, T>();
    for (let i = 0; i < localItems.length; i++) {
      const item: T = localItems[i];
      if (item.id.length > 0) {
        map.set(item.id, item);
      }
    }
    for (let i = 0; i < remoteItems.length; i++) {
      const item: T = remoteItems[i];
      if (!item || item.id.length === 0) {
        continue;
      }
      const local: T | undefined = map.get(item.id);
      if (!local || this.timeOfItem(item) >= this.timeOfItem(local)) {
        map.set(item.id, item);
      }
    }

    const merged: T[] = [];
    map.forEach((item: T) => {
      if (item.deleted !== true) {
        merged.push(item);
      }
    });
    merged.sort((a: T, b: T) => this.timeOfItem(a) - this.timeOfItem(b));
    return merged;
  }

  private timeOfItem(item: SyncCollectionItem): number {
    return item.updatedAt > 0 ? item.updatedAt : 0;
  }

  private prepareStatus(userId: string, action: string, localCount: number): void {
    this.status.backendUrl = this.apiBaseUrl;
    this.status.userId = userId;
    this.status.lastAction = action;
    this.status.localCount = localCount;
  }

  private setError(message: string): void {
    this.status.lastError = message;
    console.error('CloudSync: ' + message);
  }

  private async updateNetworkStatus(): Promise<void> {
    const result: NetworkDiagnosticsResult = await this.networkDiagnostics.diagnose();
    this.status.netId = result.netId;
    this.status.interfaceName = result.interfaceName;
    this.status.ipv4Valid = result.ipv4Valid;
    this.status.ipv6Valid = result.ipv6Valid;
    if (!result.ok && result.errorHint.length > 0) {
      this.status.lastError = result.errorHint + ' ' + result.errorMessage;
    }
  }

  private formatTime(): string {
    const d: Date = new Date();
    return d.getHours().toString().padStart(2, '0') + ':' +
      d.getMinutes().toString().padStart(2, '0') + ':' +
      d.getSeconds().toString().padStart(2, '0');
  }
}

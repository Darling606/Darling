import { preferences } from '@kit.ArkData';
import { PetProfile, HealthRecord, FeedPlan, BehaviorRecord, AdoptApplication, AdoptPet } from './PetModels';

const STORE_NAME: string = 'PetManagerStore';

export class StorageManager {
  private static instance: StorageManager;
  private store: preferences.Preferences | null = null;
  private initialized: boolean = false;

  private constructor() {}

  static getInstance(): StorageManager {
    if (!StorageManager.instance) {
      StorageManager.instance = new StorageManager();
    }
    return StorageManager.instance;
  }

  async init(context: Context): Promise<void> {
    if (this.initialized) {
      return;
    }
    try {
      this.store = await preferences.getPreferences(context, STORE_NAME);
      this.initialized = true;
    } catch (err) {
      console.error('Failed to init storage:', err.message);
    }
  }

  isReady(): boolean {
    return this.initialized && this.store !== null;
  }

  async savePetList(list: PetProfile[]): Promise<void> {
    if (!this.store) return;
    try {
      await this.store.put('pet_list', JSON.stringify(list));
      await this.store.flush();
    } catch (err) {
      console.error('Failed to save pet_list:', err.message);
    }
  }

  async getPetList(): Promise<PetProfile[]> {
    if (!this.store) return [];
    try {
      const value = await this.store.get('pet_list', '[]') as string;
      return JSON.parse(value) as PetProfile[];
    } catch (err) {
      console.error('Failed to load pet_list:', err.message);
      return [];
    }
  }

  async saveHealthRecords(list: HealthRecord[]): Promise<void> {
    if (!this.store) return;
    try {
      await this.store.put('health_records', JSON.stringify(list));
      await this.store.flush();
    } catch (err) {
      console.error('Failed to save health_records:', err.message);
    }
  }

  async getHealthRecords(): Promise<HealthRecord[]> {
    if (!this.store) return [];
    try {
      const value = await this.store.get('health_records', '[]') as string;
      return JSON.parse(value) as HealthRecord[];
    } catch (err) {
      console.error('Failed to load health_records:', err.message);
      return [];
    }
  }

  async saveFeedPlans(list: FeedPlan[]): Promise<void> {
    if (!this.store) return;
    try {
      await this.store.put('feed_plans', JSON.stringify(list));
      await this.store.flush();
    } catch (err) {
      console.error('Failed to save feed_plans:', err.message);
    }
  }

  async getFeedPlans(): Promise<FeedPlan[]> {
    if (!this.store) return [];
    try {
      const value = await this.store.get('feed_plans', '[]') as string;
      return JSON.parse(value) as FeedPlan[];
    } catch (err) {
      console.error('Failed to load feed_plans:', err.message);
      return [];
    }
  }

  async saveBehaviorRecords(list: BehaviorRecord[]): Promise<void> {
    if (!this.store) return;
    try {
      await this.store.put('behavior_records', JSON.stringify(list));
      await this.store.flush();
    } catch (err) {
      console.error('Failed to save behavior_records:', err.message);
    }
  }

  async getBehaviorRecords(): Promise<BehaviorRecord[]> {
    if (!this.store) return [];
    try {
      const value = await this.store.get('behavior_records', '[]') as string;
      return JSON.parse(value) as BehaviorRecord[];
    } catch (err) {
      console.error('Failed to load behavior_records:', err.message);
      return [];
    }
  }

  async saveApplications(list: AdoptApplication[]): Promise<void> {
    if (!this.store) return;
    try {
      await this.store.put('applications', JSON.stringify(list));
      await this.store.flush();
    } catch (err) {
      console.error('Failed to save applications:', err.message);
    }
  }

  async getApplications(): Promise<AdoptApplication[]> {
    if (!this.store) return [];
    try {
      const value = await this.store.get('applications', '[]') as string;
      return JSON.parse(value) as AdoptApplication[];
    } catch (err) {
      console.error('Failed to load applications:', err.message);
      return [];
    }
  }

  async saveAdoptPets(list: AdoptPet[]): Promise<void> {
    if (!this.store) return;
    try {
      await this.store.put('adopt_pets', JSON.stringify(list));
      await this.store.flush();
    } catch (err) {
      console.error('Failed to save adopt_pets:', err.message);
    }
  }

  async getAdoptPets(): Promise<AdoptPet[]> {
    if (!this.store) return [];
    try {
      const value = await this.store.get('adopt_pets', '[]') as string;
      return JSON.parse(value) as AdoptPet[];
    } catch (err) {
      console.error('Failed to load adopt_pets:', err.message);
      return [];
    }
  }
}

import { distributedKVStore } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  WatchAck,
  WatchBehaviorAlert,
  WatchCalendarEvent,
  WatchFeedReminder,
  WatchHealthRecord,
  WatchLocationInfo,
  WatchPetInfo,
  WatchSyncSnapshot
} from './WatchDataModels';

const TAG: string = 'DistributedDataManager';
const DOMAIN: number = 0x0000;

const STORE_ID: string = 'pet_watch_store';
const KEY_PET_INFO: string = 'pet_info_';
const KEY_HEALTH_RECORD: string = 'pet_health_';
const KEY_FEED_REMINDER: string = 'pet_feed_';
const KEY_BEHAVIOR_ALERT: string = 'pet_alert_';
const KEY_LOCATION: string = 'pet_location_';
const KEY_CALENDAR_EVENT: string = 'pet_calendar_event_';
const KEY_WATCH_ACK: string = 'pet_watch_ack_';
const KEY_SYNC_SNAPSHOT: string = 'pet_sync_snapshot';

export class DistributedDataManager {
  private kvStore: distributedKVStore.DeviceKVStore | null = null;
  private kvManager: distributedKVStore.KVManager | null = null;
  private static instance: DistributedDataManager;
  private isInitialized: boolean = false;

  onPetInfoChanged: ((pet: WatchPetInfo) => void) | null = null;
  onPetDeleted: ((petId: string) => void) | null = null;
  onHealthRecordChanged: ((record: WatchHealthRecord) => void) | null = null;
  onFeedReminderChanged: ((reminder: WatchFeedReminder) => void) | null = null;
  onBehaviorAlertChanged: ((alert: WatchBehaviorAlert) => void) | null = null;
  onLocationChanged: ((location: WatchLocationInfo) => void) | null = null;
  onCalendarEventChanged: ((event: WatchCalendarEvent) => void) | null = null;
  onSnapshotChanged: ((snapshot: WatchSyncSnapshot) => void) | null = null;

  static getInstance(): DistributedDataManager {
    if (!DistributedDataManager.instance) {
      DistributedDataManager.instance = new DistributedDataManager();
    }
    return DistributedDataManager.instance;
  }

  async initStore(context: Context): Promise<void> {
    if (this.isInitialized) {
      return;
    }

    try {
      this.kvManager = await distributedKVStore.createKVManager({
        bundleName: 'com.example.petsystem4_20_2',
        context: context
      });

      this.kvStore = await this.kvManager.getKVStore(STORE_ID, {
        kvStoreType: distributedKVStore.KVStoreType.DEVICE_COLLABORATION,
        securityLevel: distributedKVStore.SecurityLevel.S1,
        autoSync: true
      }) as distributedKVStore.DeviceKVStore;

      this.kvStore.on('dataChange', distributedKVStore.SubscribeType.SUBSCRIBE_TYPE_ALL,
        (changeInfo: distributedKVStore.ChangeNotification) => {
          this.handleDataChange(changeInfo);
        });

      this.isInitialized = true;
      hilog.info(DOMAIN, TAG, 'Initialized successfully');
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to init: %{public}s', JSON.stringify(err as object));
    }
  }

  private handleDataChange(changeInfo: distributedKVStore.ChangeNotification): void {
    hilog.info(DOMAIN, TAG, 'WATCH_DATA_CHANGED');
    this.processEntries(changeInfo.insertEntries);
    this.processEntries(changeInfo.updateEntries);
  }

  private processEntries(entries?: distributedKVStore.Entry[]): void {
    if (!entries || entries.length === 0) {
      return;
    }
    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i];
      this.processEntry(entry.key, entry.value.toString());
    }
  }

  private processEntry(key: string, value: string): void {
    try {
      if (key.startsWith(KEY_PET_INFO)) {
        const pet = JSON.parse(value) as WatchPetInfo;
        if (pet.deleted) {
          this.removeDeletedPetData(pet.id);
          if (this.onPetDeleted) {
            this.onPetDeleted(pet.id);
          }
        } else if (this.onPetInfoChanged) {
          this.onPetInfoChanged(pet);
        }
      } else if (key.startsWith(KEY_HEALTH_RECORD)) {
        const record = JSON.parse(value) as WatchHealthRecord;
        if (this.onHealthRecordChanged) {
          this.onHealthRecordChanged(record);
        }
      } else if (key.startsWith(KEY_FEED_REMINDER)) {
        const reminder = JSON.parse(value) as WatchFeedReminder;
        if (this.onFeedReminderChanged) {
          this.onFeedReminderChanged(reminder);
        }
      } else if (key.startsWith(KEY_BEHAVIOR_ALERT)) {
        const alert = JSON.parse(value) as WatchBehaviorAlert;
        if (this.onBehaviorAlertChanged) {
          this.onBehaviorAlertChanged(alert);
        }
      } else if (key.startsWith(KEY_LOCATION)) {
        const location = JSON.parse(value) as WatchLocationInfo;
        if (this.onLocationChanged) {
          this.onLocationChanged(location);
        }
      } else if (key.startsWith(KEY_CALENDAR_EVENT)) {
        const event = JSON.parse(value) as WatchCalendarEvent;
        if (this.onCalendarEventChanged) {
          this.onCalendarEventChanged(event);
        }
      } else if (key === KEY_SYNC_SNAPSHOT) {
        const snapshot = JSON.parse(value) as WatchSyncSnapshot;
        this.applySyncSnapshot(snapshot);
        if (this.onSnapshotChanged) {
          this.onSnapshotChanged(snapshot);
        }
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Parse error: %{public}s', JSON.stringify(err as object));
    }
  }

  async getPetInfo(petId: string): Promise<WatchPetInfo | null> {
    if (!this.kvStore || !this.isInitialized) {
      return null;
    }
    try {
      const value = await this.kvStore.get(KEY_PET_INFO + petId);
      if (value !== undefined && value !== null) {
        const pet = JSON.parse(value.toString()) as WatchPetInfo;
        return pet.deleted ? null : pet;
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Get pet error: %{public}s', JSON.stringify(err as object));
    }
    return null;
  }

  async getAllPetInfo(): Promise<WatchPetInfo[]> {
    return this.getAllActivePets();
  }

  async getAllActivePets(): Promise<WatchPetInfo[]> {
    if (!this.kvStore || !this.isInitialized) {
      return [];
    }
    const pets: WatchPetInfo[] = [];
    try {
      const entries = await this.kvStore.getEntries(KEY_PET_INFO);
      for (let i = 0; i < entries.length; i++) {
        try {
          const pet = JSON.parse(entries[i].value.toString()) as WatchPetInfo;
          if (!pet.deleted) {
            pets.push(pet);
          }
        } catch (e) {
          hilog.error(DOMAIN, TAG, 'Parse pet error');
        }
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Get pets error: %{public}s', JSON.stringify(err as object));
    }
    pets.sort((a: WatchPetInfo, b: WatchPetInfo) => b.updatedAt - a.updatedAt);
    return pets;
  }

  async removeDeletedPetData(petId: string): Promise<void> {
    if (!this.kvStore || !this.isInitialized || petId.length === 0) {
      return;
    }
    try {
      const feeds = await this.kvStore.getEntries(KEY_FEED_REMINDER);
      for (let i = 0; i < feeds.length; i++) {
        const reminder = JSON.parse(feeds[i].value.toString()) as WatchFeedReminder;
        if (reminder.petId === petId) {
          await this.kvStore.delete(feeds[i].key);
        }
      }

      const locations = await this.kvStore.getEntries(KEY_LOCATION);
      for (let i = 0; i < locations.length; i++) {
        const location = JSON.parse(locations[i].value.toString()) as WatchLocationInfo;
        if (location.petId === petId) {
          await this.kvStore.delete(locations[i].key);
        }
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Remove pet data error: %{public}s', JSON.stringify(err as object));
    }
  }

  async applySyncSnapshot(snapshot: WatchSyncSnapshot): Promise<void> {
    if (!this.kvStore || !this.isInitialized) {
      return;
    }
    try {
      const pets = await this.kvStore.getEntries(KEY_PET_INFO);
      for (let i = 0; i < pets.length; i++) {
        const pet = JSON.parse(pets[i].value.toString()) as WatchPetInfo;
        if (!pet.deleted && snapshot.petIds.indexOf(pet.id) < 0) {
          pet.deleted = true;
          pet.updatedAt = snapshot.updatedAt;
          await this.kvStore.put(KEY_PET_INFO + pet.id, JSON.stringify(pet));
          await this.removeDeletedPetData(pet.id);
          if (this.onPetDeleted) {
            this.onPetDeleted(pet.id);
          }
        }
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Apply snapshot error: %{public}s', JSON.stringify(err as object));
    }
  }

  async saveHealthRecord(record: WatchHealthRecord): Promise<boolean> {
    if (!this.kvStore || !this.isInitialized) {
      return false;
    }
    try {
      record.synced = false;
      await this.kvStore.put(KEY_HEALTH_RECORD + record.id, JSON.stringify(record));
      return true;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Save health error: %{public}s', JSON.stringify(err as object));
      return false;
    }
  }

  async saveFeedReminder(reminder: WatchFeedReminder): Promise<boolean> {
    if (!this.kvStore || !this.isInitialized) {
      return false;
    }
    try {
      reminder.updatedAt = Date.now();
      await this.kvStore.put(KEY_FEED_REMINDER + reminder.id, JSON.stringify(reminder));
      return true;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Save reminder error: %{public}s', JSON.stringify(err as object));
      return false;
    }
  }

  async getFeedReminders(petId: string): Promise<WatchFeedReminder[]> {
    if (!this.kvStore || !this.isInitialized) {
      return [];
    }
    const reminders: WatchFeedReminder[] = [];
    try {
      const entries = await this.kvStore.getEntries(KEY_FEED_REMINDER);
      for (let i = 0; i < entries.length; i++) {
        try {
          const reminder = JSON.parse(entries[i].value.toString()) as WatchFeedReminder;
          if (!reminder.deleted && reminder.petId === petId) {
            reminders.push(reminder);
          }
        } catch (e) {
          hilog.error(DOMAIN, TAG, 'Parse reminder error');
        }
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Get reminders error: %{public}s', JSON.stringify(err as object));
    }
    reminders.sort((a: WatchFeedReminder, b: WatchFeedReminder) => a.time.localeCompare(b.time));
    return reminders;
  }

  async getLocationInfo(petId: string): Promise<WatchLocationInfo | null> {
    if (!this.kvStore || !this.isInitialized || petId.length === 0) {
      return null;
    }
    try {
      const value = await this.kvStore.get(KEY_LOCATION + petId);
      if (value !== undefined && value !== null) {
        const location = JSON.parse(value.toString()) as WatchLocationInfo;
        return location.deleted ? null : location;
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Get location error: %{public}s', JSON.stringify(err as object));
    }
    return null;
  }

  async getCalendarEvents(): Promise<WatchCalendarEvent[]> {
    if (!this.kvStore || !this.isInitialized) {
      return [];
    }
    const events: WatchCalendarEvent[] = [];
    try {
      const entries = await this.kvStore.getEntries(KEY_CALENDAR_EVENT);
      for (let i = 0; i < entries.length; i++) {
        try {
          const event = JSON.parse(entries[i].value.toString()) as WatchCalendarEvent;
          if (!event.deleted) {
            events.push(event);
          }
        } catch (e) {
          hilog.error(DOMAIN, TAG, 'Parse calendar event error');
        }
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Get calendar events error: %{public}s', JSON.stringify(err as object));
    }
    events.sort((a: WatchCalendarEvent, b: WatchCalendarEvent) => a.eventDate.localeCompare(b.eventDate));
    return events;
  }

  async saveBehaviorAlert(alert: WatchBehaviorAlert): Promise<boolean> {
    if (!this.kvStore || !this.isInitialized) {
      return false;
    }
    try {
      await this.kvStore.put(KEY_BEHAVIOR_ALERT + alert.id, JSON.stringify(alert));
      return true;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Save alert error: %{public}s', JSON.stringify(err as object));
      return false;
    }
  }

  async getBehaviorAlerts(petId: string): Promise<WatchBehaviorAlert[]> {
    if (!this.kvStore || !this.isInitialized) {
      return [];
    }
    const alerts: WatchBehaviorAlert[] = [];
    try {
      const entries = await this.kvStore.getEntries(KEY_BEHAVIOR_ALERT);
      for (let i = 0; i < entries.length; i++) {
        try {
          const alert = JSON.parse(entries[i].value.toString()) as WatchBehaviorAlert;
          if (alert.petId === petId) {
            alerts.push(alert);
          }
        } catch (e) {
          hilog.error(DOMAIN, TAG, 'Parse alert error');
        }
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Get alerts error: %{public}s', JSON.stringify(err as object));
    }
    return alerts;
  }

  async markAlertRead(alertId: string): Promise<boolean> {
    if (!this.kvStore || !this.isInitialized) {
      return false;
    }
    try {
      const value = await this.kvStore.get(KEY_BEHAVIOR_ALERT + alertId);
      if (value !== undefined && value !== null) {
        const alert = JSON.parse(value.toString()) as WatchBehaviorAlert;
        alert.read = true;
        await this.kvStore.put(KEY_BEHAVIOR_ALERT + alertId, JSON.stringify(alert));
        return true;
      }
      return false;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Mark alert error: %{public}s', JSON.stringify(err as object));
      return false;
    }
  }

  async saveWatchAck(ack: WatchAck): Promise<boolean> {
    if (!this.kvStore || !this.isInitialized) {
      return false;
    }
    try {
      if (ack.id.length === 0) {
        ack.id = 'ack_' + Date.now().toString() + '_' + Math.floor(Math.random() * 1000).toString();
      }
      if (ack.timestamp === 0) {
        ack.timestamp = Date.now();
      }
      await this.kvStore.put(KEY_WATCH_ACK + ack.id, JSON.stringify(ack));
      return true;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Save ack error: %{public}s', JSON.stringify(err as object));
      return false;
    }
  }

  async onDestroy(): Promise<void> {
    try {
      if (this.kvManager) {
        await this.kvManager.closeKVStore('com.example.petsystem4_20_2', STORE_ID);
      }
      this.kvManager = null;
      this.kvStore = null;
      this.isInitialized = false;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Destroy error: %{public}s', JSON.stringify(err as object));
    }
  }
}

import { distributedKVStore } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { PetProfile, HealthRecord, FeedPlan } from './PetModels';
import { CalendarEvent } from './CalendarModels';
import { StorageManager } from './StorageManager';

const TAG: string = 'PhoneDistributedManager';
const DOMAIN: number = 0x0000;

const STORE_ID: string = 'pet_watch_store';
const STORE_OPTIONS: distributedKVStore.Options = {
  kvStoreType: distributedKVStore.KVStoreType.DEVICE_COLLABORATION,
  securityLevel: distributedKVStore.SecurityLevel.S1,
  autoSync: true
};

const KEY_PET_INFO: string = 'pet_info_';
const KEY_HEALTH_RECORD: string = 'pet_health_';
const KEY_FEED_REMINDER: string = 'pet_feed_';
const KEY_BEHAVIOR_ALERT: string = 'pet_alert_';
const KEY_LOCATION: string = 'pet_location_';
const KEY_CALENDAR_EVENT: string = 'pet_calendar_event_';
const KEY_WATCH_ACK: string = 'pet_watch_ack_';
const KEY_SYNC_SNAPSHOT: string = 'pet_sync_snapshot';

export class WatchPetInfo {
  id: string = '';
  name: string = '';
  type: string = '';
  breed: string = '';
  avatar: string = '';
  lastWeight: number = 0;
  lastTemperature: number = 0;
  birthday: string = '';
  gender: string = '';
  updatedAt: number = 0;
  deleted: boolean = false;
}

export class WatchHealthRecord {
  id: string = '';
  petId: string = '';
  timestamp: number = 0;
  weight: number = 0;
  temperature: number = 0;
  notes: string = '';
  synced: boolean = false;
}

export class WatchFeedReminder {
  id: string = '';
  petId: string = '';
  time: string = '';
  amount: string = '';
  type: string = '';
  enabled: boolean = true;
  lastFed: number = 0;
  updatedAt: number = 0;
  deleted: boolean = false;
}

export class WatchBehaviorAlert {
  id: string = '';
  petId: string = '';
  type: string = '';
  message: string = '';
  timestamp: number = 0;
  read: boolean = false;
}

export class WatchSyncSnapshot {
  petIds: string[] = [];
  feedPlanIds: string[] = [];
  calendarEventIds: string[] = [];
  updatedAt: number = 0;
}

export class WatchLocationInfo {
  petId: string = '';
  userLat: number = 23.7246660;
  userLng: number = 113.1053635;
  petLat: number = 23.7249160;
  petLng: number = 113.1057135;
  address: string = '广东碧桂园职业学院';
  updatedAt: number = 0;
  deleted: boolean = false;
}

export class WatchCalendarEvent {
  id: string = '';
  title: string = '';
  description: string = '';
  eventDate: string = '';
  type: string = 'custom';
  remindDays: number[] = [];
  read: boolean = false;
  updatedAt: number = 0;
  deleted: boolean = false;
}

export class WatchAck {
  id: string = '';
  sourceId: string = '';
  sourceType: string = '';
  action: string = '';
  petId: string = '';
  timestamp: number = 0;
  payload: string = '';
}

export class PhoneDistributedManager {
  private static instance: PhoneDistributedManager;
  private kvStore: distributedKVStore.DeviceKVStore | null = null;
  private kvManager: distributedKVStore.KVManager | null = null;
  private _isInitialized: boolean = false;
  private context: Context | null = null;
  private bundleName: string = '';

  static getInstance(): PhoneDistributedManager {
    if (!PhoneDistributedManager.instance) {
      PhoneDistributedManager.instance = new PhoneDistributedManager();
    }
    return PhoneDistributedManager.instance;
  }

  isInitialized(): boolean {
    return this._isInitialized;
  }

  async init(context: Context): Promise<void> {
    if (this._isInitialized) {
      return;
    }

    try {
      this.context = context;
      this.bundleName = context.applicationInfo.name;

      this.kvManager = await distributedKVStore.createKVManager({
        bundleName: this.bundleName,
        context: context
      });

      this.kvStore = await this.kvManager.getKVStore(STORE_ID, STORE_OPTIONS) as distributedKVStore.DeviceKVStore;

      this.kvStore.on('dataChange', distributedKVStore.SubscribeType.SUBSCRIBE_TYPE_ALL,
        (changeInfo: distributedKVStore.ChangeNotification) => {
          this.onDataChanged(changeInfo);
        });

      this._isInitialized = true;
      hilog.info(DOMAIN, TAG, 'Initialized successfully');
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to init: %{public}s', err.message);
    }
  }

  private onDataChanged(changeInfo: distributedKVStore.ChangeNotification): void {
    hilog.info(DOMAIN, TAG, 'PHONE_DATA_CHANGED, insertEntries: %{public}d',
      changeInfo.insertEntries ? changeInfo.insertEntries.length : 0);
    this.processAckEntries(changeInfo.insertEntries);
    this.processAckEntries(changeInfo.updateEntries);
  }

  private processAckEntries(entries?: distributedKVStore.Entry[]): void {
    if (!entries || entries.length === 0) {
      return;
    }
    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i];
      if (entry.key.startsWith(KEY_WATCH_ACK)) {
        try {
          const ack = JSON.parse(entry.value.toString()) as WatchAck;
          this.handleWatchAck(ack);
        } catch (err) {
          hilog.error(DOMAIN, TAG, 'Parse ack error: %{public}s', JSON.stringify(err as object));
        }
      }
    }
  }

  private mapPet(pet: PetProfile, deleted: boolean = false): WatchPetInfo {
    const watchPet: WatchPetInfo = new WatchPetInfo();
    watchPet.id = pet.id;
    watchPet.name = pet.name;
    watchPet.type = pet.type;
    watchPet.breed = pet.breed;
    watchPet.avatar = pet.avatar;
    watchPet.lastWeight = pet.weight;
    watchPet.birthday = pet.birthday;
    watchPet.gender = pet.gender;
    watchPet.updatedAt = Date.now();
    watchPet.deleted = deleted;
    return watchPet;
  }

  private mapFeedPlan(plan: FeedPlan, deleted: boolean = false): WatchFeedReminder {
    const reminder: WatchFeedReminder = new WatchFeedReminder();
    reminder.id = plan.id;
    reminder.petId = plan.petId;
    reminder.time = plan.time;
    reminder.amount = plan.amount;
    reminder.type = plan.type;
    reminder.enabled = plan.enabled;
    reminder.lastFed = plan.lastFeedAt;
    reminder.updatedAt = Date.now();
    reminder.deleted = deleted;
    return reminder;
  }

  private mapCalendarEvent(event: CalendarEvent, deleted: boolean = false): WatchCalendarEvent {
    const watchEvent: WatchCalendarEvent = new WatchCalendarEvent();
    watchEvent.id = event.id;
    watchEvent.title = event.title;
    watchEvent.description = event.description;
    watchEvent.eventDate = event.eventDate;
    watchEvent.type = event.type;
    watchEvent.remindDays = event.remindDays;
    watchEvent.read = false;
    watchEvent.updatedAt = Date.now();
    watchEvent.deleted = deleted;
    return watchEvent;
  }

  async syncPetInfoToWatch(pet: PetProfile): Promise<void> {
    if (!this.kvStore || !this._isInitialized) {
      hilog.warn(DOMAIN, TAG, 'Not initialized, skipping pet sync');
      return;
    }

    try {
      const watchPet: WatchPetInfo = this.mapPet(pet);

      await this.kvStore.put(
        KEY_PET_INFO + pet.id,
        JSON.stringify(watchPet)
      );

      hilog.info(DOMAIN, TAG, 'Pet synced: %{public}s', pet.id);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Sync pet error: %{public}s', err.message);
    }
  }

  async deletePetInfoFromWatch(petId: string): Promise<void> {
    if (!this.kvStore || !this._isInitialized) {
      hilog.warn(DOMAIN, TAG, 'Not initialized, skipping pet delete sync');
      return;
    }
    try {
      const tombstone: WatchPetInfo = new WatchPetInfo();
      tombstone.id = petId;
      tombstone.updatedAt = Date.now();
      tombstone.deleted = true;
      await this.kvStore.put(KEY_PET_INFO + petId, JSON.stringify(tombstone));
      hilog.info(DOMAIN, TAG, 'Pet tombstone synced: %{public}s', petId);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Delete pet sync error: %{public}s', err.message);
    }
  }

  async syncPetSnapshotToWatch(pets: PetProfile[], feedPlans: FeedPlan[], calendarEvents: CalendarEvent[]): Promise<void> {
    if (!this.kvStore || !this._isInitialized) {
      hilog.warn(DOMAIN, TAG, 'Not initialized, skipping snapshot sync');
      return;
    }
    try {
      const snapshot: WatchSyncSnapshot = new WatchSyncSnapshot();
      snapshot.updatedAt = Date.now();
      for (let i = 0; i < pets.length; i++) {
        snapshot.petIds.push(pets[i].id);
      }
      for (let i = 0; i < feedPlans.length; i++) {
        snapshot.feedPlanIds.push(feedPlans[i].id);
      }
      for (let i = 0; i < calendarEvents.length; i++) {
        snapshot.calendarEventIds.push(calendarEvents[i].id);
      }
      await this.kvStore.put(KEY_SYNC_SNAPSHOT, JSON.stringify(snapshot));
      hilog.info(DOMAIN, TAG, 'Snapshot synced pets=%{public}d feeds=%{public}d events=%{public}d',
        snapshot.petIds.length, snapshot.feedPlanIds.length, snapshot.calendarEventIds.length);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Snapshot sync error: %{public}s', err.message);
    }
  }

  async syncHealthRecordToWatch(record: HealthRecord): Promise<void> {
    if (!this.kvStore || !this._isInitialized) {
      hilog.warn(DOMAIN, TAG, 'Not initialized, skipping health sync');
      return;
    }

    try {
      const watchRecord: WatchHealthRecord = new WatchHealthRecord();
      watchRecord.id = record.id;
      watchRecord.petId = record.petId;
      watchRecord.timestamp = Date.now();
      watchRecord.weight = record.weight;
      watchRecord.temperature = record.temperature;
      watchRecord.notes = record.notes;
      watchRecord.synced = true;

      await this.kvStore.put(KEY_HEALTH_RECORD + record.id, JSON.stringify(watchRecord));
      hilog.info(DOMAIN, TAG, 'Health synced: %{public}s', record.id);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Sync health error: %{public}s', err.message);
    }
  }

  async syncFeedPlanToWatch(plan: FeedPlan): Promise<void> {
    if (!this.kvStore || !this._isInitialized) {
      hilog.warn(DOMAIN, TAG, 'Not initialized, skipping feed sync');
      return;
    }

    try {
      const watchReminder: WatchFeedReminder = this.mapFeedPlan(plan);

      await this.kvStore.put(KEY_FEED_REMINDER + plan.id, JSON.stringify(watchReminder));
      hilog.info(DOMAIN, TAG, 'Feed synced: %{public}s', plan.id);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Sync feed error: %{public}s', err.message);
    }
  }

  async deleteFeedPlanFromWatch(planId: string, petId: string): Promise<void> {
    if (!this.kvStore || !this._isInitialized) {
      hilog.warn(DOMAIN, TAG, 'Not initialized, skipping feed delete sync');
      return;
    }
    try {
      const tombstone: WatchFeedReminder = new WatchFeedReminder();
      tombstone.id = planId;
      tombstone.petId = petId;
      tombstone.updatedAt = Date.now();
      tombstone.deleted = true;
      await this.kvStore.put(KEY_FEED_REMINDER + planId, JSON.stringify(tombstone));
      hilog.info(DOMAIN, TAG, 'Feed tombstone synced: %{public}s', planId);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Delete feed sync error: %{public}s', err.message);
    }
  }

  async syncLocationToWatch(location: WatchLocationInfo): Promise<void> {
    if (!this.kvStore || !this._isInitialized) {
      hilog.warn(DOMAIN, TAG, 'Not initialized, skipping location sync');
      return;
    }
    try {
      location.updatedAt = Date.now();
      await this.kvStore.put(KEY_LOCATION + location.petId, JSON.stringify(location));
      hilog.info(DOMAIN, TAG, 'Location synced: %{public}s', location.petId);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Location sync error: %{public}s', err.message);
    }
  }

  async syncCalendarEventToWatch(event: CalendarEvent, deleted: boolean = false): Promise<void> {
    if (!this.kvStore || !this._isInitialized) {
      hilog.warn(DOMAIN, TAG, 'Not initialized, skipping calendar sync');
      return;
    }
    try {
      const watchEvent: WatchCalendarEvent = this.mapCalendarEvent(event, deleted);
      await this.kvStore.put(KEY_CALENDAR_EVENT + event.id, JSON.stringify(watchEvent));
      hilog.info(DOMAIN, TAG, 'Calendar event synced: %{public}s deleted=%{public}s',
        event.id, deleted ? 'true' : 'false');
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Calendar sync error: %{public}s', err.message);
    }
  }

  async handleWatchAck(ack: WatchAck): Promise<void> {
    if (!this.context) {
      hilog.warn(DOMAIN, TAG, 'No context, cannot apply ack');
      return;
    }
    hilog.info(DOMAIN, TAG, 'Handle watch ack source=%{public}s action=%{public}s',
      ack.sourceType, ack.action);
    if (ack.sourceType === 'feed') {
      await this.handleFeedAck(ack);
    } else if (ack.sourceType === 'calendar') {
      hilog.info(DOMAIN, TAG, 'Calendar ack received sourceId=%{public}s action=%{public}s',
        ack.sourceId, ack.action);
    }
  }

  private async handleFeedAck(ack: WatchAck): Promise<void> {
    try {
      const storage = StorageManager.getInstance();
      if (!storage.isReady() && this.context) {
        await storage.init(this.context);
      }
      const plans: FeedPlan[] = await storage.getFeedPlans();
      let changed: boolean = false;
      for (let i = 0; i < plans.length; i++) {
        if (plans[i].id === ack.sourceId) {
          if (ack.action === 'feed_toggle') {
            const payload = JSON.parse(ack.payload) as Record<string, boolean>;
            plans[i].enabled = payload['enabled'];
            changed = true;
          } else if (ack.action === 'feed_done') {
            plans[i].lastFeedAt = ack.timestamp;
            changed = true;
          } else if (ack.action === 'feed_snooze') {
            plans[i].lastTriggeredAt = 'snooze_' + ack.timestamp.toString();
            changed = true;
          }
          if (changed) {
            await this.syncFeedPlanToWatch(plans[i]);
          }
          break;
        }
      }
      if (changed) {
        await storage.saveFeedPlans(plans);
        AppStorage.set('petDataVersion', Date.now());
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Apply feed ack error: %{public}s', JSON.stringify(err as object));
    }
  }

  async sendBehaviorAlertToWatch(alert: WatchBehaviorAlert): Promise<void> {
    if (!this.kvStore || !this._isInitialized) {
      hilog.warn(DOMAIN, TAG, 'Not initialized, skipping alert sync');
      return;
    }

    try {
      await this.kvStore.put(KEY_BEHAVIOR_ALERT + alert.id, JSON.stringify(alert));
      hilog.info(DOMAIN, TAG, 'Alert synced: %{public}s', alert.id);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Sync alert error: %{public}s', err.message);
    }
  }

  async onDestroy(): Promise<void> {
    try {
      if (this.kvManager) {
        await this.kvManager.closeKVStore(this.bundleName, STORE_ID);
      }
      this.kvManager = null;
      this.kvStore = null;
      this._isInitialized = false;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Destroy error: %{public}s', err.message);
    }
  }
}

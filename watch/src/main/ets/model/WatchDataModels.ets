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

export class SyncStatus {
  lastSyncTime: number = 0;
  isSyncing: boolean = false;
  pendingCount: number = 0;
}

export interface AppColors {
  primary: string;
  primaryLight: string;
  primaryDark: string;
  success: string;
  warning: string;
  danger: string;
  background: string;
  card: string;
  cardHighlight: string;
  textPrimary: string;
  textSecondary: string;
  textHint: string;
}

export const COLORS: AppColors = {
  primary: '#FF6B9D',
  primaryLight: '#FFB5C5',
  primaryDark: '#FF8FAB',
  success: '#4CAF50',
  warning: '#FFB347',
  danger: '#FF4444',
  background: '#FFFBFD',
  card: '#FFFFFF',
  cardHighlight: '#FFE8EE',
  textPrimary: '#333',
  textSecondary: '#666',
  textHint: '#999'
};

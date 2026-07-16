export type EventType = 'birthday' | 'study' | 'work' | 'anniversary' | 'custom';

export interface CalendarEvent {
  id: string;
  title: string;
  description: string;
  eventDate: string;
  type: EventType;
  remindDays: number[];
  createdAt: number;
  updatedAt: number;
  deleted: boolean;
}

export function generateEventId(): string {
  return 'evt_' + Date.now() + '_' + Math.floor(Math.random() * 1000).toString();
}

export function getEventTypeLabel(type: EventType): string {
  if (type === 'birthday') { return '生日'; }
  if (type === 'study') { return '学习'; }
  if (type === 'work') { return '工作'; }
  if (type === 'anniversary') { return '纪念日'; }
  return '自定义';
}

export function getEventTypeColor(type: EventType): string {
  if (type === 'birthday') { return '#FF6B6B'; }
  if (type === 'study') { return '#4CAF50'; }
  if (type === 'work') { return '#64B5F6'; }
  if (type === 'anniversary') { return '#AB47BC'; }
  return '#BBBBBB';
}

export function getEventTypeBgColor(type: EventType): string {
  if (type === 'birthday') { return '#FFEBEE'; }
  if (type === 'study') { return '#E8F5E9'; }
  if (type === 'work') { return '#E3F2FD'; }
  if (type === 'anniversary') { return '#F3E5F5'; }
  return '#F5F5F5';
}

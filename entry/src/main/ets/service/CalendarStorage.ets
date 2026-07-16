import { preferences } from '@kit.ArkData';
import { CalendarEvent } from '../model/CalendarModels';

const STORE_NAME: string = 'CalendarStore';
const KEY_EVENTS: string = 'calendar_events';

export class CalendarStorage {
  private store: preferences.Preferences | null = null;

  async init(context: Context): Promise<void> {
    if (this.store !== null) { return; }
    try {
      this.store = await preferences.getPreferences(context, STORE_NAME);
    } catch (err) {
      console.error('CalendarStorage init error:', JSON.stringify(err));
    }
  }

  private isReady(): boolean {
    return this.store !== null;
  }

  async getEvents(): Promise<CalendarEvent[]> {
    if (!this.isReady()) { return []; }
    try {
      const value: string = await this.store!.get(KEY_EVENTS, '[]') as string;
      return JSON.parse(value) as CalendarEvent[];
    } catch (err) {
      console.error('CalendarStorage getEvents error:', JSON.stringify(err));
      return [];
    }
  }

  async getEventById(id: string): Promise<CalendarEvent | undefined> {
    const events: CalendarEvent[] = await this.getEvents();
    for (let i = 0; i < events.length; i++) {
      if (events[i].id === id) { return events[i]; }
    }
    return undefined;
  }

  async getEventsByDate(date: string): Promise<CalendarEvent[]> {
    const events: CalendarEvent[] = await this.getEvents();
    const result: CalendarEvent[] = [];
    for (let i = 0; i < events.length; i++) {
      if (events[i].eventDate === date) {
        result.push(events[i]);
      }
    }
    return result;
  }

  async saveEvents(events: CalendarEvent[]): Promise<void> {
    if (!this.isReady()) { return; }
    try {
      await this.store!.put(KEY_EVENTS, JSON.stringify(events));
      await this.store!.flush();
    } catch (err) {
      console.error('CalendarStorage saveEvents error:', JSON.stringify(err));
    }
  }

  async addEvent(event: CalendarEvent): Promise<void> {
    const events: CalendarEvent[] = await this.getEvents();
    events.push(event);
    await this.saveEvents(events);
  }

  async updateEvent(event: CalendarEvent): Promise<void> {
    const events: CalendarEvent[] = await this.getEvents();
    for (let i = 0; i < events.length; i++) {
      if (events[i].id === event.id) {
        events[i] = event;
        break;
      }
    }
    await this.saveEvents(events);
  }

  async deleteEvent(id: string): Promise<void> {
    const events: CalendarEvent[] = await this.getEvents();
    const filtered: CalendarEvent[] = [];
    for (let i = 0; i < events.length; i++) {
      if (events[i].id !== id) {
        filtered.push(events[i]);
      }
    }
    await this.saveEvents(filtered);
  }
}

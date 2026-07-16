type EventCallback = (data: Object) => void;

export class AppEventBus {
  private static listeners: Map<string, EventCallback[]> = new Map();

  static on(event: string, callback: EventCallback): void {
    let list: EventCallback[] | undefined = AppEventBus.listeners.get(event);
    if (list === undefined) {
      list = [];
      AppEventBus.listeners.set(event, list);
    }
    list.push(callback);
  }

  static off(event: string): void {
    AppEventBus.listeners.delete(event);
  }

  static emit(event: string, data: Object): void {
    const list: EventCallback[] | undefined = AppEventBus.listeners.get(event);
    if (list === undefined) { return; }
    for (let i = 0; i < list.length; i++) {
      list[i](data);
    }
  }
}

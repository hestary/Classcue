import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { TodoItem } from '../model/TodoItem';

const STORE_NAME: string = 'lock_todo_store';
const TODO_KEY: string = 'todos';
const REMINDER_CLEANUP_KEY: string = 'reminder_cleanup_1700002_v1';

export class TodoStore {
  private store?: preferences.Preferences;

  async initialize(context: common.UIAbilityContext): Promise<void> {
    if (this.store) {
      return;
    }
    this.store = await preferences.getPreferences(context, { name: STORE_NAME });
  }

  async load(): Promise<TodoItem[]> {
    if (!this.store) {
      return [];
    }
    const raw: preferences.ValueType = await this.store.get(TODO_KEY, '[]');
    try {
      const parsed: TodoItem[] = JSON.parse(String(raw)) as TodoItem[];
      return parsed.map((item: TodoItem) => TodoItem.fromJson(item));
    } catch (error) {
      return [];
    }
  }

  async save(items: TodoItem[]): Promise<void> {
    if (!this.store) {
      return;
    }
    await this.store.put(TODO_KEY, JSON.stringify(items));
    await this.store.flush();
  }

  async needsReminderCleanup(): Promise<boolean> {
    if (!this.store) {
      return false;
    }
    return !Boolean(await this.store.get(REMINDER_CLEANUP_KEY, false));
  }

  async markReminderCleanupComplete(): Promise<void> {
    if (!this.store) {
      return;
    }
    await this.store.put(REMINDER_CLEANUP_KEY, true);
    await this.store.flush();
  }
}

export const todoStore: TodoStore = new TodoStore();

import { relationalStore } from '@kit.ArkData';
import { PetCompanion, ChatRecord, CompanionMemory, CompanionStats, CompanionPersonality, CompanionMood, MemoryType } from './CompanionModels';

const STORE_CONFIG: relationalStore.StoreConfig = {
  name: 'CompanionStore.db',
  securityLevel: relationalStore.SecurityLevel.S1
};

const SQL_CREATE_COMPANION = `
  CREATE TABLE IF NOT EXISTS companion (
    id TEXT PRIMARY KEY,
    account TEXT,
    pet_id TEXT,
    name TEXT,
    species TEXT DEFAULT 'cat',
    avatar TEXT DEFAULT '',
    personality TEXT DEFAULT '温柔',
    level INTEGER DEFAULT 1,
    exp INTEGER DEFAULT 0,
    intimacy INTEGER DEFAULT 0,
    mood TEXT DEFAULT 'calm',
    created INTEGER DEFAULT 0,
    updated INTEGER DEFAULT 0
  )`;

const SQL_CREATE_CHAT = `
  CREATE TABLE IF NOT EXISTS chat_record (
    id TEXT PRIMARY KEY,
    companion_id TEXT,
    role TEXT,
    content TEXT,
    timestamp INTEGER DEFAULT 0
  )`;

const SQL_CREATE_MEMORY = `
  CREATE TABLE IF NOT EXISTS companion_memory (
    id TEXT PRIMARY KEY,
    companion_id TEXT,
    type TEXT DEFAULT 'daily',
    content TEXT,
    detail TEXT DEFAULT '',
    weight INTEGER DEFAULT 1,
    timestamp INTEGER DEFAULT 0
  )`;

const SQL_MIGRATE_LAST_ACCESS = `
  ALTER TABLE companion_memory ADD COLUMN last_access_time INTEGER DEFAULT 0`;

const SQL_MIGRATE_IMPORTANCE = `
  ALTER TABLE companion_memory ADD COLUMN importance INTEGER DEFAULT 40`;

const SQL_MIGRATE_HAPPINESS = `
  ALTER TABLE companion ADD COLUMN happiness INTEGER DEFAULT 80`;

const SQL_MIGRATE_LAST_INTERACT = `
  ALTER TABLE companion ADD COLUMN last_interact_time INTEGER DEFAULT 0`;

const SQL_MIGRATE_EMOTION = `
  ALTER TABLE chat_record ADD COLUMN detected_emotion TEXT DEFAULT ''`;

const SQL_MIGRATE_CHECKIN_DATE = `
  ALTER TABLE companion ADD COLUMN last_checkin_date TEXT DEFAULT ''`;

const SQL_MIGRATE_CHECKIN_DAYS = `
  ALTER TABLE companion ADD COLUMN checkin_days INTEGER DEFAULT 0`;

const SQL_MIGRATE_CHAT_COUNT = `
  ALTER TABLE companion ADD COLUMN chat_count INTEGER DEFAULT 0`;

const SQL_MIGRATE_ACHIEVEMENT_COUNT = `
  ALTER TABLE companion ADD COLUMN achievement_count INTEGER DEFAULT 0`;

const SQL_MIGRATE_UNLOCKED_IDS = `
  ALTER TABLE companion ADD COLUMN unlocked_ids TEXT DEFAULT ''`;

export class CompanionStorage {
  private static instance: CompanionStorage;
  private rdbStore: relationalStore.RdbStore | null = null;

  private constructor() {}

  static getInstance(): CompanionStorage {
    if (!CompanionStorage.instance) {
      CompanionStorage.instance = new CompanionStorage();
    }
    return CompanionStorage.instance;
  }

  async init(context: Context): Promise<void> {
    if (this.rdbStore !== null) { return; }
    try {
      this.rdbStore = await relationalStore.getRdbStore(context, STORE_CONFIG);
      await this.rdbStore.executeSql(SQL_CREATE_COMPANION);
      await this.rdbStore.executeSql(SQL_CREATE_CHAT);
      await this.rdbStore.executeSql(SQL_CREATE_MEMORY);
      try {
        await this.rdbStore.executeSql(SQL_MIGRATE_LAST_ACCESS);
      } catch (e) {
        // column may already exist, ignore
      }
      try {
        await this.rdbStore.executeSql(SQL_MIGRATE_IMPORTANCE);
      } catch (e) {
        // column may already exist, ignore
      }
      try {
        await this.rdbStore.executeSql(SQL_MIGRATE_HAPPINESS);
      } catch (e) {
        // column may already exist, ignore
      }
      try {
        await this.rdbStore.executeSql(SQL_MIGRATE_LAST_INTERACT);
      } catch (e) {
        // column may already exist, ignore
      }
      try {
        await this.rdbStore.executeSql(SQL_MIGRATE_EMOTION);
      } catch (e) {
        // column may already exist, ignore
      }
      try {
        await this.rdbStore.executeSql(SQL_MIGRATE_CHECKIN_DATE);
      } catch (e) { }
      try {
        await this.rdbStore.executeSql(SQL_MIGRATE_CHECKIN_DAYS);
      } catch (e) { }
      try {
        await this.rdbStore.executeSql(SQL_MIGRATE_CHAT_COUNT);
      } catch (e) { }
      try {
        await this.rdbStore.executeSql(SQL_MIGRATE_ACHIEVEMENT_COUNT);
      } catch (e) { }
      try {
        await this.rdbStore.executeSql(SQL_MIGRATE_UNLOCKED_IDS);
      } catch (e) { }
    } catch (err) {
      console.error('Failed to init CompanionStorage:', JSON.stringify(err));
    }
  }

  isReady(): boolean {
    return this.rdbStore !== null;
  }

  async saveCompanion(companion: PetCompanion): Promise<boolean> {
    if (!this.rdbStore) { return false; }
    try {
      const existing = await this.getCompanion(companion.account);
      if (existing !== null) {
        const valueBucket: relationalStore.ValuesBucket = {
          'name': companion.name,
          'species': companion.species,
          'avatar': companion.avatar,
          'personality': companion.personality,
          'level': companion.level,
          'exp': companion.exp,
          'intimacy': companion.intimacy,
          'mood': companion.mood,
          'happiness': companion.happiness,
          'last_interact_time': companion.lastInteractTime,
          'last_checkin_date': companion.lastCheckInDate,
          'checkin_days': companion.checkInDays,
          'chat_count': companion.chatCount,
          'achievement_count': companion.achievementCount,
          'unlocked_ids': companion.unlockedIds,
          'updated': companion.updated
        };
        const predicates = new relationalStore.RdbPredicates('companion');
        predicates.equalTo('id', companion.id);
        await this.rdbStore.update(valueBucket, predicates);
      } else {
        const valueBucket: relationalStore.ValuesBucket = {
          'id': companion.id,
          'account': companion.account,
          'pet_id': companion.petId,
          'name': companion.name,
          'species': companion.species,
          'avatar': companion.avatar,
          'personality': companion.personality,
          'level': companion.level,
          'exp': companion.exp,
          'intimacy': companion.intimacy,
          'mood': companion.mood,
          'happiness': companion.happiness,
          'last_interact_time': companion.lastInteractTime,
          'last_checkin_date': companion.lastCheckInDate,
          'checkin_days': companion.checkInDays,
          'chat_count': companion.chatCount,
          'achievement_count': companion.achievementCount,
          'unlocked_ids': companion.unlockedIds,
          'created': companion.created,
          'updated': companion.updated
        };
        await this.rdbStore.insert('companion', valueBucket);
      }
      return true;
    } catch (err) {
      console.error('saveCompanion error:', JSON.stringify(err));
      return false;
    }
  }

  async getCompanion(account: string): Promise<PetCompanion | null> {
    if (!this.rdbStore) { return null; }
    try {
      const predicates = new relationalStore.RdbPredicates('companion');
      predicates.equalTo('account', account);
      const resultSet: relationalStore.ResultSet = await this.rdbStore.query(predicates);
      if (resultSet.goToFirstRow()) {
        const companion = new PetCompanion();
        companion.id = resultSet.getString(resultSet.getColumnIndex('id'));
        companion.account = resultSet.getString(resultSet.getColumnIndex('account'));
        companion.petId = resultSet.getString(resultSet.getColumnIndex('pet_id'));
        companion.name = resultSet.getString(resultSet.getColumnIndex('name'));
        companion.species = resultSet.getString(resultSet.getColumnIndex('species'));
        companion.avatar = resultSet.getString(resultSet.getColumnIndex('avatar'));
        companion.personality = resultSet.getString(resultSet.getColumnIndex('personality')) as CompanionPersonality;
        companion.level = resultSet.getLong(resultSet.getColumnIndex('level'));
        companion.exp = resultSet.getLong(resultSet.getColumnIndex('exp'));
        companion.intimacy = resultSet.getLong(resultSet.getColumnIndex('intimacy'));
        companion.mood = resultSet.getString(resultSet.getColumnIndex('mood')) as CompanionMood;
        companion.created = resultSet.getLong(resultSet.getColumnIndex('created'));
        companion.updated = resultSet.getLong(resultSet.getColumnIndex('updated'));
        try { companion.happiness = resultSet.getLong(resultSet.getColumnIndex('happiness')); } catch (e) { companion.happiness = 80; }
        try { companion.lastInteractTime = resultSet.getLong(resultSet.getColumnIndex('last_interact_time')); } catch (e) { companion.lastInteractTime = 0; }
        try { companion.lastCheckInDate = resultSet.getString(resultSet.getColumnIndex('last_checkin_date')); } catch (e) { companion.lastCheckInDate = ''; }
        try { companion.checkInDays = resultSet.getLong(resultSet.getColumnIndex('checkin_days')); } catch (e) { companion.checkInDays = 0; }
        try { companion.chatCount = resultSet.getLong(resultSet.getColumnIndex('chat_count')); } catch (e) { companion.chatCount = 0; }
        try { companion.achievementCount = resultSet.getLong(resultSet.getColumnIndex('achievement_count')); } catch (e) { companion.achievementCount = 0; }
        try { companion.unlockedIds = resultSet.getString(resultSet.getColumnIndex('unlocked_ids')); } catch (e) { companion.unlockedIds = ''; }
        resultSet.close();
        return companion;
      }
      resultSet.close();
      return null;
    } catch (err) {
      console.error('getCompanion error:', JSON.stringify(err));
      return null;
    }
  }

  async getCompanionById(id: string): Promise<PetCompanion | null> {
    if (!this.rdbStore) { return null; }
    try {
      const predicates = new relationalStore.RdbPredicates('companion');
      predicates.equalTo('id', id);
      const resultSet: relationalStore.ResultSet = await this.rdbStore.query(predicates);
      if (resultSet.goToFirstRow()) {
        const companion = new PetCompanion();
        companion.id = resultSet.getString(resultSet.getColumnIndex('id'));
        companion.account = resultSet.getString(resultSet.getColumnIndex('account'));
        companion.petId = resultSet.getString(resultSet.getColumnIndex('pet_id'));
        companion.name = resultSet.getString(resultSet.getColumnIndex('name'));
        companion.species = resultSet.getString(resultSet.getColumnIndex('species'));
        companion.avatar = resultSet.getString(resultSet.getColumnIndex('avatar'));
        companion.personality = resultSet.getString(resultSet.getColumnIndex('personality')) as CompanionPersonality;
        companion.level = resultSet.getLong(resultSet.getColumnIndex('level'));
        companion.exp = resultSet.getLong(resultSet.getColumnIndex('exp'));
        companion.intimacy = resultSet.getLong(resultSet.getColumnIndex('intimacy'));
        companion.mood = resultSet.getString(resultSet.getColumnIndex('mood')) as CompanionMood;
        companion.created = resultSet.getLong(resultSet.getColumnIndex('created'));
        companion.updated = resultSet.getLong(resultSet.getColumnIndex('updated'));
        try { companion.happiness = resultSet.getLong(resultSet.getColumnIndex('happiness')); } catch (e) { companion.happiness = 80; }
        try { companion.lastInteractTime = resultSet.getLong(resultSet.getColumnIndex('last_interact_time')); } catch (e) { companion.lastInteractTime = 0; }
        try { companion.lastCheckInDate = resultSet.getString(resultSet.getColumnIndex('last_checkin_date')); } catch (e) { companion.lastCheckInDate = ''; }
        try { companion.checkInDays = resultSet.getLong(resultSet.getColumnIndex('checkin_days')); } catch (e) { companion.checkInDays = 0; }
        try { companion.chatCount = resultSet.getLong(resultSet.getColumnIndex('chat_count')); } catch (e) { companion.chatCount = 0; }
        try { companion.achievementCount = resultSet.getLong(resultSet.getColumnIndex('achievement_count')); } catch (e) { companion.achievementCount = 0; }
        try { companion.unlockedIds = resultSet.getString(resultSet.getColumnIndex('unlocked_ids')); } catch (e) { companion.unlockedIds = ''; }
        resultSet.close();
        return companion;
      }
      resultSet.close();
      return null;
    } catch (err) {
      console.error('getCompanionById error:', JSON.stringify(err));
      return null;
    }
  }

  async deleteCompanion(id: string): Promise<boolean> {
    if (!this.rdbStore) { return false; }
    try {
      const predicates = new relationalStore.RdbPredicates('companion');
      predicates.equalTo('id', id);
      await this.rdbStore.delete(predicates);
      await this.rdbStore.executeSql('DELETE FROM chat_record WHERE companion_id = ?', [id]);
      await this.rdbStore.executeSql('DELETE FROM companion_memory WHERE companion_id = ?', [id]);
      return true;
    } catch (err) {
      console.error('deleteCompanion error:', JSON.stringify(err));
      return false;
    }
  }

  async saveChat(record: ChatRecord): Promise<void> {
    if (!this.rdbStore) { return; }
    try {
      const valueBucket: relationalStore.ValuesBucket = {
        'id': record.id,
        'companion_id': record.companionId,
        'role': record.role,
        'content': record.content,
        'detected_emotion': record.detectedEmotion,
        'timestamp': record.timestamp
      };
      await this.rdbStore.insert('chat_record', valueBucket);
    } catch (err) {
      console.error('saveChat error:', JSON.stringify(err));
    }
  }

  async getChatHistory(companionId: string, limit: number): Promise<ChatRecord[]> {
    if (!this.rdbStore) { return []; }
    const records: ChatRecord[] = [];
    try {
      const predicates = new relationalStore.RdbPredicates('chat_record');
      predicates.equalTo('companion_id', companionId);
      predicates.orderByDesc('timestamp');
      const resultSet: relationalStore.ResultSet = await this.rdbStore.query(predicates);
      while (resultSet.goToNextRow()) {
        const record = new ChatRecord();
        record.id = resultSet.getString(resultSet.getColumnIndex('id'));
        record.companionId = resultSet.getString(resultSet.getColumnIndex('companion_id'));
        record.role = resultSet.getString(resultSet.getColumnIndex('role'));
        record.content = resultSet.getString(resultSet.getColumnIndex('content'));
        try { record.detectedEmotion = resultSet.getString(resultSet.getColumnIndex('detected_emotion')); } catch (e) { record.detectedEmotion = ''; }
        record.timestamp = resultSet.getLong(resultSet.getColumnIndex('timestamp'));
        records.unshift(record);
      }
      resultSet.close();
      return records;
    } catch (err) {
      console.error('getChatHistory error:', JSON.stringify(err));
      return records;
    }
  }

  async getChatCount(companionId: string): Promise<number> {
    if (!this.rdbStore) { return 0; }
    try {
      const predicates = new relationalStore.RdbPredicates('chat_record');
      predicates.equalTo('companion_id', companionId);
      const resultSet: relationalStore.ResultSet = await this.rdbStore.query(predicates);
      const count = resultSet.rowCount;
      resultSet.close();
      return count;
    } catch (err) {
      return 0;
    }
  }

  async saveMemory(memory: CompanionMemory): Promise<void> {
    if (!this.rdbStore) { return; }
    try {
      const valueBucket: relationalStore.ValuesBucket = {
        'id': memory.id,
        'companion_id': memory.companionId,
        'type': memory.type,
        'content': memory.content,
        'detail': memory.detail,
        'weight': memory.weight,
        'timestamp': memory.timestamp,
        'last_access_time': memory.lastAccessTime,
        'importance': memory.importance
      };
      await this.rdbStore.insert('companion_memory', valueBucket);
    } catch (err) {
      console.error('saveMemory error:', JSON.stringify(err));
    }
  }

  async getMemories(companionId: string, limit: number): Promise<CompanionMemory[]> {
    if (!this.rdbStore) { return []; }
    const memories: CompanionMemory[] = [];
    try {
      const predicates = new relationalStore.RdbPredicates('companion_memory');
      predicates.equalTo('companion_id', companionId);
      predicates.orderByDesc('weight');
      const resultSet: relationalStore.ResultSet = await this.rdbStore.query(predicates);
      while (resultSet.goToNextRow()) {
        const memory = new CompanionMemory();
        memory.id = resultSet.getString(resultSet.getColumnIndex('id'));
        memory.companionId = resultSet.getString(resultSet.getColumnIndex('companion_id'));
        memory.type = resultSet.getString(resultSet.getColumnIndex('type')) as MemoryType;
        memory.content = resultSet.getString(resultSet.getColumnIndex('content'));
        memory.detail = resultSet.getString(resultSet.getColumnIndex('detail'));
        memory.weight = resultSet.getLong(resultSet.getColumnIndex('weight'));
        memory.timestamp = resultSet.getLong(resultSet.getColumnIndex('timestamp'));
        try { memory.lastAccessTime = resultSet.getLong(resultSet.getColumnIndex('last_access_time')); } catch (e) { }
        try { memory.importance = resultSet.getLong(resultSet.getColumnIndex('importance')); } catch (e) { memory.importance = 40; }
        memories.push(memory);
      }
      resultSet.close();
      return memories;
    } catch (err) {
      console.error('getMemories error:', JSON.stringify(err));
      return memories;
    }
  }

  async getMemoryCount(companionId: string): Promise<number> {
    if (!this.rdbStore) { return 0; }
    try {
      const predicates = new relationalStore.RdbPredicates('companion_memory');
      predicates.equalTo('companion_id', companionId);
      const resultSet: relationalStore.ResultSet = await this.rdbStore.query(predicates);
      const count = resultSet.rowCount;
      resultSet.close();
      return count;
    }     catch (err) {
      return 0;
    }
  }

  async updateMemory(memory: CompanionMemory): Promise<void> {
    if (!this.rdbStore) { return; }
    try {
      const valueBucket: relationalStore.ValuesBucket = {
        'content': memory.content,
        'detail': memory.detail,
        'type': memory.type,
        'weight': memory.weight,
        'last_access_time': memory.lastAccessTime
      };
      const predicates = new relationalStore.RdbPredicates('companion_memory');
      predicates.equalTo('id', memory.id);
      await this.rdbStore.update(valueBucket, predicates);
    } catch (err) {
      console.error('updateMemory error:', JSON.stringify(err));
    }
  }

  async deleteMemory(memoryId: string): Promise<void> {
    if (!this.rdbStore) { return; }
    try {
      const predicates = new relationalStore.RdbPredicates('companion_memory');
      predicates.equalTo('id', memoryId);
      await this.rdbStore.delete(predicates);
    } catch (err) {
      console.error('deleteMemory error:', JSON.stringify(err));
    }
  }

  async getAllMemories(companionId: string): Promise<CompanionMemory[]> {
    if (!this.rdbStore) { return []; }
    const memories: CompanionMemory[] = [];
    try {
      const predicates = new relationalStore.RdbPredicates('companion_memory');
      predicates.equalTo('companion_id', companionId);
      predicates.orderByDesc('timestamp');
      const resultSet: relationalStore.ResultSet = await this.rdbStore.query(predicates);
      while (resultSet.goToNextRow()) {
        const memory = new CompanionMemory();
        memory.id = resultSet.getString(resultSet.getColumnIndex('id'));
        memory.companionId = resultSet.getString(resultSet.getColumnIndex('companion_id'));
        memory.type = resultSet.getString(resultSet.getColumnIndex('type')) as MemoryType;
        memory.content = resultSet.getString(resultSet.getColumnIndex('content'));
        memory.detail = resultSet.getString(resultSet.getColumnIndex('detail'));
        memory.weight = resultSet.getLong(resultSet.getColumnIndex('weight'));
        memory.timestamp = resultSet.getLong(resultSet.getColumnIndex('timestamp'));
        try { memory.lastAccessTime = resultSet.getLong(resultSet.getColumnIndex('last_access_time')); } catch (e) { }
        try { memory.importance = resultSet.getLong(resultSet.getColumnIndex('importance')); } catch (e) { memory.importance = 40; }
        memories.push(memory);
      }
      resultSet.close();
      return memories;
    } catch (err) {
      console.error('getAllMemories error:', JSON.stringify(err));
      return memories;
    }
  }

  async getImportantMemories(companionId: string, limit: number): Promise<CompanionMemory[]> {
    if (!this.rdbStore) { return []; }
    const memories: CompanionMemory[] = [];
    try {
      const predicates = new relationalStore.RdbPredicates('companion_memory');
      predicates.equalTo('companion_id', companionId);
      predicates.orderByDesc('importance');
      const resultSet: relationalStore.ResultSet = await this.rdbStore.query(predicates);
      while (resultSet.goToNextRow()) {
        const memory = new CompanionMemory();
        memory.id = resultSet.getString(resultSet.getColumnIndex('id'));
        memory.companionId = resultSet.getString(resultSet.getColumnIndex('companion_id'));
        memory.type = resultSet.getString(resultSet.getColumnIndex('type')) as MemoryType;
        memory.content = resultSet.getString(resultSet.getColumnIndex('content'));
        memory.detail = resultSet.getString(resultSet.getColumnIndex('detail'));
        memory.weight = resultSet.getLong(resultSet.getColumnIndex('weight'));
        memory.timestamp = resultSet.getLong(resultSet.getColumnIndex('timestamp'));
        try { memory.lastAccessTime = resultSet.getLong(resultSet.getColumnIndex('last_access_time')); } catch (e) { }
        try { memory.importance = resultSet.getLong(resultSet.getColumnIndex('importance')); } catch (e) { memory.importance = 40; }
        memories.push(memory);
        if (memories.length >= limit) { break; }
      }
      resultSet.close();
      return memories;
    } catch (err) {
      console.error('getImportantMemories error:', JSON.stringify(err));
      return memories;
    }
  }

  async getTodayChatCount(companionId: string): Promise<number> {
    if (!this.rdbStore) { return 0; }
    try {
      const todayStart = new Date();
      todayStart.setHours(0, 0, 0, 0);
      const todayTimestamp = todayStart.getTime();
      const predicates = new relationalStore.RdbPredicates('chat_record');
      predicates.equalTo('companion_id', companionId);
      const resultSet: relationalStore.ResultSet = await this.rdbStore.query(predicates);
      let count: number = 0;
      while (resultSet.goToNextRow()) {
        const role = resultSet.getString(resultSet.getColumnIndex('role'));
        const ts = resultSet.getLong(resultSet.getColumnIndex('timestamp'));
        if (role === 'user' && ts >= todayTimestamp) {
          count++;
        }
      }
      resultSet.close();
      return count;
    } catch (err) {
      return 0;
    }
  }

  async getStats(companionId: string): Promise<CompanionStats> {
    const stats = new CompanionStats();
    stats.totalChats = await this.getChatCount(companionId);
    stats.todayChats = await this.getTodayChatCount(companionId);
    stats.memoriesCount = await this.getMemoryCount(companionId);
    const companion = await this.getCompanionById(companionId);
    if (companion !== null && companion.created > 0) {
      stats.totalDays = Math.ceil((Date.now() - companion.created) / 86400000);
    }
    return stats;
  }

  async checkDatabase(): Promise<string> {
    const results: string[] = [];
    results.push('=== SQLite 数据库自检报告 ===');

    if (this.rdbStore === null) {
      results.push('[失败] rdbStore 未初始化，请先调用 init()');
      return results.join('\n');
    }
    results.push('[成功] rdbStore 已初始化');

    const tableNames: string[] = ['companion', 'chat_record', 'companion_memory'];

    for (let i = 0; i < tableNames.length; i++) {
      try {
        const sql = 'SELECT COUNT(*) AS cnt FROM ' + tableNames[i];
        const resultSet: relationalStore.ResultSet = await this.rdbStore.querySql(sql);
        if (resultSet.goToFirstRow()) {
          const cnt = resultSet.getLong(resultSet.getColumnIndex('cnt'));
          results.push('[成功] 表 ' + tableNames[i] + ' 存在，记录数: ' + cnt.toString());
        } else {
          results.push('[失败] 表 ' + tableNames[i] + ' 查询无结果');
        }
        resultSet.close();
      } catch (err) {
        results.push('[失败] 表 ' + tableNames[i] + ' 查询异常: ' + JSON.stringify(err));
      }
    }

    const testId = 'test_' + Date.now();

    try {
      const insertSql = "INSERT INTO companion (id, account, name, species, personality, level, exp, intimacy, mood, created, updated) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
      const args: Array<relationalStore.ValueType> = [testId, 'test_user', '__TEST__', 'cat', '温柔', 1, 0, 100, 'happy', Date.now(), Date.now()];
      await this.rdbStore.executeSql(insertSql, args);
      results.push('[成功] 测试记录插入成功');
    } catch (err) {
      results.push('[失败] 测试记录插入失败: ' + JSON.stringify(err));
    }

    try {
      const preds = new relationalStore.RdbPredicates('companion');
      preds.equalTo('id', testId);
      const rs: relationalStore.ResultSet = await this.rdbStore.query(preds);
      if (rs.goToFirstRow()) {
        const name = rs.getString(rs.getColumnIndex('name'));
        results.push('[成功] 查询测试记录成功，name=' + name);
      } else {
        results.push('[失败] 查询测试记录无结果');
      }
      rs.close();
    } catch (err) {
      results.push('[失败] 查询测试记录异常: ' + JSON.stringify(err));
    }

    try {
      const delPreds = new relationalStore.RdbPredicates('companion');
      delPreds.equalTo('id', testId);
      await this.rdbStore.delete(delPreds);
      results.push('[成功] 测试记录已清理');
    } catch (err) {
      results.push('[警告] 测试记录清理失败: ' + JSON.stringify(err));
    }

    results.push('=== 自检完成 ===');
    console.info(results.join('\n'));
    return results.join('\n');
  }
}

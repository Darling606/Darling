export type PetType = 'cat' | 'dog' | 'hamster' | 'rabbit' | 'other';
export type PetGender = 'male' | 'female';
export type LifeStage = '幼年期' | '成年期' | '老年期';
export type AdoptStatus = '未领养' | '申请中' | '已领养';
export type AuditResult = '待审核' | '通过' | '拒绝';
export type HealthMetric = 'weight' | 'temperature' | 'diet' | 'stool';
export type BehaviorType = '正常' | '异常' | '焦虑' | '攻击' | '异食';

let idCounter: number = 0;

export function generateId(): string {
  idCounter++;
  const timestamp = Date.now();
  const random = Math.floor(Math.random() * 100000);
  return timestamp.toString() + '_' + idCounter.toString() + '_' + random.toString();
}

export class PetProfile {
  id: string = '';
  name: string = '';
  type: PetType = 'cat';
  breed: string = '';
  age: number = 0;
  lifeStage: LifeStage = '幼年期';
  gender: PetGender = 'male';
  birthday: string = '';
  color: string = '';
  weight: number = 0;
  avatar: string = '';
  photos: string[] = [];
  familyMembers: string[] = [];
  notes: string = '';
  updatedAt: number = 0;
  deleted: boolean = false;
}

export class HealthRecord {
  id: string = '';
  petId: string = '';
  date: string = '';
  weight: number = 0;
  temperature: number = 0;
  diet: string = '';
  stool: string = '';
  notes: string = '';
  updatedAt: number = 0;
  deleted: boolean = false;
}

export class FeedPlan {
  id: string = '';
  petId: string = '';
  time: string = '';
  amount: string = '';
  type: string = '';
  enabled: boolean = true;
  lastTriggeredAt: string = '';
  lastFeedAt: number = 0;
  updatedAt: number = 0;
  deleted: boolean = false;
}

export class BehaviorRecord {
  id: string = '';
  petId: string = '';
  date: string = '';
  type: BehaviorType = '正常';
  description: string = '';
  duration: number = 0;
  notes: string = '';
  updatedAt: number = 0;
  deleted: boolean = false;
}

export class AdoptApplication {
  id: string = '';
  petId: string = '';
  applicantName: string = '';
  applicantPhone: string = '';
  applicantAddress: string = '';
  reason: string = '';
  status: AuditResult = '待审核';
  applyDate: string = '';
  auditDate: string = '';
  updatedAt: number = 0;
  deleted: boolean = false;
}

export class FamilyMember {
  id: string = '';
  name: string = '';
  relationship: string = '';
  phone: string = '';
  avatar: string = '';
}

export interface AdoptPet {
  id: string;
  name: string;
  type: PetType;
  age: string;
  gender: PetGender;
  health: string;
  description: string;
  image: string;
  status: AdoptStatus;
  updatedAt: number;
  deleted: boolean;
}

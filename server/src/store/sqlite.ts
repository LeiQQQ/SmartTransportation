import { DatabaseSync } from 'node:sqlite';
import { mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

/**
 * SQLite 存储层（Node 22+ 内置 node:sqlite，零第三方依赖）
 *
 * 数据库文件：server/data/store.db（src 与 dist 两种运行方式下均指向 server/data）
 * 当前只落一张事件表：事件是唯一"用户产生的、需要跨设备共享"的数据。
 * 流量/饱和度/配时为确定性仿真的实时派生量，不落库（见设计文档 §8.3）。
 */

const here: string = dirname(fileURLToPath(import.meta.url));
const dataDir: string = join(here, '..', '..', 'data');
mkdirSync(dataDir, { recursive: true });

export const DB_FILE: string = join(dataDir, 'store.db');

export const db = new DatabaseSync(DB_FILE);

db.exec(`
  CREATE TABLE IF NOT EXISTS event (
    id          TEXT PRIMARY KEY,
    type        INTEGER NOT NULL,
    title       TEXT NOT NULL,
    road_name   TEXT NOT NULL DEFAULT '',
    longitude   REAL NOT NULL DEFAULT 0,
    latitude    REAL NOT NULL DEFAULT 0,
    impact      INTEGER NOT NULL DEFAULT 1,
    description TEXT NOT NULL DEFAULT '',
    create_time INTEGER NOT NULL
  );
  CREATE INDEX IF NOT EXISTS idx_event_time ON event(create_time DESC);
  CREATE INDEX IF NOT EXISTS idx_event_type ON event(type, create_time DESC);
`);
